#version 330 compatibility






out vec4 texcoord;

flat out vec3 lightVector;
flat out vec3 colorSkyUp;
flat out vec3 colorTorchlight;

flat out vec4 skySHR;
flat out vec4 skySHG;
flat out vec4 skySHB;



#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"



void main()
{
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
	CropQuadForDownscale(gl_Position, texcoord);

	// Write to upper right quadrant
	// Weirdly, it has to be done this way to avoid texel misalignments
	gl_Position.xy += HalfScreen * 2.0;
	// gl_Position.xy += HalfScreen * 2.0;


	// Get light and sun vectors
	lightVector = normalize((gbufferModelView * vec4(worldLightVector.xyz, 0.0)).xyz);

	// Get diffuse light colors and data
	GetSkylightData(worldSunVector, worldLightVector, colorSunlight, timeMidnight,
		skySHR, skySHG, skySHB, colorSkyUp);
	colorTorchlight = GetColorTorchlight();

}
