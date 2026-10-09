#version 330 compatibility


/*
 _______ _________ _______  _______  _
(  ____ \\__   __/(  ___  )(  ____ )( )
| (    \/   ) (   | (   ) || (    )|| |
| (_____    | |   | |   | || (____)|| |
(_____  )   | |   | |   | ||  _____)| |
      ) |   | |   | |   | || (      (_)
/\____) |   | |   | (___) || )       _
\_______)   )_(   (_______)|/       (_)

Do not modify this code until you have read the LICENSE.txt contained in the root directory of this shaderpack!

*/

#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/Materials.inc"
#include "/lib/GBufferData.inc"


in vec4 texcoord;
flat in vec3 colorSkyUp;


 float e(float v,float y)
 {
   float x=1.;
   #ifdef FULL_RT_REFLECTIONS
   x=clamp(pow(v,.125)+y,0.,1.);
   #else
   x=clamp(v*10.-7.,0.,1.);
   #endif
   return x;
 }
 void main()
 {
   if (texcoord.x<HalfScreen.x||texcoord.y<HalfScreen.y)
     {
       gl_FragData[0]=texture2DLod(colortex1,texcoord.st,0);
       gl_FragData[1]=texture2DLod(colortex7,texcoord.st,0);
     }
   else
     {
       vec2 coord=texcoord.st-HalfScreen;
       GBufferData s=GetGBufferData(coord.xy);
       GBufferDataTransparent f=GetGBufferDataTransparent(coord.xy);
       MaterialMask y=CalculateMasks(f.materialID,coord.xy);
       bool c=f.depth<s.depth;
       float lodWaterDepth=1.0;
       float lodSolidDepth=1.0;
       #ifdef LOD
         lodSolidDepth=getLodDepthSolid(coord.xy);
         lodWaterDepth=getLodDepthWater(coord.xy);
         c=c||(lodWaterDepth<lodSolidDepth&&f.depth==1.0);
       #endif
       float solidDepth=s.depth;
       if(c)
         s.depth=f.depth,s.normal=f.normal,s.smoothness=f.smoothness,s.metalness=0.,s.mcLightmap=f.mcLightmap,s.depth=f.depth;
       bool isParticle=abs(111.-f.materialID*255.)<.4&&c;
       vec4 r;
       #ifdef LOD
         if (f.depth==1.0&&lodWaterDepth<1.0) {
           r=GetViewPositionLod(coord.xy,lodWaterDepth);
         }else
       #endif
       {
         r=GetViewPosition(coord.xy,s.depth);
       }
       vec4 g=gbufferModelViewInverse*vec4(r.xyz,0.);
       vec3 h=normalize(r.xyz),worldDir=normalize(g.xyz);
       float waterViewDepth=length(r.xyz);
       vec3 diffuseColor=texture2DLod(colortex1,texcoord.st,0).rgb;
       diffuseColor=pow(diffuseColor,vec3(2.2));
       vec3 solidViewPos;
       #ifdef LOD
         if(solidDepth==1.0&&lodSolidDepth<1.0) {
           solidViewPos=GetViewPositionLod(coord,lodSolidDepth).xyz;
         }else
       #endif
       {
         solidViewPos=GetViewPosition(coord,solidDepth).xyz;
       }
       float solidViewDepth=length(solidViewPos),viewDepthDiff=solidViewDepth-waterViewDepth;
       if(isParticle)
         {
           diffuseColor*=100.;
           if(isEyeInWater==1)
             UnderwaterFog(diffuseColor,viewDepthDiff,worldDir,colorSkyUp,colorSunlight);
           else if(isEyeInWater==2)
             UnderLavaFog(diffuseColor,viewDepthDiff,worldDir);
           diffuseColor*=.01;
           diffuseColor.xyz=mix(diffuseColor.xyz,sqrt(diffuseColor.xyz*length(f.albedo.xyz+.1))*f.albedo.xyz*.1,f.albedo.w);
         }
       else if(c)
         {
           vec3 refractionNormal=f.normal-f.geoNormal*1.05;
           float refractionStrength=saturate(viewDepthDiff*.5)*.5;
           vec2 refractionCoord=coord+refractionNormal.xy/(waterViewDepth+1.5)*refractionStrength;
           refractionCoord=clamp(refractionCoord,vec2(ScreenTexel),HalfScreen-ScreenTexel*2.);
           float refractionSolidDepth=texture2DLod(depthtex1,refractionCoord,0).x;
           float refractionWaterDepth=texture2DLod(depthtex0,refractionCoord,0).x;
           bool isWater=refractionWaterDepth<refractionSolidDepth;
           float lodWaterRefractionDepth=1.0;
           float lodSolidRefractionDepth=1.0;
           #ifdef LOD
             lodSolidRefractionDepth=getLodDepthSolid(refractionCoord);
             lodWaterRefractionDepth=getLodDepthWater(refractionCoord);
             isWater=isWater||(lodWaterRefractionDepth<lodSolidRefractionDepth);
           #endif
           if(isWater)
             {
               diffuseColor=texture2DLod(colortex1,refractionCoord+HalfScreen,0).rgb;
               diffuseColor=pow(diffuseColor,vec3(2.2));
               #ifdef LOD
                 if(refractionWaterDepth==1.0&&lodWaterRefractionDepth<1.0) {
                   r=GetViewPositionLod(refractionCoord, lodWaterRefractionDepth);
                 }else
               #endif
               {
                 r=GetViewPosition(refractionCoord,refractionWaterDepth);
               }
               #ifdef LOD
                 if(refractionSolidDepth==1.0&&lodSolidRefractionDepth<1.0) {
                   solidViewPos=GetViewPositionLod(refractionCoord,lodSolidRefractionDepth).xyz;
                 }else
               #endif
               {
                 solidViewPos=GetViewPosition(refractionCoord,refractionSolidDepth).xyz;
               }
               waterViewDepth=length(r.xyz);
               solidViewDepth=length(solidViewPos);
               viewDepthDiff=solidViewDepth-waterViewDepth;
             }
           if(y.water>.5!=(isEyeInWater==1))
             {
               diffuseColor.rgb*=100.;
               UnderwaterFog(diffuseColor,viewDepthDiff,worldDir,colorSkyUp,colorSunlight);
               diffuseColor.rgb*=.01;
             }
           else
             {
               vec3 L=normalize(f.albedo.xyz+.0001)*pow(dot(f.albedo.xyz,f.albedo.xyz),.25);
               vec3 glassColor=mix(vec3(1.),L,vec3(pow(f.albedo.w,.2)));
               diffuseColor.rgb*=100.;
               if(isEyeInWater==2)
                 UnderLavaFog(diffuseColor,viewDepthDiff,worldDir);
               diffuseColor*=.01*glassColor*glassColor;
             }
         }
       diffuseColor=pow(diffuseColor,vec3(1./2.2));

/*************************************************************** Reflection Filtering ***************************************************************/
       float p=GetDepthLinear(coord.xy),a=dot(-h,s.normal.xyz),l=1.-s.smoothness,w=l*l,b=e(s.smoothness,s.metalness);
       vec4 F=texture2DLod(colortex7,texcoord.st,0);
       if(b>.001)
         {
           const float x=30.;
           float T=x*.9;
           T*=min(w*20.,1.1);
           T*=mix(F.w,1.,.2);
           vec2 k=BlueNoiseTemporal(coord.xy).xy*.99-.495;
           vec4 U=vec4(0.);
           float E=0.;
           float J=F.w*.95+.05;
           const float cos17508=cos(1.5708),sin15708=sin(1.5708);
           vec2 D=normalize(cross(s.normal,h).xy),L=mat2(cos17508,-sin15708,sin15708,cos17508)*D;
           float M=saturate(a);
           D*=mix(.1075,.5,M);
           L*=mix(.7,.5,M);
           vec3 A=reflect(-h,s.normal);
           vec2 Temp=T*ScreenTexel;
           L*=Temp,D*=Temp;
           w=115./w;
           for(int W=-1;W<=1;W++)
             {
               vec2 offsetPart1=W*D+coord.st;
               for(int C=-1;C<=1;C++)
                 {
                   vec2 X=offsetPart1+C*L;
                   X=clamp(X,4.*ScreenTexel,1.-4.*ScreenTexel);
                   vec4 V=texture2DLod(colortex7,X+HalfScreen,0);
                   float Z=GetDepthLinear(X),j=pow(saturate(dot(A,reflect(-h,GetNormals(X)))),w),ab=exp(-(abs(Z-p)*1.1)),ac=j*ab;
                   U+=vec4(pow(dot(V.xyz,V.xyz),J*.5)*normalize(V.xyz+1e-10),V.w)*ac;
                   E+=ac;
                 }
             }
           if(E>.001)
             {
               U/=E+.0001;
               U.xyz=pow(dot(U.xyz,U.xyz),.5/J)*normalize(U.xyz+1e-06);
               F=max(U,vec4(0.));
             }
         }
       gl_FragData[0]=vec4(diffuseColor,1.0);
       gl_FragData[1]=F;
     }
 }




/* DRAWBUFFERS:17 */
