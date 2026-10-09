layout(location = 0) out vec4 gbufferData0;
layout(location = 1) out vec4 gbufferData1;
layout(location = 2) out vec4 gbufferData2;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

#include "/lib/Settings.inc"
#include "/lib/Materials.inc"
#include "/lib/Common.inc"
#include "/lib/GBufferData.inc"
#include "/lib/GBuffersCommon.inc"

void voxy_emitFragment(VoxyFragmentParameters parameters)
{
	GBufferData gbuffer;

	vec4 albedo = parameters.sampledColour * parameters.tinting;

    vec3 worldNormal = vec3(
        float((parameters.face >> 2) & 1u),
        0.0,
        float((parameters.face >> 1) & 1u)
    );
    worldNormal.y = 1.0 - worldNormal.x - worldNormal.z;
    worldNormal *= uintBitsToFloat((parameters.face << 31) ^ 0xBF800000u);
    vec3 viewNormal = mat3(gbufferModelView) * worldNormal;

	vec2 mcLightmap = clamp(parameters.lightMap * 16.0 / 15.0 - 0.5 / 15.0, 0.0, 1.0);

    float blockId = parameters.customId;
    float materialIDs = 1.0;
    float s=abs(normalize(worldNormal.xz).x),l=abs(worldNormal.y);
    if(blockId==31.||abs(blockId-37.5)<1.0f)
        materialIDs=MAT_ID_GRASS;
    if(blockId==59.||blockId==175.f)
        materialIDs=MAT_ID_GRASS;
    if(blockId==18.||blockId==161.f&&(parameters.tinting.x<.999||parameters.tinting.y<.999||parameters.tinting.z<.999))
        materialIDs=MAT_ID_LEAVES;
    if(blockId==50||blockId==52||abs(blockId-92.5)<1.||blockId==124||abs(blockId-182.5)<2||abs(blockId-190.5)<2||blockId==198||blockId==213)
        materialIDs=MAT_ID_TORCH;
    if(blockId==197)
        materialIDs=MAT_ID_GLOW_LICHEN;
    if(blockId==199)
        materialIDs=MAT_ID_GLOW_BERRIES;
    if(blockId==10||blockId==11)
        materialIDs=MAT_ID_LAVA;
    if(blockId==89||blockId==91||abs(blockId-148.5)<2.||blockId==169)
        materialIDs=MAT_ID_GLOWSTONE;
    if(blockId==138)
        materialIDs=MAT_ID_BEACON;
    #ifdef GLOWING_REDSTONE_BLOCK
    if(blockId==152)
        materialIDs=MAT_ID_GLOWSTONE;
    #endif
    #ifdef GLOWING_LAPIS_LAZULI_BLOCK
    if(blockId==22)
        materialIDs=MAT_ID_GLOWSTONE;
    #endif
    #ifdef GLOWING_EMERALD_BLOCK
    if(blockId==133)
        materialIDs=MAT_ID_GLOWSTONE;
    #endif
    if(blockId==79||blockId==95||blockId==165)
        materialIDs=MAT_ID_STAINED_GLASS;
    if(blockId==51||blockId==53)
        materialIDs=MAT_ID_FIRE;
    if(blockId==74||blockId==76||blockId==117||abs(blockId-194.5)<2)
        materialIDs=MAT_ID_LIT_FURNACE;

	gbuffer.parallaxOffset = 0.0;

	float wetnessModulator = 1.0;

	vec3 rainNormal = vec3(0.0, 0.0, 0.0);

    vec4 viewPos = GetViewPositionLod(gl_FragCoord.st * ScreenTexel, gl_FragCoord.z);
	#ifdef RAIN_SPLASH_EFFECT
	vec4 rainPosition = viewPos + vec4(0.0, 0.0, (1.0 - gbuffer.parallaxOffset) * 0.5, 0.0);
	rainPosition = gbufferModelViewInverse * rainPosition;
	rainNormal = GetRainSplashNormal(rainPosition.xyz + cameraPosition, worldNormal, wetnessModulator);
	#endif

	wetnessModulator *= saturate(worldNormal.y * 10.5 + 0.7);
	wetnessModulator *= saturate(abs(2.0 - materialIDs));
	wetnessModulator *= clamp(mcLightmap.y * 1.05 - 0.7, 0.0, 0.3) / 0.3;
	wetnessModulator *= saturate(wetness * 1.1 - 0.1);

    vec3 tangent = mat3(gbufferModelView) * vec3(abs(worldNormal.y) + worldNormal.z, 0.0, -worldNormal.x);
    vec3 bitangent = mat3(gbufferModelView) * vec3(0.0, abs(worldNormal.y) - 1.0, worldNormal.y);
    mat3 tbn = mat3(tangent, bitangent, viewNormal);

	// Get specular data from specular texture
    viewNormal = tbn * normalize(vec3(0.0, 0.0, 1.0) + rainNormal * wetnessModulator * vec3(1.0, 1.0, 0.0));

    float smoothness = 0.0;
    float metallic = 0.0;
    float emissive = 0.0;
	#ifdef FORCE_WET_EFFECT
	smoothness = mix(smoothness, 1.0, saturate(wetnessModulator * saturate(1.0 - metallic) * max(1.0 - isEyeInWater, 0.0)));
	#endif

	// Darker albedo when wet
	albedo.rgb = pow(albedo.rgb, vec3(1.0 + wetnessModulator * (1.0 - metallic) * 0.1));


	// Fix impossible normal angles
	vec3 viewDir = -normalize(viewPos.xyz);
	// make outright impossible
	viewNormal.xyz = normalize(viewNormal.xyz + tbn[2] / (sqrt(saturate(dot(viewNormal, viewDir)) + 0.001)));

	#ifdef WET_CAVE_EFFECT
	float caveDamp = 1.0 - metallic;
	caveDamp *= pow((1.0 - mcLightmap.y), 2.0);
	caveDamp *= pow((1.0 - mcLightmap.x), 1.0);
	smoothness = mix(smoothness, 1.0, 0.9 * caveDamp);
	#endif

	float isTransparent = step(abs(materialIDs - 7.), 0.5);
	metallic *= 1.0 - isTransparent;
	smoothness = mix(smoothness, 0.992, isTransparent);

	gbuffer.albedo = albedo;
	gbuffer.normal = viewNormal.xyz;
	gbuffer.mcLightmap = mcLightmap;
	gbuffer.smoothness = smoothness;
	gbuffer.metalness = metallic;
	gbuffer.materialID = (materialIDs + 0.1) / 255.0;
	gbuffer.emissive = emissive;
	gbuffer.geoNormal = tbn[2];
	gbuffer.depth = 0.0;

	#ifndef SPEC_EMISSIVE
	gbuffer.emissive = 0.0;
	#endif


	vec4 frag0, frag1, frag2;

	OutputGBufferDataSolid(gbuffer, frag0, frag1, frag2);

	gbufferData0 = frag0;
	gbufferData1 = frag1;
	gbufferData2 = frag2;

}
