#version 430

// Light in the lower air (crepuscular rays, valley haze, terrain shadow and near mist:
// lib/atmosphere/Crepuscular.inc, AirTerrainShadow.inc)
// at the resolution of the cloud ray march: one pixel of each 2x2 block of internal pixels,
// a different one every frame (the same as the march with CLOUD_RES 2). composite4 upsamples
// it with depth aware weights, the temporal anti-aliasing filters the rest. The light in the
// air is smooth: 4 times fewer integrations for the same image.
// Output: airLightA = light removed from the air (rgb) + haze optical depth at 550 nm,
//         airLightB = light added (rgb) + distance of the surface (km).

layout(local_size_x = 8, local_size_y = 8) in;

#include "/lib/Settings.inc"

#if defined VOLUMETRIC_CLOUDS && ATMOSPHERE_MODEL == 1 && (defined CREPUSCULAR_RAYS && defined CLOUD_SHADOWS || HAZE_DENSITY > 0 || defined GODRAYS)
	#define AIR_LIGHT_PASS
const vec2 workGroupsRender = vec2(0.25, 0.25);
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

#ifdef AIR_LIGHT_PASS
	#include "/lib/clouds/CloudUniforms.inc"
	uniform vec3 worldLightVector;
	uniform vec3 worldSunVector;
	uniform float nightBrightness;
	uniform ivec2 eyeBrightnessSmooth;
	#define ATMOSPHERE_LUTS
	#include "/lib/atmosphere/Atmosphere.inc"
	#include "/lib/clouds/CloudCommon.inc"
	#define CLOUD_SKY_LOOKUPS
	#include "/lib/clouds/CloudSky.inc"
	#include "/lib/clouds/CloudView.inc"
	#include "/lib/clouds/CloudHistory.inc"
	#ifndef MC_SHADOW_QUALITY
		#define MC_SHADOW_QUALITY 1.0
	#endif
	#ifndef CLOUD_PREVIEW
		uniform mat4 shadowModelView;
		uniform mat4 shadowProjection;
		uniform sampler2DShadow shadowtex0;
		uniform sampler2D shadowcolor;
		const int shadowMapResolution = 8192; // Higher value impacts performance costs, but can get better shadow, and increase path tracing distance. Please increase the shadow distance at the same time. 4096 - 80 blocks path tracing. 8192 - 160 blocks path tracing. 16384 - 300 blocks path tracing, requires at least 6GB VRAM. 34768 - 530 blocks of path tracing, requires at least 20GB VRAM. [4096 8192 16384 32768]
		const float SHADOW_MAP_RESOLUTION = shadowMapResolution * MC_SHADOW_QUALITY;
	#endif
	#include "/lib/atmosphere/AirTerrainShadow.inc"
	#include "/lib/atmosphere/Crepuscular.inc"

	layout(rgba16f) uniform writeonly image2D airLightA;
	layout(rgba16f) uniform writeonly image2D airLightB;
#endif

void main() {
	#ifdef AIR_LIGHT_PASS
		ivec2 rp = ivec2(gl_GlobalInvocationID.xy);
		ivec2 isz = CloudInternalSize();
		ivec2 rsz = (isz + 1) / 2;
		if (any(greaterThanEqual(rp, rsz))) return;
		ivec2 px = min(rp * 2 + CloudCheckerOffset(frameCounter), isz - 1);

		vec2 tc = (vec2(px) + 0.5) / vec2(viewWidth, viewHeight);
		vec2 jitter = CloudJitter(frameCounter);
		vec3 dir = CloudWorldDir(tc, jitter);
		float dist = CloudSceneDistance(px, tc, jitter);

		// clouds seen through the pixel (as composed by composite4)
		vec2 cloudTD = vec2(1.0, 1e9);
		if (CloudPossible(dir, dist)) cloudTD = vec2(CloudSat(CloudHistory(px, true).z), CloudDepthAt(px));

		// blue noise over the low resolution grid (sampling it one pixel in two would lose its
		// blue spectrum: clumped noise the temporal anti-aliasing cannot remove)
		vec3 noise = texelFetch(noisetex, rp & 63, 0).rgb;
		noise = fract(noise + vec3(0.447213595, 1.41421356, 1.61803398) * float(frameCounter % 64));
		float apFade = pow(CloudSat(float(eyeBrightnessSmooth.y) / 240.0), 6.0);
		// only used when neither the sun nor the moon is above the horizon
		vec3 skyAmbient = worldLightVector.y < -0.05 ? AtmoSkyRadiance(vec3(0.0, 1.0, 0.0), worldSunVector, nightBrightness) : vec3(0.0);
		AirLight air = AirLightIntegrate(dir, dist, cloudTD, noise, skyAmbient, apFade);

		float od = -log(max(air.T.g, 1e-4));
		imageStore(airLightA, rp, vec4(air.removed, od));
		imageStore(airLightB, rp, vec4(air.inscatter, min(dist * 0.001, 60000.0)));
	#endif
}
