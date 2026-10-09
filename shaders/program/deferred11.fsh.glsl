#include "/program/template/PathTraceDenoiser.glsl"


 void main()
 {
   vec4 y=G(colortex7,texcoord.xy,true,2.,2.,vec2(1.,-1.));
   gl_FragData[0]=y;
 }

/* DRAWBUFFERS:7 */
