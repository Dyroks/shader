
const float weights[5] = float[5](0.27343750, 0.21875000, 0.10937500, 0.03125000, 0.00390625);



////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////// Bloom Pass 0 /////////////////////////////////////////////////////////////////////////////////////
vec3 GrabBlur(vec2 coord, const float level, const vec2 offset)
{
	float octave = exp2(level);
	coord += offset;
	coord *= octave;

	vec2 texel = octave * ScreenTexel;
	float lod = level - 1.0;

	if (abs(coord.x - 0.5) > 0.5 + 10.0 * texel.x || abs(coord.y - 0.5) > 0.5 + 10.0 * texel.y)
		return vec3(0.0);

	vec3 color = GammaToLinear(texture2DLod(colortex7, saturate(coord), lod).rgb) * 0.5;
	color += GammaToLinear(texture2DLod(colortex7, saturate(coord + vec2(-0.5, 0.5) * texel), lod).rgb) * 0.125;
	color += GammaToLinear(texture2DLod(colortex7, saturate(coord + vec2(-0.5,-0.5) * texel), lod).rgb) * 0.125;
	color += GammaToLinear(texture2DLod(colortex7, saturate(coord + vec2( 0.5, 0.5) * texel), lod).rgb) * 0.125;
	color += GammaToLinear(texture2DLod(colortex7, saturate(coord + vec2( 0.5,-0.5) * texel), lod).rgb) * 0.125;

	return color;
}

vec2 bloomPadding = ScreenTexel * 30.0;

vec2 GetBloomLevelOffset(float octave)
{
    octave += 0.0001;	// AMD FIX

    vec2 offset = vec2(0.0);
    float floorOctave = min(1.0, floor(octave / 3.0));
    offset.x = -floorOctave * (0.25 + bloomPadding.x);
    offset.y = -1.0 + exp2(-octave) - bloomPadding.y * octave;
	offset.y += floorOctave * 0.35;

 	return offset;
}


vec3 CalculateBloomPass0(vec2 coord)
{
	vec3 bloomColor = vec3(0.0);
	bloomColor += GrabBlur(coord, 1.0, vec2(0.0, 0.0));
	bloomColor += GrabBlur(coord, 2.0, GetBloomLevelOffset(1.0));
	bloomColor += GrabBlur(coord, 3.0, GetBloomLevelOffset(2.0));
	bloomColor += GrabBlur(coord, 4.0, GetBloomLevelOffset(3.0));
	bloomColor += GrabBlur(coord, 5.0, GetBloomLevelOffset(4.0));
	bloomColor += GrabBlur(coord, 6.0, GetBloomLevelOffset(5.0));
	bloomColor += GrabBlur(coord, 7.0, GetBloomLevelOffset(6.0));
	bloomColor += GrabBlur(coord, 8.0, GetBloomLevelOffset(7.0));
	bloomColor += GrabBlur(coord, 9.0, GetBloomLevelOffset(8.0));

	bloomColor = LinearToGamma(bloomColor);

	return bloomColor;
}






////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////// Bloom Pass 1 /////////////////////////////////////////////////////////////////////////////////////
vec3 BlurH(vec2 coord)
{
	vec3 color = vec3(0.0);

	color += GammaToLinear(texture2DLod(colortex7, coord, 0).rgb) * weights[0];

	for (int i = 1; i < 5; i++)
	{
		vec2 coordOffset = vec2(i * ScreenTexel.x, 0.0);
		color += (GammaToLinear(texture2DLod(colortex7, coord + coordOffset, 0).rgb) + GammaToLinear(texture2DLod(colortex7, coord - coordOffset, 0).rgb)) * weights[i];
	}

	return color;
}

vec3 CalculateBloomPass1(vec2 coord)
{
	return LinearToGamma(BlurH(coord));
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////// Bloom Pass 2 /////////////////////////////////////////////////////////////////////////////////////
vec3 BlurV(vec2 coord)
{
	vec3 color = vec3(0.0);

	color += GammaToLinear(texture2DLod(colortex7, coord, 0).rgb) * weights[0];

	for (int i = 1; i < 5; i++)
	{
		vec2 coordOffset = vec2(0.0, i * ScreenTexel.y);
		color += (GammaToLinear(texture2DLod(colortex7, coord + coordOffset, 0).rgb) + GammaToLinear(texture2DLod(colortex7, coord - coordOffset, 0).rgb)) * weights[i];
	}

	return color;
}

vec3 CalculateBloomPass2(vec2 coord)
{
	return BlurV(coord);
}







////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////// Final retrieval of bloom /////////////////////////////////////////////////////////////////////////
vec4 cubic(float x)
{
    float x2 = x * x;
    float x3 = x2 * x;
    vec4 w;
    w.x =   -x3 + 3*x2 - 3*x + 1;
    w.y =  3*x3 - 6*x2       + 4;
    w.z = -3*x3 + 3*x2 + 3*x + 1;
    w.w =  x3;
    return w / 6.f;
}

vec4 BicubicTexture(in sampler2D tex, in vec2 coord)
{
	vec2 resolution = ScreenSize;

	coord *= resolution;

	float fx = fract(coord.x);
    float fy = fract(coord.y);
    coord.x -= fx;
    coord.y -= fy;

    vec4 xcubic = cubic(fx);
    vec4 ycubic = cubic(fy);

    vec4 c = vec4(coord.x - 0.5, coord.x + 1.5, coord.y - 0.5, coord.y + 1.5);
    vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
    vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

    vec4 sample0 = texture2D(tex, vec2(offset.x, offset.z) / resolution);
    vec4 sample1 = texture2D(tex, vec2(offset.y, offset.z) / resolution);
    vec4 sample2 = texture2D(tex, vec2(offset.x, offset.w) / resolution);
    vec4 sample3 = texture2D(tex, vec2(offset.y, offset.w) / resolution);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

vec3 dualBlurUpSample(sampler2D sampleTex, vec2 uv) {
    vec3 totalColor = vec3(0.0);
    totalColor += texture2D(sampleTex, uv + vec2( 0.5, 0.5) * ScreenTexel).rgb * (1.0 / 6.0);
    totalColor += texture2D(sampleTex, uv + vec2( 0.5,-0.5) * ScreenTexel).rgb * (1.0 / 6.0);
    totalColor += texture2D(sampleTex, uv + vec2(-0.5, 0.5) * ScreenTexel).rgb * (1.0 / 6.0);
    totalColor += texture2D(sampleTex, uv + vec2(-0.5,-0.5) * ScreenTexel).rgb * (1.0 / 6.0);
    totalColor += texture2D(sampleTex, uv + vec2( 1.0, 0.0) * ScreenTexel).rgb * (1.0 / 12.0);
    totalColor += texture2D(sampleTex, uv + vec2(-1.0, 0.0) * ScreenTexel).rgb * (1.0 / 12.0);
    totalColor += texture2D(sampleTex, uv + vec2( 0.0, 1.0) * ScreenTexel).rgb * (1.0 / 12.0);
    totalColor += texture2D(sampleTex, uv + vec2( 0.0,-1.0) * ScreenTexel).rgb * (1.0 / 12.0);
    return totalColor;
}

vec3 GetBloomTap(vec2 coord, const float octave, const vec2 offset)
{
	coord /= octave;
	coord -= offset;

	// return GammaToLinear(BicubicTexture(BLOOM_TEX, coord).rgb);
	return dualBlurUpSample(colortex7, coord).rgb;
}

vec3 GetBloom(vec2 coord)
{
	vec3 bloom = vec3(0.0);

	bloom += GetBloomTap(coord, 2.0  , vec2(0.0))				 * 0.90909;
	bloom += GetBloomTap(coord, 4.0  , GetBloomLevelOffset(1.0)) * 0.82645;
	bloom += GetBloomTap(coord, 8.0  , GetBloomLevelOffset(2.0)) * 0.75131;
	bloom += GetBloomTap(coord, 16.0 , GetBloomLevelOffset(3.0)) * 0.68301;
	bloom += GetBloomTap(coord, 32.0 , GetBloomLevelOffset(4.0)) * 0.62092;
	bloom += GetBloomTap(coord, 64.0 , GetBloomLevelOffset(5.0)) * 0.56447;
	bloom += GetBloomTap(coord, 128.0, GetBloomLevelOffset(6.0)) * 0.51316;
	bloom += GetBloomTap(coord, 256.0, GetBloomLevelOffset(7.0)) * 0.46651;
	bloom += GetBloomTap(coord, 512.0, GetBloomLevelOffset(8.0)) * 0.42410;

	bloom /= 5.75902;

	return bloom;
}
