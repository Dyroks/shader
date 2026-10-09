in vec4 color;
in vec4 texcoord;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/GBufferData.inc"


void main()
{
	#ifdef WEATHER
	if (PixelOutOfScreenBounds(gl_FragCoord.st))
	#endif
	{
		discard;
	}

	vec4 albedo = texture2D(texture, texcoord.st, 0);
	albedo *= color;

	if(albedo.w < 0.01) {
		discard;
	}

	vec4 frag0, frag1, frag2;

	GBufferData gbuffer;

	gbuffer.albedo = albedo;
	gbuffer.normal = vec3(0.0);
	gbuffer.smoothness = 0.0;
	gbuffer.metalness = 0.0;
	gbuffer.emissive = 0.0;
	gbuffer.geoNormal = vec3(0.0);
	gbuffer.parallaxOffset = 0.0;
	gbuffer.depth = 0.0;

	#if MC_VERSION > 11500
	gbuffer.mcLightmap = vec2(1.0);
	gbuffer.materialID = 0.0;
	OutputGBufferDataParticle(gbuffer, frag0, frag1, frag2);
	#else
	gbuffer.albedo.xyz = vec3(0.0);
	gbuffer.mcLightmap = vec2(0.0);
	gbuffer.materialID = 0.0;
	OutputGBufferDataParticle(gbuffer, frag0, frag1, frag2);
	frag1.zw = vec2(0.0);
	#endif


	gl_FragData[0] = frag0;
	gl_FragData[1] = frag1;
	gl_FragData[2] = frag2;
}

/* DRAWBUFFERS:012 */