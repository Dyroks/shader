out vec4 color;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/TAA.inc"


void main()
{
	gl_Position = ftransform();

	FinalVertexTransformTAA(gl_Position);

	color = gl_Color;

	gl_FogFragCoord = gl_Position.z;
}
