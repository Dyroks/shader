#include "/program/template/PathTraceDenoiser.glsl"


 void main()
 {
   vec4 x=G(colortex7,texcoord.xy,true,4.,4.,vec2(1.,0.));
   gl_FragData[0]=x;
 }

/* DRAWBUFFERS:7 */
