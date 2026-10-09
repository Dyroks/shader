in vec4 color;
in vec4 viewPos;
in vec3 tangent;
in vec3 binormal;
in vec3 worldPos;
in vec3 viewNormal;
in vec3 viewVector;
in vec2 blockLight;
flat in int materialID;

#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/Materials.inc"
#include "/lib/GBufferData.inc"

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
  allwaves /= 1.0 + dot(fwidth(position), vec3(10.0));

  return allwaves;
}

vec3 GetWaterParallaxCoord(in vec3 position)
{
	vec3 parallaxCoord = position.xyz;

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

void main() {
	if (PixelOutOfScreenBounds(gl_FragCoord.st)||texture2D(depthtex1,gl_FragCoord.st*ScreenTexel).r<1.0) {
		discard;
	}

	vec3 viewWorldPos = worldPos - cameraPosition;
    if (max(dot(viewWorldPos.xz, viewWorldPos.xz), viewWorldPos.y * viewWorldPos.y) < (far - 16.0) * (far - 16.0)) {
        discard;
    }

	GBufferDataTransparent gbuffer;
    vec4 albedo = color;

	vec3 normal = viewNormal;
	if (materialID == MAT_ID_WATER) {
		vec3 waterNormal = GetWavesNormal(worldPos);
		waterNormal = mat3(tangent, binormal, normal) * waterNormal;
		vec3 viewDir = -normalize(viewPos.xyz);
		normal = normalize(waterNormal.xyz +
			(normal / (max(0.0, dot(normal, viewDir)) + 0.001)) * 0.2);
	}

	gbuffer.albedo = albedo;
	gbuffer.normal = normal;
	gbuffer.geoNormal = viewNormal;
	gbuffer.materialID = materialID / 255.0;
	gbuffer.smoothness = 1.0;
	gbuffer.mcLightmap = blockLight;
	gbuffer.depth = 0.0;

	vec4 data0, data1;
	OutputGBufferDataTransparent(gbuffer, data0, data1);
	gl_FragData[0] = data0;
	gl_FragData[1] = data1;
}

/* DRAWBUFFERS:12 */
