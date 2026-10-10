#version 430
// Distant terrain shading, step 3 (lib/FarShading.inc), before deferred12, at a quarter of the
// internal resolution (one pixel of each 2x2 block, a different one every frame):
//  - sun shadows of the relief by a march toward the sun through the world height map
//    (deferred12_a/b): the shadow map covers shadowDistance and holds no Voxy terrain. Pixels
//    inside the shadow map only count occluders outside it (the shadow map has the others).
//    Soft penumbra from the height clearance along the ray.
//  - ambient occlusion where deferred12 replaces the GI with the flat sky ambient (beyond the
//    voxel volume): hemisphere samples through the depth buffer.
// Output farShade: x = ambient occlusion, y = sun visibility, z = distance (km), w = 1.
layout(local_size_x = 8, local_size_y = 8) in;
#include "/lib/Settings.inc"
#ifdef AB_FAR_SHADING
const vec2 workGroupsRender = vec2(0.25, 0.25);
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

#ifdef AB_FAR_SHADING
#include "/lib/FarShading.inc"
#include "/lib/FarShadingCompute.inc"
uniform usampler2D farHeightSampler;
layout(rgba16f) uniform writeonly image2D farShade;

const float shadowDistance = 240.0; // Shadow distance. Set lower if you prefer nicer close shadows. Set higher if you prefer nicer distant shadows. [80.0 120.0 160.0 200.0 240.0 280.0 320.0 360.0 400.0 440.0 480.0 520.0 560.0 600.0 640.0]
const int shadowMapResolution = 8192; // Higher value impacts performance costs, but can get better shadow, and increase path tracing distance. Please increase the shadow distance at the same time. 4096 - 80 blocks path tracing. 8192 - 160 blocks path tracing. 16384 - 300 blocks path tracing, requires at least 6GB VRAM. 34768 - 530 blocks of path tracing, requires at least 20GB VRAM. [4096 8192 16384 32768]
#ifndef MC_SHADOW_QUALITY
	#define MC_SHADOW_QUALITY 1.0
#endif
const float SHADOW_MAP_RESOLUTION = shadowMapResolution * MC_SHADOW_QUALITY;
const float RAY_TRACING_RESOLUTION = SHADOW_MAP_RESOLUTION - 2048.0;
const float RAY_TRACING_DIAMETER_TEMP = floor(pow(RAY_TRACING_RESOLUTION, 2.0 / 3.0));
const float RAY_TRACING_DIAMETER = RAY_TRACING_DIAMETER_TEMP - mod(RAY_TRACING_DIAMETER_TEMP - 1.0, 2.0);
const float RAY_TRACING_RADIUS = RAY_TRACING_DIAMETER / 2.0;

#endif

void main() {
	#ifdef AB_FAR_SHADING
		ivec2 rp = ivec2(gl_GlobalInvocationID.xy);
		ivec2 px = FarShadeSetup(rp);
		if (px.x < 0) return;

		vec4 P = SceneViewPos(px);
		if (P.w == 0.0) {
			imageStore(farShade, rp, vec4(1.0, 1.0, 1e4, 1.0));
			return;
		}
		float dist = length(P.xyz);
		vec3 rel = mat3(gbufferModelViewInverse) * P.xyz + gbufferModelViewInverse[3].xyz;
		float cheb = max(max(abs(rel.x), abs(rel.y)), abs(rel.z));
		vec3 n = normalize(DecodeNormal(texelFetch(colortex2, px, 0).zw));
		vec3 noise = texelFetch(noisetex, rp & 63, 0).rgb;
		noise = fract(noise + vec3(0.447213595, 1.41421356, 1.61803398) * float(frameCounter % 64));
		vec3 start = P.xyz + n * (0.5 + 0.004 * dist);   // ambient occlusion samples

		// Sun: march toward the light through the height map, steps growing geometrically
		float sun = 1.0;
		vec3 nw = mat3(gbufferModelViewInverse) * n;
		vec3 Lw = worldLightVector;
		if (dot(nw, Lw) > 0.0 && Lw.y > 0.0) {
			ivec2 org = FarHeightOrigin(cameraPosition);
			// inside the shadow map, its own occluders are found by the soft shadows of deferred12
			bool inShadowMap = length(rel.xz) < 0.9 * shadowDistance;
			vec3 p0 = rel + nw * 1.0;
			float t0 = 1.5 * farHeightCell;
			float k = pow(farShadowReach / t0, 1.0 / float(farShadowSteps));
			float t = t0 * pow(k, noise.x);
			for (int i = 0; i < farShadowSteps; i++, t *= k) {
				vec3 p = p0 + Lw * t;
				if (inShadowMap && length(p.xz) < 0.9 * shadowDistance) continue;
				// bilinear height of the 4 nearest cells (an unknown cell: the nearest known one)
				vec2 c = (p.xz + cameraPosition.xz) / farHeightCell - 0.5;
				ivec2 c0 = ivec2(floor(c));
				if (any(lessThan(c0, org)) || any(greaterThanEqual(c0 + 1, org + farHeightSize))) break;
				vec2 fr = c - vec2(c0);
				uvec4 hv = uvec4(texelFetch(farHeightSampler, c0 & (farHeightSize - 1), 0).r,
				                 texelFetch(farHeightSampler, (c0 + ivec2(1, 0)) & (farHeightSize - 1), 0).r,
				                 texelFetch(farHeightSampler, (c0 + ivec2(0, 1)) & (farHeightSize - 1), 0).r,
				                 texelFetch(farHeightSampler, (c0 + ivec2(1, 1)) & (farHeightSize - 1), 0).r);
				uint known = max(max(hv.x, hv.y), max(hv.z, hv.w));
				if (known == 0u) continue;
				for (int j = 0; j < 4; j++) if (hv[j] == 0u) hv[j] = known;
				vec4 h = vec4(FarHeightDecode(hv.x), FarHeightDecode(hv.y), FarHeightDecode(hv.z), FarHeightDecode(hv.w));
				float H = mix(mix(h.x, h.y, fr.x), mix(h.z, h.w, fr.x), fr.y);
				// soft shadow: height clearance of the ray over the terrain, relative to the distance
				float clearance = p.y + cameraPosition.y - H + 2.0 + 0.01 * t;
				sun = min(sun, clamp(farShadowSoftness * clearance / t, 0.0, 1.0));
				if (sun < 0.01) break;
			}
		}

		// Ambient occlusion where the GI is replaced by the flat sky ambient
		float ao = 1.0;
		if (cheb > RAY_TRACING_RADIUS - 6.0) {
			float R = clamp(0.04 * dist, 8.0, 64.0);
			vec3 t = normalize(cross(n, abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
			vec3 b = cross(n, t);
			float occ = 0.0;
			for (int i = 0; i < farAOSamples; i++) {
				// cosine weighted hemisphere, sample lengths spread over the radius
				vec2 h = fract(vec2(float(i) * 0.618034 + noise.y, float(i) * 0.7548777 + noise.z));
				float phi = 6.2831853 * h.x, sr = sqrt(h.y);
				vec3 dir = t * (cos(phi) * sr) + b * (sin(phi) * sr) + n * sqrt(1.0 - h.y);
				float len = R * mix(0.15, 1.0, fract(float(i) * 0.38196601 + noise.x));
				vec3 q = start + dir * len;
				ivec2 qp;
				if (!ProjectToPixel(q, qp)) continue;
				vec4 o = SceneViewPos(qp);
				if (o.w == 0.0) continue;
				float behind = o.z - q.z;
				if (behind > 0.002 * -q.z + 0.25) occ += clamp(1.0 - (behind - R) / R, 0.0, 1.0);
			}
			ao = 1.0 - farAOStrength * occ / float(farAOSamples);
		}
		imageStore(farShade, rp, vec4(ao, sun, dist * 0.001, 1.0));
	#endif
}
