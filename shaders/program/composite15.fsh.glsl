#extension GL_ARB_gpu_shader5 : enable


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/FXAASimple.inc"


in vec4 texcoord;


void main() {

	vec4 col = vec4(0.0);

	#if FINAL_FXAA > 0
		col = vec4(DoFXAASimple(colortex0, texcoord.st, ScreenTexel).rgb, texture2DLod(colortex0, texcoord.st, 0).a);
	#else
		col = texture2DLod(colortex0, texcoord.st, 0);
	#endif

	gl_FragData[0] = col;
}

/* DRAWBUFFERS:0 */
