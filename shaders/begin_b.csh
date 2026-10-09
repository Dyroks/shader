#version 430

// Volumetric clouds: far weather map (1024^2 texels, 2 layers), see lib/clouds/CloudWeather.inc. Needs the regime map of begin.csh

layout(local_size_x = 16, local_size_y = 16) in;

#include "/lib/Settings.inc"

#ifdef VOLUMETRIC_CLOUDS
const ivec3 workGroups = ivec3(64, 64, 1);
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

#define CLOUD_REGIME_MAP
#include "/lib/clouds/CloudUniforms.inc"
#include "/lib/clouds/CloudCommon.inc"
#include "/lib/clouds/CloudWeather.inc"

layout(rgba16f) uniform writeonly image3D cloudWeatherFar;

void main() {
	#ifdef VOLUMETRIC_CLOUDS
		ivec2 id = ivec2(gl_GlobalInvocationID.xy);
		float time = CloudTime();
		vec2 q = CloudWeatherTexelWorld(id, cloudWeatherFarTexel, cloudWeatherFarSize) - CloudWindOffset(time);
		vec4 a, b;
		CloudGenerateWeather(q, time, true, a, b);
		imageStore(cloudWeatherFar, ivec3(id, 0), a);
		imageStore(cloudWeatherFar, ivec3(id, 1), b);
	#endif
}
