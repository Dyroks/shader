#include "/program/template/PathTraceDenoiser.glsl"


 void main()
 {
   vec4 x=G(colortex7,texcoord.xy,true,2.,2.,vec2(1.,1.));
   gl_FragData[0]=x;
 }

/* DRAWBUFFERS:7 */
