#version 430

// Volumetric clouds: temporal reconstruction into a history buffer at internal resolution.
// History layout: x = sun scattering, y = sky scattering, z = transmittance, w = sample count.
// Even frames write cloudHistA and read cloudHistB, odd frames the opposite.

layout(local_size_x = 8, local_size_y = 8) in;

#include "/lib/Settings.inc"

#ifdef VOLUMETRIC_CLOUDS
const vec2 workGroupsRender = vec2(0.5, 0.5);
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

#include "/lib/clouds/CloudUniforms.inc"
#include "/lib/clouds/CloudCommon.inc"
#include "/lib/clouds/CloudView.inc"

uniform sampler2D cloudRawSampler;
uniform sampler2D cloudHistASampler;
uniform sampler2D cloudHistBSampler;
layout(rgba16f) uniform writeonly image2D cloudHistA;
layout(rgba16f) uniform writeonly image2D cloudHistB;

const float cloudHistoryMax = 10.0;  // max accumulated samples per pixel
const float cloudClipGamma = 1.5;    // variance clipping width (in standard deviations)

bool CloudBad(vec4 v) {
	return any(isnan(v)) || any(isinf(v));
}

void main() {
	#ifdef VOLUMETRIC_CLOUDS
		ivec2 px = ivec2(gl_GlobalInvocationID.xy);
		ivec2 isz = CloudInternalSize();
		if (any(greaterThanEqual(px, isz))) return;

		#if CLOUD_RES == 2
			ivec2 off = CloudCheckerOffset(frameCounter);
			ivec2 rp = px >> 1;
			ivec2 rsz = (isz + 1) / 2;
			bool fresh = all(equal(px & 1, off));
		#else
			ivec2 off = ivec2(0);
			ivec2 rp = px;
			ivec2 rsz = isz;
			bool fresh = true;
		#endif

		vec4 cur = texelFetch(cloudRawSampler, rp, 0);
		if (CloudBad(cur)) cur = vec4(0.0, 0.0, 1.0, -1.0);

		// Neighbourhood of the current low resolution samples: statistics for variance clipping
		// (Salvi 2016), min/max as an outer bound, and depth
		vec3 mn = cur.xyz, mx = cur.xyz;
		vec3 m1 = cur.xyz, m2 = cur.xyz * cur.xyz;
		float n = 1.0;
		float depthKm = cur.w;
		for (int y = -1; y <= 1; y++)
		for (int x = -1; x <= 1; x++) {
			if (x == 0 && y == 0) continue;
			vec4 v = texelFetch(cloudRawSampler, clamp(rp + ivec2(x, y), ivec2(0), rsz - 1), 0);
			if (CloudBad(v)) continue;
			mn = min(mn, v.xyz);
			mx = max(mx, v.xyz);
			m1 += v.xyz;
			m2 += v.xyz * v.xyz;
			n += 1.0;
			depthKm = max(depthKm, v.w);
		}
		if (cur.w > 0.0) depthKm = cur.w;
		if (depthKm <= 0.0) depthKm = 10.0 * cloudScale;
		m1 /= n;
		vec3 sigma = sqrt(max(m2 / n - m1 * m1, 0.0));
		vec3 pad = vec3(0.002, 0.002, 0.01);
		mn = max(mn, m1 - sigma * cloudClipGamma) - pad;
		mx = min(mx, m1 + sigma * cloudClipGamma) + pad;

		// Spatial estimate for pixels without a fresh sample (bilinear over this frame's samples)
		vec2 rawSize = vec2(textureSize(cloudRawSampler, 0));
		vec3 spatial = textureLod(cloudRawSampler, ((vec2(px - off) * 0.5) + 0.5) / rawSize, 0.0).xyz;
		if (CloudBad(vec4(spatial, 0.0))) spatial = cur.xyz;

		// Reprojection at the cloud depth
		vec2 tc = (vec2(px) + 0.5) / vec2(viewWidth, viewHeight);
		vec3 dir = CloudWorldDir(tc, CloudJitter(frameCounter));
		vec2 ptc = CloudReproject(dir * (depthKm * 1000.0), CloudJitter(frameCounter - 1));
		vec2 ppx = ptc * vec2(viewWidth, viewHeight);
		bool even = (frameCounter & 1) == 0;
		vec2 histSize = vec2(textureSize(cloudHistASampler, 0));
		vec4 hist = even ? textureLod(cloudHistBSampler, ppx / histSize, 0.0)
		                 : textureLod(cloudHistASampler, ppx / histSize, 0.0);
		bool valid = all(greaterThanEqual(ppx, vec2(0.5))) && all(lessThan(ppx, vec2(isz) - 0.5))
		          && !CloudBad(hist) && hist.w >= 0.5 && hist.w <= cloudHistoryMax + 0.5;

		#ifndef CLOUD_TEMPORAL
			valid = valid && !fresh;
		#endif

		vec4 result;
		if (valid) {
			hist.xyz = clamp(hist.xyz, mn, mx);
			if (fresh) {
				float count = min(hist.w, cloudHistoryMax - 1.0);
				result = vec4(mix(hist.xyz, cur.xyz, 1.0 / (count + 1.0)), count + 1.0);
			} else {
				result = hist;
			}
		} else {
			result = fresh ? vec4(cur.xyz, 1.0) : vec4(spatial, 1.0);
		}

		if (even) imageStore(cloudHistA, px, result);
		else      imageStore(cloudHistB, px, result);
	#endif
}
