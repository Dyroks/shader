#extension GL_ARB_gpu_shader5 : enable


#include "/lib/Uniforms.inc"


const bool colortex2MipmapEnabled = true;


in vec4 texcoord;


void main() {

	gl_FragData[0] = texture2D(colortex2, texcoord.xy * 16.0);
}


/* DRAWBUFFERS:2 */
