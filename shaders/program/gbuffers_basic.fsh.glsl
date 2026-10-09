in vec4 color;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/GBufferData.inc"
#include "/lib/Materials.inc"


void main()
{
	if (PixelOutOfScreenBounds(gl_FragCoord.st)) {
		discard;
	}
	vec4 albedo = color;

	GBufferData gbuffer;
	gbuffer.albedo = albedo;
	gbuffer.normal = vec3(0.0, 0.0, 1.0);
	gbuffer.mcLightmap = vec2(0.0);
	gbuffer.smoothness = 0.0;
	gbuffer.metalness = 0.0;
	gbuffer.materialID = (MAT_ID_DYNAMIC_ENTITY + 0.1) / 255.0;
	gbuffer.emissive = 0.0;
	gbuffer.geoNormal = vec3(0.0, 0.0, 1.0);
	gbuffer.parallaxOffset = 0.0;
	gbuffer.depth = 0.0;


	vec4 data0, data1, data2;

	#if MC_VERSION >= 260100
		OutputGBufferDataParticle(gbuffer, data0, data1, data2);
	#else
		OutputGBufferDataSolid(gbuffer, data0, data1, data2);
	#endif

	gl_FragData[0] = data0;
	gl_FragData[1] = data1;
	gl_FragData[2] = data2;

}

/* DRAWBUFFERS:012 */
