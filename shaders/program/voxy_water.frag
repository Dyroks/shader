layout(location = 0) out vec4 gbufferData0;
layout(location = 1) out vec4 gbufferData1;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

#include "/lib/Settings.inc"
#include "/lib/Materials.inc"
#include "/lib/Common.inc"
#include "/lib/GBufferData.inc"
#include "/lib/PhysicsOcean.inc"

vec4 textureSmooth(in vec2 coord)
{
	coord *= 64.0f;
	coord += 0.5f;

	vec2 whole = floor(coord);
	vec2 part  = fract(coord);

	part *= part * (3.0f - 2.0f * part);

	coord = whole + part - 0.5f;
	coord /= 64.0f;

	return textureLod(noisetex, coord, 0.0);
}

float AlmostIdentity(in float x)
{
	if (x > 0.2) return x;

	return 0.1 * x * x + 0.1;
}

float GetWaves(vec3 position, float fadeFactor)
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
  allwaves *= fadeFactor;

  return allwaves;
}

vec3 GetWaterParallaxCoord(in vec3 position, vec3 viewVector, float fadeFactor)
{
	vec3 parallaxCoord = position.xyz;

	vec3 stepScale = vec3(0.6f * WATER_WAVE_HEIGHT, 0.6f * WATER_WAVE_HEIGHT, 1.0f) * 0.5;

	float waveHeight = GetWaves(position, fadeFactor);

		vec3 pCoord = vec3(0.0f, 0.0f, 1.0f);

		vec3 stepSize = viewVector * stepScale;

		float sampleHeight = waveHeight;

		for (int i = 0; sampleHeight < pCoord.z && i < 60; ++i)
		{
			pCoord.xy = mix(pCoord.xy, pCoord.xy + stepSize.xy, clamp((pCoord.z - sampleHeight) / (stepScale.z * 0.2f / (-viewVector.z + 0.05f)), 0.0f, 1.0f));
			pCoord.z += stepSize.z;
			sampleHeight = GetWaves(position + vec3(pCoord.x, 0.0f, pCoord.y), fadeFactor);
		}

	parallaxCoord = position.xyz + vec3(pCoord.x, 0.0f, pCoord.y);

	return parallaxCoord;
}

vec3 GetWavesNormal(vec3 position, vec3 viewVector, float fadeFactor)
{

	#ifdef WATER_PARALLAX
	position = GetWaterParallaxCoord(position, viewVector, fadeFactor);
	#endif


	position -= vec3(0.02f, 0.0f, 0.02f);

	float wavesCenter = GetWaves(position, fadeFactor);
	float wavesLeft = GetWaves(position + vec3(0.04f, 0.0f, 0.0f), fadeFactor);
	float wavesUp   = GetWaves(position + vec3(0.0f, 0.0f, 0.04f), fadeFactor);

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

	vec3 n = textureLod(tex, coord, 0.0).rgb * 2.0 - 1.0;
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

vec3 GetRainNormal(in vec3 pos, vec3 worldNormal, vec2 blockLight, float matID, float fadeFactor)
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
	float downfall = textureLod(noisetex, pos.xz * 0.0025, 0.0).x;
	downfall = saturate(downfall * 1.5 - 0.25);

	n *= 0.4;

	n.xy *= fadeFactor;

	n.xy *= rainStrength;

	vec3 rainFlowNormal = vec3(0.0, 0.0, 1.0);
	float rainWeight = abs(matID - 6.1) < 0.1 ? abs(worldNormal.y) : saturate(worldNormal.y);

	n = mix(rainFlowNormal, n, rainWeight);

	n = mix(vec3(0, 0, 1), n, clamp(blockLight.y * 1.05 - 0.9, 0.0, 0.1) / 0.1);

	return n;
}

vec3 SlimeJiggleNormal(vec3 texNormal, vec3 worldPosition)
{
	vec3 p = worldPosition.xyz * 0.7 + frameTimeCounter * 0.5;

	texNormal.x += simplex3d(p 		);
	texNormal.y += simplex3d(p + 2.0);
	texNormal.xy *= 0.05;

	texNormal = normalize(texNormal);

	return texNormal;
}

void voxy_emitFragment(VoxyFragmentParameters parameters) {
	vec4 tex = parameters.sampledColour * parameters.tinting;

    vec3 worldNormal = vec3(
        float((parameters.face >> 2) & 1u),
        0.0,
        float((parameters.face >> 1) & 1u)
    );
    worldNormal.y = 1.0 - worldNormal.x - worldNormal.z;
    worldNormal *= uintBitsToFloat((parameters.face << 31) ^ 0xBF800000u);
    vec3 viewNormal = mat3(gbufferModelView) * worldNormal;

	vec2 blockLight = clamp(parameters.lightMap * 16.0 / 15.0 - 0.5 / 15.0, 0.0, 1.0);

    float blockId = parameters.customId;
	float matID = 7.0;
	if(blockId == 8 || blockId == 9 || blockId == 389)
	{
		tex = vec4(0.0, 0.0, 0.0f, 0.2);
		matID = 6.0f;
	}

	if (blockId == 165)
	{
		matID = 7.0;
	}

	matID += 0.1f;

    vec3 tangent = mat3(gbufferModelView) * vec3(abs(worldNormal.y) + worldNormal.z, 0.0, -worldNormal.x);
    vec3 bitangent = mat3(gbufferModelView) * vec3(0.0, abs(worldNormal.y) - 1.0, worldNormal.y);
    mat3 tbn = mat3(tangent, bitangent, viewNormal);

    vec4 viewPosition = GetViewPositionLod(gl_FragCoord.st * ScreenTexel, gl_FragCoord.z);
    vec3 worldPosition = mat3(gbufferModelViewInverse) * viewPosition.xyz + gbufferModelViewInverse[3].xyz + cameraPosition;

	float viewDepthInv = inversesqrt(dot(viewPosition.xyz, viewPosition.xyz));
    vec3 viewDir = viewPosition.xyz * -viewDepthInv;
    float fadeFactor = viewDepthInv * dot(viewDir, tbn[2]) * gbufferProjection[1].y * viewHeight;
	fadeFactor = fadeFactor / (fadeFactor + 50.0);

	vec3 wavesNormal = GetWavesNormal(worldPosition, viewPosition.xyz * tbn, fadeFactor);

	vec3 waterNormal = wavesNormal;
    vec3 texNormal = vec3(0.0, 0.0, 1.0);

    if(blockId == 165)
        waterNormal = SlimeJiggleNormal(texNormal, worldPosition);
    else if(matID == 7.0)
        waterNormal = texNormal;

	#ifdef RAIN_SPLASH_EFFECT
		waterNormal = normalize(waterNormal + GetRainNormal(worldPosition, worldNormal, blockLight, matID, fadeFactor) * vec3(1.0, 1.0, 0.0));
	#endif
    waterNormal = tbn * waterNormal;

    // Fix impossible normal angles
    waterNormal.xyz = normalize(waterNormal.xyz +
        (viewNormal / (max(0.0, dot(viewNormal, viewDir)) + 0.001)) * 0.2);





	GBufferDataTransparent gbuffer;

	gbuffer.albedo = tex;
	gbuffer.normal = waterNormal.xyz;
	gbuffer.geoNormal = viewNormal;
	gbuffer.materialID = matID / 255.0;
	gbuffer.smoothness = 1.0;
	gbuffer.mcLightmap = blockLight;
	gbuffer.depth = 0.0;

	vec4 data0, data1;

	OutputGBufferDataTransparent(gbuffer, data0, data1);

	gbufferData0 = data0;
	gbufferData1 = data1;
}
