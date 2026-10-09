#include "/lib/Uniforms.inc"


in vec4 texcoord;


 void main()
 {
   vec4 s=texture2DLod(colortex7,texcoord.xy+HalfScreen,0);
   gl_FragData[0]=vec4(s);
 }




/* DRAWBUFFERS:7 */
