in vec4 color;
in vec3 worldPos;
in vec3 viewNormal;
in vec2 blockLight;
flat in int materialID;

#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/GBufferData.inc"
#include "/lib/GBuffersCommon.inc"

void main() {
	GBufferData gbuffer;
	if (PixelOutOfScreenBounds(gl_FragCoord.st)) {
		discard;
	}

	vec3 viewWorldPos = worldPos - cameraPosition;
    if (max(dot(viewWorldPos.xz, viewWorldPos.xz), viewWorldPos.y * viewWorldPos.y) < (far - 16.0) * (far - 16.0)) {
        discard;
    }

	vec4 albedo = color;
	ivec3 pixelPos = ivec3(floor(worldPos * 16.0 + 1e-3));
	ivec2 texel = (pixelPos.xz + 17 * pixelPos.y) & 63;
	float noise = texelFetch(noisetex, texel, 0).r;
	albedo.rgb = pow(albedo.rgb, vec3(noise * 0.3 + 0.85));

	vec3 worldNormal = mat3(gbufferModelViewInverse) * viewNormal;

	float wetnessModulator = 1.0;
	wetnessModulator *= saturate(worldNormal.y * 10.5 + 0.7);
	wetnessModulator *= saturate(abs(2.0 - materialID));
	wetnessModulator *= clamp(blockLight.y * 1.05 - 0.7, 0.0, 0.3) / 0.3;
	wetnessModulator *= saturate(wetness * 1.1 - 0.1);

	float smoothness = 0.0;
	#ifdef FORCE_WET_EFFECT
	smoothness = mix(smoothness, 1.0, saturate(wetnessModulator * max(1.0 - isEyeInWater, 0.0)));
	#endif

	albedo.rgb = pow(albedo.rgb, vec3(1.0 + wetnessModulator * 0.1));

	#ifdef WET_CAVE_EFFECT
	float caveDamp = 1.0;
	caveDamp *= pow((1.0 - blockLight.y), 2.0);
	caveDamp *= pow((1.0 - blockLight.x), 1.0);
	smoothness = mix(smoothness, 1.0, 0.9 * caveDamp);
	#endif

	gbuffer.albedo = albedo;
	gbuffer.normal = viewNormal;
	gbuffer.mcLightmap = blockLight;
	gbuffer.smoothness = smoothness;
	gbuffer.metalness = 0.0;
	gbuffer.materialID = materialID / 255.0;
	gbuffer.emissive = 0.0;
	gbuffer.geoNormal = viewNormal;
	gbuffer.parallaxOffset = 0.0;
	gbuffer.depth = 0.0;

	vec4 frag0, frag1, frag2;
	OutputGBufferDataSolid(gbuffer, frag0, frag1, frag2);

	gl_FragData[0] = frag0;
	gl_FragData[1] = frag1;
	gl_FragData[2] = frag2;
}

/* DRAWBUFFERS:012 */
