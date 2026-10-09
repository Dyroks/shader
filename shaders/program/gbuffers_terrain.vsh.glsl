#if MC_VERSION >= 11500
layout(location = 11) in vec4 mc_Entity;
#else
layout(location = 10) in vec4 mc_Entity;
#endif


out vec4 Vcolor;
out vec4 Vtexcoord;
out vec4 VviewPos;
out vec3 VworldPosition;
out vec3 VworldNormal;
out vec2 VblockLight;
flat out float VmaterialIDs;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/TAA.inc"
#include "/lib/Materials.inc"


 void main()
 {
   Vcolor=gl_Color;
   Vtexcoord=gl_MultiTexCoord0;
   vec4 lmcoord=gl_TextureMatrix[1]*gl_MultiTexCoord1;
   VblockLight=clamp(lmcoord.st*33.05f/32.f-.0328125f,0.f,1.f);
   VworldNormal=gl_Normal;
   VviewPos=gl_ModelViewMatrix*gl_Vertex;
   vec4 x=gbufferModelViewInverse*VviewPos;
   VworldPosition=x.xyz+cameraPosition.xyz;
   VmaterialIDs=1.;
   float s=abs(normalize(gl_Normal.xz).x),l=abs(gl_Normal.y);
   if((mc_Entity.x==31.||abs(mc_Entity.x-37.5)<1.0f||mc_Entity.x==2.&&gl_Normal.y<.5&&abs(s-.5)<.49&&l<.9)||any(lessThan(abs(abs(gl_Normal)-.5),vec3(.49))))
     VmaterialIDs=MAT_ID_GRASS;
   if(mc_Entity.x==59.||mc_Entity.x==175.f)
     VmaterialIDs=MAT_ID_GRASS;
   if(mc_Entity.x==18.||mc_Entity.x==161.f&&(Vcolor.x<.999||Vcolor.y<.999||Vcolor.z<.999))
     VmaterialIDs=MAT_ID_LEAVES;
   if(mc_Entity.x==50||mc_Entity.x==52||abs(mc_Entity.x-92.5)<1.||mc_Entity.x==124||abs(mc_Entity.x-182.5)<2||abs(mc_Entity.x-190.5)<2||mc_Entity.x==198||mc_Entity.x==213)
     VmaterialIDs=MAT_ID_TORCH;
   if(mc_Entity.x==197)
     VmaterialIDs=MAT_ID_GLOW_LICHEN;
   if(mc_Entity.x==199)
     VmaterialIDs=MAT_ID_GLOW_BERRIES;
   if(mc_Entity.x==10||mc_Entity.x==11)
     VmaterialIDs=MAT_ID_LAVA;
   if(mc_Entity.x==89||mc_Entity.x==91||abs(mc_Entity.x-148.5)<2.||mc_Entity.x==169)
     VmaterialIDs=MAT_ID_GLOWSTONE;
   if(mc_Entity.x==138)
     VmaterialIDs=MAT_ID_BEACON;
   #ifdef GLOWING_REDSTONE_BLOCK
   if(mc_Entity.x==152)
     VmaterialIDs=MAT_ID_GLOWSTONE;
   #endif
   #ifdef GLOWING_LAPIS_LAZULI_BLOCK
   if(mc_Entity.x==22)
     VmaterialIDs=MAT_ID_GLOWSTONE;
   #endif
   #ifdef GLOWING_EMERALD_BLOCK
   if(mc_Entity.x==133)
     VmaterialIDs=MAT_ID_GLOWSTONE;
   #endif
   if(mc_Entity.x==79||mc_Entity.x==95||mc_Entity.x==165)
     VmaterialIDs=MAT_ID_STAINED_GLASS;
   if(mc_Entity.x==51||mc_Entity.x==53)
     VmaterialIDs=MAT_ID_FIRE;
   if(mc_Entity.x==74||mc_Entity.x==76||mc_Entity.x==117||abs(mc_Entity.x-194.5)<2)
     VmaterialIDs=MAT_ID_LIT_FURNACE;
   gl_Position=gl_ProjectionMatrix*VviewPos;
   FinalVertexTransformTAA(gl_Position);
 }



