#version 430
// ReSTIR GI (GI_METHOD 1, lib/gi/GiRestir.glsl), spatial pass: reuse of the neighbours, visibility, shading.
// Internal resolution, before deferred.fsh (which copies the result into the GI buffer).
layout(local_size_x = 8, local_size_y = 8) in;
#include "/lib/Settings.inc"
#if GI_METHOD == 1
const vec2 workGroupsRender = vec2(0.5, 0.5);
#include "/lib/gi/GiComputeHeader.glsl"
#include "/lib/gi/GiRestir.glsl"
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

void main() {
	#if GI_METHOD == 1
		GiRestirSpatial(ivec2(gl_GlobalInvocationID.xy));
	#endif
}
