out vec4 texcoord;


#include "/lib/Uniforms.inc"


void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
}
