#version 430
// Distant terrain shading, step 1 (lib/FarShading.inc): the world height map follows the camera
// (toroidal): clears the cells whose world position was outside the window last frame (and the
// whole map on the first frame). deferred12_b fills it, deferred12_c marches it.
layout(local_size_x = 8, local_size_y = 8) in;
#include "/lib/Settings.inc"
#ifdef AB_FAR_SHADING
const ivec3 workGroups = ivec3(256, 256, 1);   // farHeightSize / 8
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

#ifdef AB_FAR_SHADING
#include "/lib/FarShading.inc"
uniform vec3 cameraPosition;
layout(r32ui) uniform writeonly uimage2D farHeight;
layout(rgba32i) uniform readonly iimage2D farHeightState;
#endif

void main() {
	#ifdef AB_FAR_SHADING
		ivec2 t = ivec2(gl_GlobalInvocationID.xy);
		ivec2 org = FarHeightOrigin(cameraPosition);
		ivec4 state = imageLoad(farHeightState, ivec2(0));   // xy: last window origin, z: magic
		ivec2 w = org + ((t - org) & (farHeightSize - 1));   // world cell this texel holds now
		bool keep = state.z == farHeightMagic && all(greaterThanEqual(w, state.xy)) && all(lessThan(w, state.xy + farHeightSize));
		if (!keep) imageStore(farHeight, t, uvec4(0u));
	#endif
}
