out vec4 color;
out vec4 texcoord;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/TAA.inc"


void main()
{
	gl_Position = ftransform();

	FinalVertexTransformTAA(gl_Position);

	color = gl_Color;

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

	gl_FogFragCoord = gl_Position.z;
}
