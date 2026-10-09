// =====================================================================================
//  Volumetric clouds - composition into the lit scene (composite4.fsh) and into the
//  screen space sky reflections (composite.fsh)
//
//  Included after the pack's Settings/Uniforms/Common, so the SEUS atmosphere functions
//  and the LOD helpers are available.
// =====================================================================================

#ifndef CLOUD_COMPOSITE_INC
#define CLOUD_COMPOSITE_INC

#ifndef CLOUD_WORLDDAY_DECLARED
#define CLOUD_WORLDDAY_DECLARED
uniform int worldDay;
#endif

#include "/lib/clouds/CloudCommon.inc"
#include "/lib/clouds/CloudShading.inc"

uniform sampler2D cloudRawSampler;
uniform sampler2D cloudHistASampler;
uniform sampler2D cloudHistBSampler;
#if CLOUD_DEBUG_VIEW == 2
uniform sampler3D cloudWeatherNearSampler;
#endif

// Scene radiance units: composite4 works with (deferred12 radiance) * 0.001 * 120
const float cloudToComposite = 0.12;

vec3 CloudHeatColor(float x) {
	x = CloudSat(x);
	return CloudSat(vec3(x * 3.0 - 1.0, x < 0.5 ? x * 2.0 : 2.0 - x * 2.0, 1.0 - x * 3.0)) + vec3(0.02);
}

// History written by composite4_b this frame (latest = true, after composite4_b) or by the
// previous frame (latest = false, for passes that run before composite4).
vec4 CloudHistory(ivec2 px, bool latest) {
	bool readA = ((frameCounter & 1) == 0) == latest;
	vec4 hist = readA ? texelFetch(cloudHistASampler, px, 0) : texelFetch(cloudHistBSampler, px, 0);
	if (any(isnan(hist)) || any(isinf(hist))) hist = vec4(0.0, 0.0, 1.0, 0.0);
	return hist;
}

// Distance of the clouds seen through an internal pixel (blocks)
float CloudDepthAt(ivec2 px) {
	#if CLOUD_RES == 2
		ivec2 rp = px >> 1;
	#else
		ivec2 rp = px;
	#endif
	float depthKm = texelFetch(cloudRawSampler, rp, 0).w;
	if (depthKm < 0.0) {
		// pixel had no cloud in the latest low resolution sample: use the largest neighbour depth
		depthKm = 0.0;
		ivec2 rawMax = textureSize(cloudRawSampler, 0) - 1;
		for (int i = 0; i < 4; i++) {
			ivec2 o = ivec2(i & 1, i >> 1) * 2 - 1;
			depthKm = max(depthKm, texelFetch(cloudRawSampler, clamp(rp + o, ivec2(0), rawMax), 0).w);
		}
		if (depthKm <= 0.0) depthKm = 10.0 * cloudScale;
	}
	return depthKm * 1000.0;
}

// Distance to the first surface (terrain, water, LOD terrain) through an internal texture
// coordinate, 1e9 for the sky
float CloudSurfaceDistance(vec2 tc) {
	float dist = 1e9;
	float d = textureLod(depthtex0, tc, 0.0).x;
	if (d < 1.0) dist = length(GetViewPosition(tc, d).xyz);
	#ifdef LOD
		float ld = min(getLodDepthSolid(tc), getLodDepthWater(tc));
		if (ld < 1.0) dist = min(dist, length(GetViewPositionLod(tc, ld).xyz));
	#endif
	return dist;
}

// Clouds can only be visible if the view ray enters the cloud layer before the surface.
// Exact per pixel test: removes any temporal leftover of clouds over near geometry.
bool CloudPossible(vec3 worldDir, float surfaceDist) {
	float tStart, tEnd;
	if (!CloudShellSegment(worldDir, cameraPosition.y, cloudLayerBottom, cloudLayerTop, tStart, tEnd)) return false;
	return surfaceDist > tStart;
}

// color   : scene colour in composite4 units (modified in place)
// worldDir: normalised camera to pixel direction
// tc      : internal texture coordinate (0..0.5)
// skyAmbient: average sky radiance (deferred12 units)
void CloudComposite(inout vec3 color, vec3 worldDir, vec2 tc, vec3 skyAmbient) {
	ivec2 px = ivec2(tc * vec2(viewWidth, viewHeight));
	#if CLOUD_DEBUG_VIEW != 2 && CLOUD_DEBUG_VIEW != 3
		if (!CloudPossible(worldDir, CloudSurfaceDistance(tc))) {
			#if CLOUD_DEBUG_VIEW == 1
				color = vec3(0.0);
			#elif CLOUD_DEBUG_VIEW == 4
				color = vec3(2.0);
			#endif
			return;
		}
	#endif

	vec4 hist = CloudHistory(px, true);
	float T = CloudSat(hist.z);
	vec3 cloudColor = CloudShade(hist.xyz, CloudDepthAt(px), worldDir, cameraPosition.y, worldSunVector, colorSunlight, skyAmbient);
	cloudColor = DoNightEyeAtNight(cloudColor, timeMidnight);

	#if CLOUD_DEBUG_VIEW == 0
		color = color * T + cloudColor * cloudToComposite;
	#elif CLOUD_DEBUG_VIEW == 1
		color = cloudColor * cloudToComposite;
	#elif CLOUD_DEBUG_VIEW == 2
		color = color * T + cloudColor * cloudToComposite;
		if (tc.x < 0.2 && tc.y < 0.2) {
			vec2 uv = tc / 0.2;
			vec4 w = textureLod(cloudWeatherNearSampler, vec3(uv, 0.25), 0.0);
			color = vec3(w.x, w.z / 3.0, w.w) * 2.0;
			if (max(abs(uv.x - 0.5), abs(uv.y - 0.5)) < 0.004) color = vec3(4.0);
		}
	#elif CLOUD_DEBUG_VIEW == 3
		#if CLOUD_RES == 2
			ivec2 rp = px >> 1;
		#else
			ivec2 rp = px;
		#endif
		color = CloudHeatColor(texelFetch(cloudRawSampler, rp, 0).y) * 2.0;
	#elif CLOUD_DEBUG_VIEW == 4
		color = vec3(T) * 2.0;
	#endif
}

// Screen space reflections that land on the sky read the sky drawn by deferred12, before
// the clouds are composited (composite4). Put the clouds back from the previous frame's
// cloud history, reprojected to where this direction was on screen in that frame (so the
// reflected clouds follow camera rotations without lag). Off screen: the sky capture.
// skyColor: sky colour read from the screen (any unit), unitScale: that unit / deferred12 unit
vec3 CloudOverScreenSky(vec3 skyColor, vec3 worldDir, vec2 tc, vec3 skyAmbient, float unitScale) {
	ivec2 px = ivec2(tc * vec2(viewWidth, viewHeight));
	float depth = CloudDepthAt(px);

	vec3 prevRel = worldDir * depth + (cameraPosition - previousCameraPosition);
	vec4 pc = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(prevRel, 1.0));
	vec2 prevTc = (pc.xy / pc.w + 1.0) * 0.25;
	vec2 prevPx = prevTc * vec2(viewWidth, viewHeight);
	vec2 histSize = vec2(textureSize(cloudHistASampler, 0));
	vec2 internalSize = ceil(vec2(viewWidth, viewHeight) * 0.5);
	if (pc.w <= 0.0 || any(lessThan(prevPx, vec2(0.5))) || any(greaterThan(prevPx, internalSize - 0.5))) {
		#if defined CLOUD_SKY_LOOKUPS && defined CLOUD_SKY_LIGHTING
			return CloudSkyLookup(worldDir).rgb * unitScale;
		#else
			return skyColor;
		#endif
	}

	// previous frame history = the one not written this frame yet
	vec2 uv = prevPx / histSize;
	vec4 hist = (frameCounter & 1) == 0 ? textureLod(cloudHistBSampler, uv, 0.0) : textureLod(cloudHistASampler, uv, 0.0);
	if (any(isnan(hist)) || any(isinf(hist))) return skyColor;

	vec3 cloudColor = CloudShade(hist.xyz, depth, worldDir, cameraPosition.y, worldSunVector, colorSunlight, skyAmbient);
	cloudColor = DoNightEyeAtNight(cloudColor, timeMidnight);
	return skyColor * CloudSat(hist.z) + cloudColor * unitScale;
}

#endif
