// =====================================================================================
//  Distant terrain shading: sun shadows of the distant relief and ambient occlusion beyond
//  the voxel volume, computed by deferred12_c.csh at a quarter of the internal resolution
//  (farShade), applied by deferred12. The shadows march a height map of the terrain the camera
//  has seen (deferred12_a, deferred12_b).
// =====================================================================================

#ifndef FAR_SHADING_INC
#define FAR_SHADING_INC

const int farShadowSteps = 40;        // march toward the sun through the height map
const float farShadowReach = 6000.0;  // blocks
const float farShadowSoftness = 12.0; // larger = harder shadow edges (penumbra ~ 1/x radian)

// World height map of the terrain seen by the camera (deferred12_a clears, deferred12_b fills,
// deferred12_c marches it): farHeightSize^2 cells of farHeightCell blocks, toroidal, anchored in
// the world around the camera; a cell holds the highest surface seen in it (0 = unknown).
// Shader storage buffer 1 (FAR_HEIGHT_BUFFER, compute programs only).
const float farHeightCell = 8.0;
const int farHeightSize = 2048;
const int farHeightMagic = 0x5EED;

int FarHeightIndex(ivec2 t) {
	return t.y * farHeightSize + t.x;
}

ivec2 FarHeightOrigin(vec3 cam) {
	return ivec2(floor(cam.xz / farHeightCell)) - farHeightSize / 2;
}
uint FarHeightEncode(float y) {
	return uint(clamp(y + 4096.0, 1.0, 65535.0) * 16.0);
}
float FarHeightDecode(uint v) {
	return float(v) / 16.0 - 4096.0;
}
#ifdef FAR_HEIGHT_BUFFER
layout(std430, binding = 1) buffer FarHeightBuffer {
	ivec4 farHeightState;   // xy: window origin of the last frame, z: magic once initialised
	uint farHeight[];       // farHeightSize^2 cells (texel t at t.y * farHeightSize + t.x)
};
#endif

const int farAOSamples = 8;
const float farAOStrength = 0.8;

#ifdef FAR_SHADE_UPSAMPLE
uniform sampler2D farShadeSampler;

// x = ambient occlusion, y = sun visibility of an internal pixel: the 4 nearest samples of
// the quarter resolution pass, bilinear weights times the similarity of their distance
vec2 FarShadeUpsample(ivec2 px, float dist) {
	int i = frameCounter & 3;
	ivec2 off = ivec2(i == 1 || i == 2 ? 1 : 0, i == 1 || i == 3 ? 1 : 0);
	ivec2 rsz = (ivec2(ceil(vec2(viewWidth, viewHeight) * 0.5)) + 1) / 2;
	vec2 f = vec2(px - off) * 0.5;
	ivec2 b = ivec2(floor(f));
	vec2 fr = f - vec2(b);
	float dKm = dist * 0.001;
	vec2 sum = vec2(0.0);
	float sumW = 0.0;
	for (int k = 0; k < 4; k++) {
		ivec2 o = ivec2(k & 1, k >> 1);
		vec4 s = texelFetch(farShadeSampler, clamp(b + o, ivec2(0), rsz - 1), 0);
		float rel = abs(s.z - dKm) / max(min(s.z, dKm), 0.002);
		vec2 bw = mix(1.0 - fr, fr, vec2(o));
		float w = bw.x * bw.y * exp2(-rel * 20.0) + 1e-6;
		sum += s.xy * w;
		sumW += w;
	}
	return sum / sumW;
}
#endif

#endif
