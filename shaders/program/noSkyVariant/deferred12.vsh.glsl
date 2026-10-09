out vec4 texcoord;
flat out vec3 colorTorchlight;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"


void main()
{
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
	CropQuadForDownscale(gl_Position, texcoord);
	gl_Position.xy += HalfScreen * 2.0;

	colorTorchlight = GetColorTorchlight();
}
