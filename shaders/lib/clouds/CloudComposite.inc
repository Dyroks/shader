// =====================================================================================
//  Volumetric clouds - composition into the lit scene (composite4.fsh)
//
//  Included after the pack's Settings/Uniforms/Common, so the SEUS atmosphere functions
//  are available. Phase 4 will route this through a dedicated atmosphere interface.
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

// color   : scene colour in composite4 units (modified in place)
// worldDir: normalised camera to pixel direction
// tc      : internal texture coordinate (0..0.5)
// skyAmbient: average sky radiance (deferred12 units)
void CloudComposite(inout vec3 color, vec3 worldDir, vec2 tc, vec3 skyAmbient) {
	ivec2 px = ivec2(tc * vec2(viewWidth, viewHeight));
	vec4 hist = (frameCounter & 1) == 0 ? texelFetch(cloudHistASampler, px, 0) : texelFetch(cloudHistBSampler, px, 0);
	if (any(isnan(hist)) || any(isinf(hist))) hist = vec4(0.0, 0.0, 1.0, 0.0);

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

	float T = CloudSat(hist.z);
	vec3 cloudColor = CloudShade(hist.xyz, depthKm * 1000.0, worldDir, cameraPosition.y, worldSunVector, colorSunlight, skyAmbient);
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
		color = CloudHeatColor(texelFetch(cloudRawSampler, rp, 0).y) * 2.0;
	#elif CLOUD_DEBUG_VIEW == 4
		color = vec3(T) * 2.0;
	#endif
}

#endif
