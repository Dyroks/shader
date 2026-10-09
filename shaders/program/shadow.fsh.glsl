#extension GL_ARB_shading_language_packing : enable
#extension GL_ARB_shader_bit_encoding : enable

// #define DH_SHADOW_FIX

layout(location = 0) out vec4 shadowColor0;
layout(location = 1) out vec4 shadowColor1;

in vec4 texcoord;
in vec4 color;
in vec3 worldPos;
in vec2 midTexCoord;
in float textureResolution;
in float materialIDs;
in float mcEntity;
in float isVoxelOutput;

uniform float alphaTestRef;

#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"


 void main()
 {
   vec4 v=texture2D(texture,texcoord.xy,0);
   vec3 f=v.xyz*color.xyz;
   if(isVoxelOutput<.5)
     {
       #ifdef DH_SHADOW_FIX
       #endif
       if (any(greaterThan(abs(gl_FragCoord.st - midTexCoord), vec2(1024.0)))) {
         discard;
       }
       #if MC_VERSION >= 11700
       if (v.w < alphaTestRef) {
         discard;
       }
       #endif
       float x=min(v.w*7.,1.);
       f.xyz=normalize(f.xyz+1e-4)*pow(dot(f.xyz,f.xyz),.25);
       f.xyz=mix(vec3(1.),f.xyz,vec3(pow(v.w,.2)));
       shadowColor0=vec4(f.xyz,x);
       shadowColor1=vec4(.75-worldPos.y/512.-0.9/255.,0.,0.,x);
     }
   else
     {
       ivec2 blockAtlasSize = textureSize(gaux1, 0);
       float atlasSizeDiff = abs(blockAtlasSize.x - atlasSize.x) + abs(blockAtlasSize.y - atlasSize.y);
       if (atlasSizeDiff > 0.1) discard;
       float tileSize=TEXTURE_RESOLUTION;
       #if TEXTURE_RESOLUTION == 0
       tileSize=exp2(round(log2(textureResolution)));
       #endif
       vec2 atlasTiles=atlasSize/tileSize;
       vec2 midCoord=(floor(midTexCoord*atlasTiles)+vec2(0.5))/atlasTiles;
       if(v.w<0.001)
         {
           f=texture2D(texture,midTexCoord.xy,0).xyz*color.rgb;
         }
       f.xyz*=sqrt(3.0)/length(color.xyz);
       f=pow(f,vec3(2.2));
       if(abs(mcEntity-50.)<.1)
         {
           f.xyz=KelvinToRGB(float(TORCHLIGHT_COLOR_TEMPERATURE))*.5;
         }
       else if(abs(mcEntity-51.)<.1)
         f.xyz=vec3(1.,.35,.025);
       else if(abs(mcEntity-52.5)<1.)
       {
         float intensity=mcEntity-52.;
         f.xyz=vec3(.1,.9,1.)*(.2+intensity*.8);
       }
       else if(abs(mcEntity-74.)<.1)
         f.xyz=vec3(1.,.02,.01)*.3;
       else if(abs(mcEntity-76.)<.1)
         f.xyz=vec3(1.,.02,.01)*.2;
       else if(abs(mcEntity-92.)<.1)
         f.xyz=vec3(.4,0.,1.);
       else if(abs(mcEntity-93.)<.1)
         f.xyz=vec3(.5,.9,.5)*.5;
       else if(abs(mcEntity-117.)<.1)
         f.xyz=vec3(1.,.3,.0)*.1;
       else if(abs(mcEntity-138.)<.1)
         f.xyz=vec3(.4,1.,1.)*.3;
       else if(abs(mcEntity-148.5)<2.)
         {
           float intensity=(mcEntity-146.);
           f.xyz=vec3(.5,.3,.7)*.2*intensity;
         }
       else if(abs(mcEntity-182.5)<2.)
         {
           float intensity=(mcEntity-181.)/10.;
           f.xyz=vec3(.4+intensity,intensity,1.)*.3*pow(2.,intensity*10.);
         }
       else if(abs(mcEntity-186.5)<2.)
         {
           float intensity=(mcEntity-184.5)/3.;
           f.xyz=KelvinToRGB(float(TORCHLIGHT_COLOR_TEMPERATURE))*intensity*.4;
         }
       else if(abs(mcEntity-190.5)<2.)
         {
           float intensity=mcEntity-188.5;
           f.xyz=vec3(.8,1.,.8)*.14*intensity;
         }
       else if(abs(mcEntity-197.)<.1)
         f.xyz=vec3(.007,.0044,.0012);
       else if(abs(mcEntity-198.)<.1)
         f.xyz=vec3(1.,1.,1.)*.2;
       else if(abs(mcEntity-199.)<.1)
         f.xyz=vec3(0.3, 0.09, 0.003)*.5;
       else if(abs(mcEntity-213.)<.1)
         f.xyz=vec3(1.,.2,.0)*.2;
       float y=step(1e-3,abs(color.x-color.y)+abs(color.x-color.z)+abs(color.y-color.z));
       f.xyz=normalize(f.xyz+1e-05)*min(length(f.xyz),.95);
       shadowColor0=vec4(f.xyz,(materialIDs+.1)/255.);
       shadowColor1=vec4(midCoord.xy,y,log2(textureResolution)/255.);
     }
 }



