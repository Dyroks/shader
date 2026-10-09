in vec4 color;
in vec4 texcoord;
in vec4 viewPos;
in vec3 worldNormal;
in vec2 blockLight;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/GBufferData.inc"
#include "/lib/GBuffersCommon.inc"


void main()
{
	if (PixelOutOfScreenBounds(gl_FragCoord.st)) {
		discard;
	}
	float lodOffset = 0.0;

	vec4 albedo = texture2D(texture, texcoord.st, lodOffset);
	albedo *= color;

	if(albedo.w < 0.01) {
		discard;
	}

	vec2 mcLightmap = blockLight;


	float wetnessModulator = 1.0;

	wetnessModulator *= saturate(worldNormal.y * 10.5 + 0.7);
	wetnessModulator *= clamp(blockLight.y * 1.05 - 0.7, 0.0, 0.3) / 0.3;
	wetnessModulator *= saturate(wetness * 1.1 - 0.1);



	vec3 N;
	mat3 tbn;
	mat3 tbnRaw;
	CalculateNormalAndTBN(viewPos.xyz, texcoord.st, N, tbn, tbnRaw);




	// Get specular data from specular texture
	#ifdef MC_SPECULAR_MAP
		vec4 specTex = texture2D(specular, texcoord.st, lodOffset);
		float smoothness = specTex[SPEC_CHANNEL_SMOOTHNESS];
		float metallic = specTex[SPEC_CHANNEL_METALNESS];
		float emissive = specTex[SPEC_CHANNEL_EMISSIVE];
		#ifdef SPEC_SMOOTHNESS_AS_ROUGHNESS
			smoothness = 1.0 - smoothness;
		#endif
		smoothness = smoothness * 0.992; 						// Fix weird specular issue		
	#else
		float smoothness = 0.0;
		float metallic = 0.0;
		float emissive = 0.0;
	#endif
	#ifdef MC_NORMAL_MAP
		vec4 normalTex = texture2D(normals, texcoord.st, lodOffset) * 2.0 - 1.0;
	#else
		vec4 normalTex = vec4(0.0, 0.0, 1.0, 1.0);
	#endif

	float normalMapStrength = 2.0;
	#ifdef FORCE_WET_EFFECT
	normalMapStrength = mix(NORMAL_MAP_STRENGTH, 0.1, wetnessModulator * wetnessModulator * wetnessModulator * wetnessModulator);
	#endif

	vec3 viewNormal = tbn * normalize(normalTex.xyz * vec3(normalMapStrength, normalMapStrength, 1.0));



	#ifdef FORCE_WET_EFFECT
	smoothness = mix(smoothness, 1.0, saturate(wetnessModulator * saturate(1.0 - metallic)));
	#endif


	// Darker albedo when wet
	albedo.rgb = pow(albedo.rgb, vec3(1.0 + wetnessModulator * (1.0 - metallic) * 0.3));


	// Fix impossible normal angles
	vec3 viewDir = -normalize(viewPos.xyz);
	// make outright impossible
	viewNormal.xyz = normalize(viewNormal.xyz + N / (sqrt(saturate(dot(viewNormal, viewDir)) + 0.001)));


	GBufferDataTransparent gbuffer;


	gbuffer.albedo = albedo;
	gbuffer.normal = viewNormal.xyz;
	gbuffer.geoNormal = N.xyz;
	gbuffer.materialID = 7.1 / 255.0;
	gbuffer.smoothness = 1.0;
	gbuffer.mcLightmap = blockLight;
	gbuffer.depth = 0.0;

	vec4 data0, data1;

	OutputGBufferDataTransparent(gbuffer, data0, data1);

	gl_FragData[0] = data0;
	gl_FragData[1] = data1;

}

/* DRAWBUFFERS:12 */
