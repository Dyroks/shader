// =====================================================================================
//  Distant terrain shading: sun shadows of the distant relief and ambient occlusion beyond
//  the voxel volume, computed by deferred12_a.csh at a quarter of the internal resolution
//  (farShade), applied by deferred12.
// =====================================================================================

#ifndef FAR_SHADING_INC
#define FAR_SHADING_INC

const int farShadowSteps = 24;        // march toward the sun
const float farShadowReach = 4000.0;  // blocks
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
