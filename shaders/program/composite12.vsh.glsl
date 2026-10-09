out vec4 texcoord;


#include "/lib/Uniforms.inc"


void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;

	gl_Position.xy = gl_Position.xy * 0.5 + 0.5;
	texcoord.x *= HalfScreen.x;
	gl_Position.x *= HalfScreen.x;
	gl_Position.xy = gl_Position.xy * 2.0 - 1.0;

}
