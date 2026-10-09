#version 430

// Volumetric clouds: sky capture (512^2 octahedral map). Sky + clouds radiance for every
// direction, used by the GI, the sky ambient light and the reflections. A quarter of the
// texels is updated every frame and blended with the previous value.

layout(local_size_x = 8, local_size_y = 8) in;

#include "/lib/Settings.inc"

#if defined VOLUMETRIC_CLOUDS && defined CLOUD_SKY_LIGHTING
const ivec3 workGroups = ivec3(32, 32, 1);   // 256^2 threads, one texel of each 2x2 block
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

// Low quality ray march: the capture is only used for lighting and blurry reflections
#define CQ_OVERRIDE
#define CQ_STEPS 40
#define CQ_LIGHT_STEPS 3
#define CQ_MS_OCTAVES 2
#define CQ_DETAIL_DISTANCE 0.0
#define CQ_STEP_SCALE 1.5

#define CLOUD_WEATHER_SAMPLING
#include "/lib/clouds/CloudUniforms.inc"
uniform float nightVision;
float nightBrightness = 0.0001 + 0.0019 * nightVision;   // same as shaders.properties

#include "/lib/clouds/CloudCommon.inc"
#include "/lib/clouds/CloudWeather.inc"
#include "/lib/clouds/CloudMarch.inc"
#include "/lib/atmosphere/SkySEUS.inc"
#include "/lib/clouds/CloudShading.inc"
#include "/lib/clouds/CloudSky.inc"

layout(rgba16f) uniform image2D cloudSkyCapture;

shared vec3 cloudSkySamples[17];

void main() {
	#if defined VOLUMETRIC_CLOUDS && defined CLOUD_SKY_LIGHTING
		vec3 Lpack = normalize(shadowModelViewInverse[2].xyz);
		vec3 sunVec = sunAngle < 0.5 ? Lpack : -Lpack;

		// Average sky radiance (same directions as composite4.vsh), shared by the work group
		uint li = gl_LocalInvocationIndex;
		if (li < 17u) {
			vec3 d = vec3(0.0, 1.0, 0.0);
			if (li > 0u) {
				float a = float((li - 1u) >> 1) * 0.785398;
				d = (li & 1u) == 1u ? normalize(vec3(cos(a), 0.25, sin(a))) : normalize(vec3(cos(a + 0.39), 1.0, sin(a + 0.39)));
			}
			cloudSkySamples[li] = SkyShading(d, sunVec);
		}
		barrier();
		vec3 skyAmbient = vec3(0.0);
		for (int i = 0; i < 17; i++) skyAmbient += cloudSkySamples[i];
		skyAmbient /= 17.0;

		ivec2 px = ivec2(gl_GlobalInvocationID.xy) * 2 + ivec2(frameCounter & 1, (frameCounter >> 1) & 1);
		vec3 dir = CloudOctDecode((vec2(px) + 0.5) / cloudSkyCaptureSize);

		vec3 sky = SkyShading(dir, sunVec);

		vec3 moonColor = CloudPackLightColor(Lpack.y, sunVec.y < 0.0, wetness, nightBrightness);
		bool isSun = sunVec.y > cloudSunModeLimit;
		vec3 L = isSun ? sunVec : -sunVec;

		vec2 noise = fract(texelFetch(noisetex, px & 63, 0).rg + vec2(0.618034, 0.414214) * float(frameCounter % 64));
		CloudResult r = CloudMarch(dir, 1e9, cameraPosition.y, L, isSun, noise);
		float depth = r.depth > 0.0 ? r.depth : 10.0 * cloudKm;
		vec3 color = sky * r.T + CloudShade(vec3(r.sun, r.sky, r.T), depth, dir, cameraPosition.y, sunVec, moonColor, skyAmbient);
		vec4 result = vec4(color, r.T);

		vec4 prev = imageLoad(cloudSkyCapture, px);
		bool prevOk = !(any(isnan(prev)) || any(isinf(prev))) && prev.a >= 0.0 && prev.a <= 1.0 && dot(prev.rgb, vec3(1.0)) > 0.0;
		if (prevOk) result = mix(prev, result, 0.4);
		imageStore(cloudSkyCapture, px, result);
	#endif
}
