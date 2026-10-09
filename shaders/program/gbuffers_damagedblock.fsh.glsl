in vec4 color;
in vec4 texcoord;
in vec3 worldNormal;
in vec2 blockLight;
flat in float materialIDs;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"


void main()
{
	if (PixelOutOfScreenBounds(gl_FragCoord.st)) {
		discard;
	}
	float lodOffset = 0.0;

	vec4 albedo = texture2D(texture, texcoord.st, lodOffset);
	albedo *= color;

	vec2 mcLightmap = blockLight;


	float wetnessModulator = 1.0;

	wetnessModulator *= saturate(worldNormal.y * 10.5 + 0.7);
	wetnessModulator *= saturate(abs(2.0 - materialIDs));
	wetnessModulator *= clamp(blockLight.y * 1.05 - 0.7, 0.0, 0.3) / 0.3;
	wetnessModulator *= saturate(wetness * 1.1 - 0.1);


	// Get specular data from specular texture
	vec4 specTex = texture2D(specular, texcoord.st, lodOffset);
	float metallic = specTex[SPEC_CHANNEL_METALNESS];


	// Darker albedo when wet
	albedo.rgb = pow(albedo.rgb, vec3(1.0 + wetnessModulator * (1.0 - metallic) * 0.3));


	gl_FragData[0] = albedo;
}

/* DRAWBUFFERS:0 */
