#include "/lib/Uniforms.inc"


out vec4 texcoord;
out mat4 gbufferPreviousModelViewInverse;


void main()
{
	gl_Position = ftransform();

	texcoord = gl_MultiTexCoord0;

	gbufferPreviousModelViewInverse = inverse(gbufferPreviousModelView);
}
