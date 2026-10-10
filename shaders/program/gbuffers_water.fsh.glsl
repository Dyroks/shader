in mat3 tbnMatrix;
in vec4 texcoord;
in vec4 viewPosition;
in vec3 worldPosition;
in vec3 viewVector;
in vec3 worldNormal;
in vec3 normal;
in vec2 blockLight;
flat in float isWater;
flat in float isStainedGlass;
flat in float isSlime;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/GBufferData.inc"
#include "/lib/PhysicsOcean.inc"

#ifdef PHYSICS_OCEAN
    in vec3 physics_localPosition;
    in float physics_localWaviness;
#endif

vec4 textureSmooth(in vec2 coord)
{
	coord *= 64.0f;
	coord += 0.5f;

	vec2 whole = floor(coord);
	vec2 part  = fract(coord);

	part *= part * (3.0f - 2.0f * part);

	coord = whole + part - 0.5f;
	coord /= 64.0f;

	return texture2D(noisetex, coord);
}

// Wave amplitude fade with the pixel footprint, computed once in main(): fwidth() inside the parallax
// loop (divergent control flow) was undefined
float waveFade = 1.0;

float AlmostIdentity(in float x)
{
	if (x > 0.2) return x;

	return 0.1 * x * x + 0.1;
}

float GetWaves(vec3 position)
{
  float speed = 0.9f * frameTimeCounter;

  vec2 p = position.xz / 5.0f;


  p.xy -= position.y / 10.0f;

  p.x = -p.x;

  p.x += (speed / 40.0f);
  p.y -= (speed / 40.0f);

  float allwaves = 0.0f;
  float wave = textureSmooth((p * vec2(2.0f, 1.2f)) + vec2(0.0f,  p.x * 2.1f)).x;	p /= 2.1f;	p.y -= speed / 20.0f; p.x -= speed / 30.0f;
  allwaves += wave * 0.5;

      wave = textureSmooth( (p * vec2(2.0f, 1.4f))  + vec2(0.0f, -p.x * 2.1f)).x;	p /= 1.5f;	p.x += speed / 20.0f;
      wave *= 2.1f;
  allwaves += wave;

      wave = textureSmooth( (p * vec2(1.0f, 0.75f)) + vec2(0.0f,  p.x * 1.1f)).x;	p /= 1.5f;	p.x -= speed / 55.0f;
      wave *= 17.25f;
  allwaves += wave;

      wave = textureSmooth( (p * vec2(1.0f, 0.75f)) + vec2(0.0f, -p.x * 1.7f)).x;	p /= 1.9f;	p.x += speed / 155.0f;
      wave *= 15.25f;
  allwaves += wave;

      wave = abs(textureSmooth((p * vec2(1.0f, 0.8f)) + vec2(0.0f, -p.x * 1.7f)).x * 2.0f - 1.0f);	p /= 2.0f; p.x += speed / 155.0f;
      wave = 1.0f - AlmostIdentity(wave);
      wave *= 29.25f;
  allwaves += wave;

      wave = abs(textureSmooth((p * vec2(1.0f, 0.8f)) + vec2(0.0f,  p.x * 1.7f)).x * 2.0f - 1.0f);
      wave = 1.0f - AlmostIdentity(wave);
      wave *= 15.25f;
  allwaves += wave;

  allwaves /= 80.1;
  allwaves *= waveFade;

  return allwaves;
}

vec3 GetWaterParallaxCoord(in vec3 position)
{
	vec3 parallaxCoord = position.xyz;

	// The relief fades out with the waves themselves: none where they are nearly flat (far away)
	float parallaxWeight = smoothstep(0.15, 0.3, waveFade);
	if (parallaxWeight <= 0.0)
		return position;

	vec3 stepScale = vec3(0.6f * WATER_WAVE_HEIGHT, 0.6f * WATER_WAVE_HEIGHT, 1.0f) * 0.5;

	float waveHeight = GetWaves(position);

		vec3 pCoord = vec3(0.0f, 0.0f, 1.0f);

		vec3 stepSize = viewVector * stepScale;

		float sampleHeight = waveHeight;

		for (int i = 0; sampleHeight < pCoord.z && i < 60; ++i)
		{
			pCoord.xy = mix(pCoord.xy, pCoord.xy + stepSize.xy, clamp((pCoord.z - sampleHeight) / (stepScale.z * 0.2f / (-viewVector.z + 0.05f)), 0.0f, 1.0f));
			pCoord.z += stepSize.z;
			sampleHeight = GetWaves(position + vec3(pCoord.x, 0.0f, pCoord.y));
		}

	pCoord.xy *= parallaxWeight;
	parallaxCoord = position.xyz + vec3(pCoord.x, 0.0f, pCoord.y);

	return parallaxCoord;
}

vec3 GetWavesNormal(vec3 position)
{

	#ifdef WATER_PARALLAX
	position = GetWaterParallaxCoord(position);
	#endif


	position -= vec3(0.02f, 0.0f, 0.02f);

	float wavesCenter = GetWaves(position);
	float wavesLeft = GetWaves(position + vec3(0.04f, 0.0f, 0.0f));
	float wavesUp   = GetWaves(position + vec3(0.0f, 0.0f, 0.04f));

	vec3 wavesNormal;
		 wavesNormal.r = wavesCenter - wavesLeft;
		 wavesNormal.g = wavesCenter - wavesUp;

		 wavesNormal.rg *= 5.0f * WATER_WAVE_HEIGHT;


    wavesNormal.b = 1.0;
	wavesNormal.rgb = normalize(wavesNormal.rgb);


	return wavesNormal.rgb;
}




vec3 GetRainAnimationTex(sampler2D tex, vec2 uv)
{
	float frame = floor(fract(frameTimeCounter) * 60.0);
	vec2 coord = vec2(uv.x, fract(uv.y / 60.0) - frame / 60.0);

	vec3 n = texture2D(tex, coord).rgb * 2.0 - 1.0;
	n.y = -n.y;

	n.xy = pow(abs(n.xy), vec2(0.8)) * sign(n.xy);

	return n;
}

vec3 BilateralRainTex(sampler2D tex, vec2 uv)
{
	vec3 n = GetRainAnimationTex(tex, uv.xy);
	vec3 nR = GetRainAnimationTex(tex, uv.xy + vec2(1.0, 0.0) / 128.0);
	vec3 nU = GetRainAnimationTex(tex, uv.xy + vec2(0.0, 1.0) / 128.0);
	vec3 nUR = GetRainAnimationTex(tex, uv.xy + vec2(1.0, 1.0) / 128.0);

	vec2 fractCoord = fract(uv.xy * 128.0);

	vec3 lerpX = mix(n, nR, fractCoord.x);
	vec3 lerpX2 = mix(nU, nUR, fractCoord.x);
	vec3 lerpY = mix(lerpX, lerpX2, fractCoord.y);

	return lerpY;
}

vec3 GetRainNormal(in vec3 pos)
{
	if (rainStrength < 0.01)
		return vec3(0.0, 0.0, 1.0);

	pos.xyz *= 0.5;


	#ifdef RAIN_SPLASH_BILATERAL
	vec3 n = BilateralRainTex(gaux2, pos.xz);
	#else
	vec3 n = GetRainAnimationTex(gaux2, pos.xz);
	#endif

	pos.x -= frameTimeCounter * 1.5;
	float downfall = texture2D(noisetex, pos.xz * 0.0025).x;
	downfall = saturate(downfall * 1.5 - 0.25);

	n *= 0.4;

	float lod = dot(abs(fwidth(pos.xyz)), vec3(20.0));

	n.xy /= 1.1 + lod * 1.1;

	n.xy *= rainStrength;

	vec3 rainFlowNormal = vec3(0.0, 0.0, 1.0);
	float rainWeight = isWater > 0.5 ? abs(worldNormal.y) : saturate(worldNormal.y);

	n = mix(rainFlowNormal, n, rainWeight);

	n = mix(vec3(0, 0, 1), n, clamp(blockLight.y * 1.05 - 0.9, 0.0, 0.1) / 0.1);

	return n;
}

vec3 SlimeJiggleNormal(vec3 texNormal)
{
	vec3 p = worldPosition.xyz * 0.7 + frameTimeCounter * 0.5;

	texNormal.x += simplex3d(p 		);
	texNormal.y += simplex3d(p + 2.0);
	texNormal.xy *= 0.05;

	texNormal = normalize(texNormal);

	return texNormal;
}

void main() {
	#ifdef PHYSICS_OCEAN
		WavePixelData physics_waveData = physics_wavePixel(physics_localPosition.xz, physics_localWaviness, physics_iterationsNormal, physics_gameTime);
	#endif
	if (PixelOutOfScreenBounds(gl_FragCoord.st)) {
		discard;
	}
	vec4 tex = texture2D(texture, texcoord.st);
	#ifdef MC_SPECULAR_MAP
		float smoothness = texture2D(specular, texcoord.st).r;
		smoothness = mix(1.0, smoothness, step(0.001, smoothness));
	#else
		float smoothness = 1.0;
	#endif


	float matID = 1.0f;

	if (isWater > 0.5)
	{
		smoothness = 1.0;
		tex = vec4(0.0, 0.0, 0.0f, 0.2);
		matID = 6.0f;
	}

	if (isStainedGlass > 0.5 || isSlime > 0.5)
	{
		matID = 7.0;
	}

	matID += 0.1f;

	vec3 geoNormal = normal;
	// waves only where they are used: not on stained glass and slime, not under the physics ocean
	vec3 wavesNormal = vec3(0.0, 0.0, 1.0);
	#ifndef PHYSICS_OCEAN
	waveFade = 1.0 / (1.0 + dot(fwidth(worldPosition), vec3(10.0)));
	if (isStainedGlass < 0.5 && isSlime < 0.5)
		wavesNormal = GetWavesNormal(worldPosition);
	#endif
	#ifdef PHYSICS_OCEAN
        #ifndef PHYSICS_OCEAN_V2
            physics_waveData.normal.xz *= 0.5;
        #endif
		wavesNormal = normalize(mat3(gbufferModelView) * physics_waveData.normal);
		wavesNormal = dot(wavesNormal, viewPosition.xyz) > 0.0 ? -wavesNormal : wavesNormal;
		geoNormal = wavesNormal;
	#endif

	vec3 waterNormal = wavesNormal;
	#ifdef MC_NORMAL_MAP
		vec3 texNormal = texture2D(normals, texcoord.st).rgb * 2.0f - 1.0f;
	#else
		vec3 texNormal = vec3(0.0, 0.0, 1.0);
	#endif

    if(isSlime > 0.5)
        waterNormal = SlimeJiggleNormal(texNormal);
    else if(isStainedGlass > 0.5)
        waterNormal = texNormal;

	#ifdef RAIN_SPLASH_EFFECT
		waterNormal = normalize(waterNormal + GetRainNormal(worldPosition.xyz) * vec3(1.0, 1.0, 0.0));
	#endif
	#ifndef PHYSICS_OCEAN
		waterNormal = waterNormal * tbnMatrix;

		// Fix impossible normal angles
		vec3 viewDir = normalize(-viewPosition.xyz);
		waterNormal.xyz = normalize(waterNormal.xyz +
			(normal / (max(0.0, dot(normal, viewDir)) + 0.001)) * 0.2);
	#endif





	GBufferDataTransparent gbuffer;

	gbuffer.albedo = tex;
	gbuffer.normal = waterNormal.xyz;
	gbuffer.geoNormal = geoNormal;
	gbuffer.materialID = matID / 255.0;
	gbuffer.smoothness = smoothness;
	gbuffer.mcLightmap = blockLight;
	gbuffer.depth = 0.0;

	vec4 data0, data1;

	OutputGBufferDataTransparent(gbuffer, data0, data1);

	gl_FragData[0] = data0;
	gl_FragData[1] = data1;

}

/* DRAWBUFFERS:12 */
