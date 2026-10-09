#version 430

// Volumetric clouds: ray march.
// CLOUD_RES 1: one sample per internal pixel. CLOUD_RES 2: one pixel of each 2x2 block per
// frame (checkerboard over 4 frames), reconstructed by composite4_b.csh.

layout(local_size_x = 8, local_size_y = 8) in;

#include "/lib/Settings.inc"

#if !defined VOLUMETRIC_CLOUDS
const ivec3 workGroups = ivec3(1, 1, 1);
#elif CLOUD_RES == 1
const vec2 workGroupsRender = vec2(0.5, 0.5);
#else
const vec2 workGroupsRender = vec2(0.25, 0.25);
#endif

#define CLOUD_WEATHER_SAMPLING
#include "/lib/clouds/CloudUniforms.inc"
#include "/lib/clouds/CloudCommon.inc"
#include "/lib/clouds/CloudWeather.inc"
#include "/lib/clouds/CloudMarch.inc"
#include "/lib/clouds/CloudView.inc"

layout(rgba16f) uniform writeonly image2D cloudRaw;

void main() {
	#ifdef VOLUMETRIC_CLOUDS
		ivec2 rp = ivec2(gl_GlobalInvocationID.xy);
		ivec2 isz = CloudInternalSize();
		#if CLOUD_RES == 2
			ivec2 rsz = (isz + 1) / 2;
			ivec2 px = min(rp * 2 + CloudCheckerOffset(frameCounter), isz - 1);
		#else
			ivec2 rsz = isz;
			ivec2 px = rp;
		#endif
		if (any(greaterThanEqual(rp, rsz))) return;

		vec2 tc = (vec2(px) + 0.5) / vec2(viewWidth, viewHeight);
		vec2 jitter = CloudJitter(frameCounter);
		vec3 dir = CloudWorldDir(tc, jitter);
		float sceneDist = CloudSceneDistance(px, tc, jitter);

		vec2 noise = texelFetch(noisetex, px & 63, 0).rg;
		noise = fract(noise + vec2(0.447213595, 1.41421356) * float(frameCounter % 64));

		vec4 light = CloudLightDirection();
		CloudResult r = CloudMarch(dir, sceneDist, cameraPosition.y, light.xyz, light.w > 0.5, noise);

		vec4 outv = vec4(r.sun, r.sky, r.T, r.depth > 0.0 ? r.depth * 0.001 : -1.0);
		#if CLOUD_DEBUG_VIEW == 3
			outv.y = r.cost / float(CQ_STEPS * 3);
		#endif
		#ifdef CLOUD_PROFILE
			outv = r.prof;
		#endif
		imageStore(cloudRaw, rp, outv);
	#endif
}
