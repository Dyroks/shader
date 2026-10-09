#version 330 compatibility


/*
 _______ _________ _______  _______  _
(  ____ \\__   __/(  ___  )(  ____ )( )
| (    \/   ) (   | (   ) || (    )|| |
| (_____    | |   | |   | || (____)|| |
(_____  )   | |   | |   | ||  _____)| |
      ) |   | |   | |   | || (      (_)
/\____) |   | |   | (___) || )       _
\_______)   )_(   (_______)|/       (_)

Do not modify this code until you have read the LICENSE.txt contained in the root directory of this shaderpack!

*/


out vec4 texcoord;
flat out vec3 colorSkyUp;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"

#ifdef VOLUMETRIC_CLOUDS
flat out vec3 cloudSkyAmbient;
#endif


void main()
{
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
	CropQuadForDownscale(gl_Position, texcoord);
	gl_Position.xy += HalfScreen * 2.0;

	// Get diffuse light colors and data
	colorSkyUp = SkyShading(vec3(0.0, 1.0, 0.0), worldSunVector);

	#ifdef VOLUMETRIC_CLOUDS
	// Average sky radiance over the upper hemisphere, lights the clouds
	cloudSkyAmbient = colorSkyUp;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		cloudSkyAmbient += SkyShading(normalize(vec3(cos(a), 0.25, sin(a))), worldSunVector);
		cloudSkyAmbient += SkyShading(normalize(vec3(cos(a + 0.39), 1.0, sin(a + 0.39))), worldSunVector);
	}
	cloudSkyAmbient /= 17.0;
	#endif
}
