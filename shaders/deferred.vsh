#version 330 compatibility


out vec4 texcoord;
flat out vec3 colorSkyUp;


#include "/lib/Settings.inc"
#ifdef AB_GI_VOLUME
flat out vec3 colorTorchlight;
flat out vec4 skySHR;
flat out vec4 skySHG;
flat out vec4 skySHB;
#endif
#include "/lib/Uniforms.inc"
#if defined AB_GI_VOLUME && defined VOLUMETRIC_CLOUDS && defined CLOUD_SKY_LIGHTING
#define CLOUD_SH_FROM_CAPTURE
#include "/lib/clouds/CloudLookups.inc"
#endif
#include "/lib/Common.inc"


void main()
{
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;

	// Get diffuse light colors and data
	#ifdef AB_GI_VOLUME
	// Same sky ambient as deferred12, which replaces the GI with it outside the voxel volume
	GetSkylightData(worldSunVector, worldLightVector, colorSunlight, timeMidnight,
		skySHR, skySHG, skySHB, colorSkyUp);
	colorTorchlight = GetColorTorchlight();
	#else
	colorSkyUp = SkyShading(vec3(0.0, 1.0, 0.0), worldSunVector);
	#endif
}
