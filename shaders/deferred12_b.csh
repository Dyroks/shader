#version 430
// Distant terrain shading, step 2 (lib/FarShading.inc): writes the height of the terrain seen
// through the quarter resolution pixels into the world height map (highest surface per cell,
// vanilla and Voxy terrain, entities excluded). Over a few frames the map holds every surface
// the camera has seen, so the shadows no longer depend on what is on screen.
layout(local_size_x = 8, local_size_y = 8) in;
#include "/lib/Settings.inc"
#ifdef AB_FAR_SHADING
const vec2 workGroupsRender = vec2(0.25, 0.25);
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

#ifdef AB_FAR_SHADING
#define FAR_HEIGHT_BUFFER
#include "/lib/FarShading.inc"
#include "/lib/FarShadingCompute.inc"
#endif

void main() {
	#ifdef AB_FAR_SHADING
		ivec2 org = FarHeightOrigin(cameraPosition);
		if (gl_GlobalInvocationID.xy == uvec2(0u)) farHeightState = ivec4(org, farHeightMagic, 0);
		ivec2 px = FarShadeSetup(ivec2(gl_GlobalInvocationID.xy));
		if (px.x < 0) return;
		vec4 P = SceneViewPos(px);
		if (P.w == 0.0) return;
		int mat = GbufferMaterial(px);
		if (mat == 4 || mat == 5 || mat == 35) return;   // hand, player, entities
		vec3 world = mat3(gbufferModelViewInverse) * P.xyz + gbufferModelViewInverse[3].xyz + cameraPosition;
		ivec2 cell = ivec2(floor(world.xz / farHeightCell));
		if (any(lessThan(cell, org)) || any(greaterThanEqual(cell, org + farHeightSize))) return;
		atomicMax(farHeight[FarHeightIndex(cell & (farHeightSize - 1))], FarHeightEncode(world.y));
	#endif
}
