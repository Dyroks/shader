#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/TAA.inc"


out vec4 texcoord;


void main()
{
	gl_Position = ftransform();

	texcoord = gl_MultiTexCoord0;

	CropQuadForDownscale(gl_Position, texcoord);

	gl_Position.y += HalfScreen.y * 2.0;
}
