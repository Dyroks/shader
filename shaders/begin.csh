#version 430

// Volumetric clouds: regime map (512^2), large scale coverage / convection / base altitude /
// clustering in wind relative space. Read by begin_a.csh and begin_b.csh.

layout(local_size_x = 16, local_size_y = 16) in;

#include "/lib/Settings.inc"

#ifdef VOLUMETRIC_CLOUDS
const ivec3 workGroups = ivec3(32, 32, 1);
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

#include "/lib/clouds/CloudUniforms.inc"
#include "/lib/clouds/CloudCommon.inc"
#include "/lib/clouds/CloudWeather.inc"

layout(rgba16f) uniform writeonly image2D cloudRegime;

void main() {
	#ifdef VOLUMETRIC_CLOUDS
		ivec2 id = ivec2(gl_GlobalInvocationID.xy);
		float time = CloudTime();
		vec2 q = CloudRegimeOrigin(time) + (vec2(id) + 0.5 - cloudRegimeSize * 0.5) * cloudRegimeTexel;
		imageStore(cloudRegime, id, CloudRegimeFull(q, time));
	#endif
}
