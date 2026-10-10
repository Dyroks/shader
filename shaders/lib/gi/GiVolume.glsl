// =====================================================================================
//  GI module: voxel volume of the terrain around the camera
//
//  The shadow pass writes one texel per voxel into a corner of the shadow map atlas:
//   - shadowcolor:  rgb = vertex colour (biome tint, or the colour of a light), a = voxel id / 255
//   - shadowcolor1: xy = atlas position of the block texture, z = tint flag,
//                   w = log2(texture resolution) / 255
//  The volume is a cube of RAY_TRACING_DIAMETER blocks centred on the camera block.
//
//  Volume coordinates: one unit per block, camera relative position
//  + FractedCameraPosition + RAY_TRACING_DIAMETER / 2 - 1.
//
//  Needs, defined by the program: SHADOW_MAP_RESOLUTION, RAY_TRACING_RESOLUTION and
//  RAY_TRACING_DIAMETER. Uniforms: shadowcolor, FractedCameraPosition.
// =====================================================================================

#ifndef GI_VOLUME_INC
#define GI_VOLUME_INC

const int giVolumeSize = int(RAY_TRACING_DIAMETER);
const int giVolumeRowLength = int(RAY_TRACING_RESOLUTION);   // texels per row of the voxel area
const float giVolumeOffset = RAY_TRACING_DIAMETER * 0.5 - 1.0;

// Voxel ids written by the shadow pass
const int giIdEmpty = 255;            // air
const int giIdSmallLight = 241;       // torch, lantern, candle...: a light inside an empty cube
const int giIdLightBlock = 31;        // glowstone, sea lantern, ...: the whole texture emits
const int giIdFaceLightFirst = 32;    // lit furnaces: light toward one face (-z, +x, +z, -x)
const int giIdFaceLightLast = 35;
const int giIdRedLight = 36;          // emits on its red texels (lit redstone ore)
const int giIdStainedGlass = 37;
const int giIdGlass = 39;
const int giIdAlphaTestFirst = 31;    // ids whose texture alpha decides the hit (leaves, glass, plants)
const int giIdAlphaTestLast = 92;

vec3 GiVolumePos(vec3 rel) {
	return rel + FractedCameraPosition + giVolumeOffset;
}

vec3 GiRelPos(vec3 volumePos) {
	return volumePos - FractedCameraPosition - giVolumeOffset;
}

bool GiInVolume(ivec3 voxel) {
	return all(greaterThanEqual(voxel, ivec3(0))) && all(lessThan(voxel, ivec3(giVolumeSize)));
}

// Texel of a voxel in the shadow map atlas: x + y * size runs along the rows, z selects a band
// of rows
ivec2 GiVoxelTexel(ivec3 voxel) {
	int run = voxel.x + voxel.y * giVolumeSize;
	return ivec2(run % giVolumeRowLength, voxel.z + (run / giVolumeRowLength) * giVolumeSize);
}

#endif
