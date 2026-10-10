// Progressive bloom (composite14_a .. composite14_i): one dispatch per bloom level, from the
// coarsest (9) to the finest (1). Level k of bloomAccum = weight k x level k of the blurred
// atlas (colortex7, composite11-13) + level k+1 of bloomAccum upsampled with the same tent as
// the final lookup. composite14 then reads level 1 only (8 taps instead of 9 levels x 8).
// BLOOM_LEVEL (1..9) is defined by the including program, before workGroupsRender.
layout(local_size_x = 8, local_size_y = 8) in;

uniform sampler2D colortex7;
uniform sampler2D bloomAccumSampler;
layout(rgba16f) uniform writeonly image2D bloomAccum;
uniform float viewWidth;
uniform float viewHeight;
uniform vec2 ScreenTexel;

// Same layout as Bloom.inc
vec2 GetBloomLevelOffset(float octave) {
	octave += 0.0001;
	vec2 bloomPadding = ScreenTexel * 30.0;
	vec2 offset = vec2(0.0);
	float floorOctave = min(1.0, floor(octave / 3.0));
	offset.x = -floorOctave * (0.25 + bloomPadding.x);
	offset.y = -1.0 + exp2(-octave) - bloomPadding.y * octave;
	offset.y += floorOctave * 0.35;
	return offset;
}

vec3 BloomTent(vec2 uv) {
	vec3 c = vec3(0.0);
	c += textureLod(bloomAccumSampler, uv + vec2( 0.5, 0.5) * ScreenTexel, 0.0).rgb * (1.0 / 6.0);
	c += textureLod(bloomAccumSampler, uv + vec2( 0.5,-0.5) * ScreenTexel, 0.0).rgb * (1.0 / 6.0);
	c += textureLod(bloomAccumSampler, uv + vec2(-0.5, 0.5) * ScreenTexel, 0.0).rgb * (1.0 / 6.0);
	c += textureLod(bloomAccumSampler, uv + vec2(-0.5,-0.5) * ScreenTexel, 0.0).rgb * (1.0 / 6.0);
	c += textureLod(bloomAccumSampler, uv + vec2( 1.0, 0.0) * ScreenTexel, 0.0).rgb * (1.0 / 12.0);
	c += textureLod(bloomAccumSampler, uv + vec2(-1.0, 0.0) * ScreenTexel, 0.0).rgb * (1.0 / 12.0);
	c += textureLod(bloomAccumSampler, uv + vec2( 0.0, 1.0) * ScreenTexel, 0.0).rgb * (1.0 / 12.0);
	c += textureLod(bloomAccumSampler, uv + vec2( 0.0,-1.0) * ScreenTexel, 0.0).rgb * (1.0 / 12.0);
	return c;
}

void main() {
		const float weights[9] = float[9](0.90909, 0.82645, 0.75131, 0.68301, 0.62092, 0.56447, 0.51316, 0.46651, 0.42410);
		vec2 screen = vec2(viewWidth, viewHeight);
		float octave = exp2(float(BLOOM_LEVEL));
		vec2 off = GetBloomLevelOffset(float(BLOOM_LEVEL - 1));
		// the level's tile and a margin of 4 texels (the upsampling taps reach 1 texel outside)
		ivec2 size = ivec2(ceil(screen / octave)) + 8;
		ivec2 p = ivec2(gl_GlobalInvocationID.xy);
		if (any(greaterThanEqual(p, size))) return;
		ivec2 px = ivec2(floor(-off * screen)) - 4 + p;
		if (any(lessThan(px, ivec2(0))) || any(greaterThanEqual(px, ivec2(screen)))) return;
		vec2 uv = (vec2(px) + 0.5) / screen;
		vec3 c = texelFetch(colortex7, px, 0).rgb * weights[BLOOM_LEVEL - 1];
		#if BLOOM_LEVEL < 9
			// position in the level, then in the next coarser level of the atlas
			vec2 x = (uv + off) * octave;
			c += BloomTent(x / (octave * 2.0) - GetBloomLevelOffset(float(BLOOM_LEVEL)));
		#endif
		imageStore(bloomAccum, px, vec4(c, 1.0));
}
