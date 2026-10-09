out vec4 texcoord;

out mat4 gbufferPreviousModelViewInverse;
out mat4 gbufferPreviousProjectionInverse;


#include "/lib/Uniforms.inc"


void main()
{
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;

	// Inverse previous matrices for reprojection
	gbufferPreviousModelViewInverse = inverse(gbufferPreviousModelView);
	gbufferPreviousProjectionInverse = inverse(gbufferPreviousProjection);
}
