in vec4 color;
in vec4 texcoord;
in vec4 viewPos;
in vec4 endPortalCoord;
in vec3 worldPosition;
in vec3 worldNormal;
in vec2 blockLight;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/GBufferData.inc"
#include "/lib/GBuffersCommon.inc"
#include "/lib/Materials.inc"


const vec3[] COLORS = vec3[](
    vec3(0.022087, 0.098399, 0.110818),
    vec3(0.011892, 0.095924, 0.089485),
    vec3(0.027636, 0.101689, 0.100326),
    vec3(0.046564, 0.109883, 0.114838),
    vec3(0.064901, 0.117696, 0.097189),
    vec3(0.063761, 0.086895, 0.123646),
    vec3(0.084817, 0.111994, 0.166380),
    vec3(0.097489, 0.154120, 0.091064),
    vec3(0.106152, 0.131144, 0.195191),
    vec3(0.097721, 0.110188, 0.187229),
    vec3(0.133516, 0.138278, 0.148582),
    vec3(0.070006, 0.243332, 0.235792),
    vec3(0.196766, 0.142899, 0.214696),
    vec3(0.047281, 0.315338, 0.321970),
    vec3(0.204675, 0.390010, 0.302066),
    vec3(0.080955, 0.314821, 0.661491)
);

const mat4 SCALE_TRANSLATE = mat4(
    0.5, 0.0, 0.0, 0.25,
    0.0, 0.5, 0.0, 0.25,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0
);

mat2 mat2RotateZ(float radian) {
    return mat2(
        cos(radian), -sin(radian),
        sin(radian), cos(radian)
    );
}

mat4 endPortalLayer(float layer) {
    mat4 translate = mat4(
        1.0, 0.0, 0.0, 17.0 / layer,
        0.0, 1.0, 0.0, (2.0 + layer / 1.5) * (frameTimeCounter * 0.0015),
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0
    );

    mat2 rotate = mat2RotateZ(radians((layer * layer * 4321.0 + layer * 9.0) * 2.0));

    mat2 scale = mat2((4.5 - layer / 4.0) * 2.0);

    return mat4(scale * rotate) * translate * SCALE_TRANSLATE;
}


void main()
{
	if (PixelOutOfScreenBounds(gl_FragCoord.st)
		#ifdef BLOCK
			|| color.a < 0.99
		#else
			|| (dot(color.rgb, vec3(1.0)) < 0.001 && abs(color.a - 0.5) < 0.49)
		#endif
	) {
		discard;
	}
	float lodOffset = 0.0;

	vec4 albedo = texture2D(texture, texcoord.st, lodOffset);
	albedo *= color;

	vec2 mcLightmap = blockLight;

	float wetnessModulator = 1.0;

	vec3 rainNormal = vec3(0.0, 0.0, 0.0);
	#ifdef RAIN_SPLASH_EFFECT
	rainNormal = GetRainSplashNormal(worldPosition, worldNormal, wetnessModulator);
	#endif

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

	vec3 viewNormal = tbn * normalize(normalTex.xyz * vec3(normalMapStrength, normalMapStrength, 1.0) + rainNormal * wetnessModulator);


	#if SPEC_CHANNEL_EMISSIVE == 3
	emissive -= step(1.0, emissive);
	#endif

	if (blockEntityId == 138) {
		emissive = 1.0;
	}

	#ifdef FORCE_WET_EFFECT
	smoothness = mix(smoothness, 1.0, saturate(wetnessModulator * saturate(1.0 - metallic)));
	#endif

	// Darker albedo when wet
	albedo.rgb = pow(albedo.rgb, vec3(1.0 + wetnessModulator * (1.0 - metallic) * 0.3));


	// Fix impossible normal angles
	vec3 viewDir = -normalize(viewPos.xyz);
	vec3 relfectDir = reflect(-viewDir, viewNormal);
	// make outright impossible
	viewNormal.xyz = normalize(viewNormal.xyz + N / (sqrt(saturate(dot(viewNormal, viewDir)) + 0.001)));
	// Physics mod snow support
	if (dot(abs(dFdx(texcoord.st)) + abs(dFdy(texcoord.st)), vec2(1.0)) < 1e-6) {
		viewNormal.xyz = N;
		smoothness = 0.0;
		metallic = 0.0;
	}

	albedo.rgb = mix(albedo.rgb, entityColor.rgb, vec3(entityColor.a));


	GBufferData gbuffer;
	gbuffer.albedo = albedo;
	gbuffer.normal = viewNormal.xyz;
	gbuffer.mcLightmap = mcLightmap;
	gbuffer.smoothness = smoothness;
	gbuffer.metalness = metallic;
	gbuffer.materialID = (MAT_ID_DYNAMIC_ENTITY + 0.1) / 255.0;
	gbuffer.emissive = emissive;
	gbuffer.geoNormal = N.xyz;
	gbuffer.parallaxOffset = 0.0;
	gbuffer.depth = 0.0;

	#ifdef BLOCK
    if (blockEntityId == 119 || blockEntityId == 209) {
        gbuffer.albedo.rgb = textureProj(texture, endPortalCoord).rgb * COLORS[0];
        gbuffer.albedo.w = 1.0;
        for(int i = 1; i < 15; i++) {
            gbuffer.albedo.rgb += textureProj(texture, endPortalCoord * endPortalLayer(float(i + 1))).rgb * COLORS[i];
        }
        gbuffer.smoothness = 0.0;
        gbuffer.metalness = 0.0;
        gbuffer.emissive = 1.0;
    }
	#endif

	#ifndef SPEC_EMISSIVE
	gbuffer.emissive = 0.0;
	#endif

	vec4 frag0, frag1, frag2;

	OutputGBufferDataSolid(gbuffer, frag0, frag1, frag2);

	gl_FragData[0] = frag0;
	gl_FragData[1] = frag1;
	gl_FragData[2] = frag2;

}

/* DRAWBUFFERS:012 */
