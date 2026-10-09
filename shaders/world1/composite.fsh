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


in vec4 texcoord;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/Materials.inc"
#include "/lib/GBufferData.inc"


const int shadowMapResolution = 8192; // Higher value impacts performance costs, but can get better shadow, and increase path tracing distance. Please increase the shadow distance at the same time. 4096 - 80 blocks path tracing. 8192 - 160 blocks path tracing. 16384 - 300 blocks path tracing, requires at least 6GB VRAM. 34768 - 530 blocks of path tracing, requires at least 20GB VRAM. [4096 8192 16384 32768]
const float SHADOW_MAP_RESOLUTION = shadowMapResolution * MC_SHADOW_QUALITY;
const float RAY_TRACING_RESOLUTION = SHADOW_MAP_RESOLUTION - 2048.0;
const float RAY_TRACING_DIAMETER_TEMP = floor(pow(RAY_TRACING_RESOLUTION, 2.0 / 3.0));
const float RAY_TRACING_DIAMETER = RAY_TRACING_DIAMETER_TEMP - mod(RAY_TRACING_DIAMETER_TEMP - 1.0, 2.0);
const float RAY_TRACING_RADIUS = RAY_TRACING_DIAMETER / 2.0;


vec2 Texcoord;


 vec2 s(vec3 v)
 {
   ivec2 m=ivec2(viewWidth,viewHeight);
   vec3 i=floor(v.xzy+1e-05);
   i.x+=i.z*altRTDiameter;
   vec2 r;
   r.x=mod(i.x,m.x);
   r.y=i.y+floor(i.x/m.x)*altRTDiameter;
   r+=.5;
   r/=m;
   return r;
 }
 vec2 d(vec3 v)
 {
   v=clamp(v,vec3(0.),vec3(RAY_TRACING_DIAMETER));
   v.x+=v.y*RAY_TRACING_DIAMETER;
   v.y=v.z+floor(v.x/RAY_TRACING_RESOLUTION)*RAY_TRACING_DIAMETER;
   v.x=mod(v.x,RAY_TRACING_RESOLUTION);
   return v.xy;
 }
 struct rXuEJcsNQI{vec3 QbpObHBdUl;vec3 ZRrfSsHfvT;vec3 fgCeZiNBHZ;vec3 ZKdJsVHIyK;vec3 frnQIYJjVJ;};
 rXuEJcsNQI r(Ray v)
 {
   rXuEJcsNQI i;
   i.QbpObHBdUl=floor(v.origin);
   i.ZRrfSsHfvT=abs(vec3(length(v.direction))/(v.direction+1e-07));
   i.fgCeZiNBHZ=sign(v.direction);
   i.ZKdJsVHIyK=(i.fgCeZiNBHZ*(i.QbpObHBdUl-v.origin)+i.fgCeZiNBHZ*.5+.5)*i.ZRrfSsHfvT;
   i.frnQIYJjVJ=vec3(0.);
   return i;
 }
 void i(inout rXuEJcsNQI v)
 {
   v.frnQIYJjVJ=step(v.ZKdJsVHIyK.xyz,vec3(min(v.ZKdJsVHIyK.x,min(v.ZKdJsVHIyK.y,v.ZKdJsVHIyK.z))));
   v.ZKdJsVHIyK+=v.frnQIYJjVJ*v.ZRrfSsHfvT,v.QbpObHBdUl+=v.frnQIYJjVJ*v.fgCeZiNBHZ;
 }
 vec3 p(vec2 v)
 {
   v=(floor(v*ScreenSize)+.5)*ScreenTexel;
   vec4 texLod=texture2DLod(colortex5,v,0);
   vec2 unpackedY=UnpackTwo16BitFrom32Bit(texLod.y);
   vec2 unpackedZ=UnpackTwo16BitFrom32Bit(texLod.z);
   vec2 unpackedW=UnpackTwo16BitFrom32Bit(texLod.w);
   return pow(vec3(unpackedY.x,unpackedZ.x,unpackedW.x),vec3(8.0));
 }
 float e(float v,float y)
 {
   float z=1.;
   #ifdef FULL_RT_REFLECTIONS
   z=clamp(pow(v,.125)+y,0.,1.);
   #else
   z=clamp(v*10.-7.,0.,1.);
   #endif
   return z;
 }


#if SHAPE_CALC_FUNC == 0
#include "/program/template/BlockShapes_CompileTime.glsl"
#else
#include "/program/template/BlockShapes_Performance.glsl"
#endif


 vec3 c(vec2 v)
 {
   vec2 y=vec2(v.xy*ScreenSize)/64.;
   const vec2 m[16]=vec2[16](vec2(-1,-1),vec2(0,-.333333),vec2(-.5,.333333),vec2(.5,-.777778),vec2(-.75,-.111111),vec2(.25,.555556),vec2(-.25,-.555556),vec2(.75,.111111),vec2(-.875,.777778),vec2(.125,-.925926),vec2(-.375,-.259259),vec2(.625,.407407),vec2(-.625,-.703704),vec2(.375,-.037037),vec2(-.125,.62963),vec2(.875,-.481482));
   y+=m[frameCounter%16]*.5;
   y=(floor(y*64.)+.5)/64.;
   vec3 c=texture2D(noisetex,y).xyz;
   return c;
 }
 vec3 H(vec3 v,vec3 y)
 {
   vec2 x=s(clamp(v-vec3(RAY_TRACING_DIAMETER/2.-1)+vec3(.5*altRTDiameter),vec3(0.),vec3(altRTDiameter)));
   return p(x);
 }
 vec3 H(float v,float f,float x,vec3 i)
 {
   vec3 r;
   r.x=x*cos(v);
   r.y=x*sin(v);
   r.z=f;
   vec3 c=abs(i.y)<.999?vec3(0,0,1):vec3(1,0,0),z=normalize(cross(i,vec3(0.,1.,1.))),w=cross(z,i);
   return z*r.x+w*r.y+i*r.z;
 }
 vec3 c(vec2 v,float y,vec3 x)
 {
   float s=2*3.14159*v.x,z=sqrt((1-v.y)/(1+(y*y-1)*v.y)),i=sqrt(max(0.,1-z*z));
   return H(s,z,i,x);
 }
 void G(inout vec3 v,in vec3 y,in vec3 i,vec3 z,float x)
 {
   float c=length(y);
   c*=pow(eyeBrightnessSmooth.y/240.,6.f)*rainStrength;
   float f=exp(-c*4e-05);
   f=max(f,.5);
   v=mix(vec3(0.),v,vec3(f));
 }
 vec4 G(float v,vec3 s,vec3 m,vec3 x,vec3 z,vec3 n,float h,float a,float T,bool w)
 {
   float l=1.;
   #ifdef SUNLIGHT_LEAK_FIX
   if(isEyeInWater<1)
     l=saturate(a*100.);
   #endif
   v=max(v-.05,0.);
   float R=v*v;
   vec3 cTexcoord=c(Texcoord.xy).xyz;
   vec3 g=reflect(n,c(cTexcoord.xy*vec2(1.,.8),R,x)),q=normalize((gbufferModelView*vec4(g.xyz,0.)).xyz);
   if(dot(g,x)<0.)
     g=reflect(g,x);
   #ifdef REFLECTION_SCREEN_SPACE_TRACING
   {
     bool b=false;
     vec2 F=Texcoord.xy;
     vec3 D=m.xyz;
     float S=0.;
     vec3 K=m.xyz;
     float P=.1/saturate(dot(-n,x)+.001),J=P*2.,X=1.,Y=0.;
     vec3 temp=q.xyz*P;
     float lengthK=length(K)*.1;
     for(int N=0;N<16;N++)
       {
         vec3 C=temp*(.15+lengthK)*X;
         float j=J*(lengthK);
         K+=C;
         if(K.z>0.)
           break;
         lengthK=length(K)*.1;
         vec2 M=ProjectBack(K).xy;
         TemporalJitterProjPos(M);
         float depth=GetDepth(M.xy*.5);
         vec3 u;
         #ifdef LOD
         if(depth==1.0){
           depth=getLodDepthSolid(M.xy*0.5);
           u=GetViewPositionNoJitterLod(M.xy,depth).xyz;
         }else
         #endif
         {
           u=GetViewPositionNoJitter(M.xy,depth).xyz;
         }
         float I=lengthK*10.-length(u)-.02;
         if(abs(2.*I-j)<j&&abs(M.x-.5)<.5&&abs(M.y-.5)<.5)
           {
             K-=C;
             X*=.5;
             Y+=1.;
             if(Y>2.)
               {
                 b=true;
                 F=M.xy;
                 D=u.xyz;
                 S=distance(K,m.xyz)*.4;
                 break;
               }
           }
       }
     float maxDepth=far;
     #ifdef LOD
     maxDepth=lodRenderDistance();
     #endif
     if(length(D)>maxDepth)
       b=false;
     if(b)
       {
         F.xy=floor(F.xy*ScreenSize+.5)*ScreenTexel;
         TemporalJitterProjPos01(F);
         vec2 M=F.xy*.5;
         M=clamp(M,ScreenTexel,HalfScreen)+HalfScreen;
         vec3 E=pow(texture2DLod(colortex1,M,0).xyz,vec3(2.2))*100.;
         G(E,D,normalize(m.xyz),normalize(s.xyz),1.);
         if(isEyeInWater==0)
           E*=1.2,TheEndFog(E,length(D),n),E/=1.2;
         if(isEyeInWater==1)
           E*=1.2,UnderwaterFog(E,length(D),n,vec3(0.),colorSunlight),E/=1.2;
         if(isEyeInWater==2)
           E*=1.2,UnderLavaFog(E,length(D),n),E/=1.2;
         return vec4(E,saturate(S/4.));
       }
   }
   #endif
   vec3 M=s+x*(.004+h*.1);
   if(!w)
     M-=n*(T*.3/(saturate(dot(z,-n))+1e-06)+.01);
   M+=FractedCameraPosition;
   vec3 rayPos=clamp(M+vec3(RAY_TRACING_DIAMETER/2.-1.),vec3(-1.),vec3(RAY_TRACING_DIAMETER-1.));
   Ray F=MakeRay(rayPos,g);
   vec3 k=vec3(1.),N=vec3(0.);
   float S=0.;
   rXuEJcsNQI P=r(F);
   float J=far;
   vec3 u=vec3(1.),fOrigin=.5-F.origin;
   vec3 stainedColor=vec3(1.);
   vec2 atlasTexSize=vec2(textureSize(colortex0,0));
   for(int Q=0;Q<1;Q++)
     {
       vec4 Y=vec4(1.);
       float emissive=0.;
       vec2 shadowCoord=vec2(0.);
       float prevID=255.;
       vec3 rayHitPos=vec3(0.);
       for(int j=0;j<REFLECTION_TRACE_LENGTH;j++)
         {
           shadowCoord=d(P.QbpObHBdUl);
           Y=texelFetch(shadowcolor,ivec2(shadowCoord),0);
           S=Y.w*255.;
           if(S<255.)
             {
               if(S==241.)
                 {
                   vec3 temp=P.QbpObHBdUl+fOrigin;
                   float A=saturate(pow(saturate(dot(F.direction,normalize(temp))),56.*dot(temp,temp))*5.-1.)*5.;
                   N+=Y.xyz*A*stainedColor;
                   i(P);
                   prevID=241.;
                   continue;
                 }
               if((prevID==S&&(S==37.||S==39.))||!c(P.QbpObHBdUl,S,F,J,u))
                 {
                   i(P);
                   continue;
                 }
               rayHitPos=fract(F.origin+F.direction*J)-.5;
               vec2 O=vec2(0.);
               O+=vec2(rayHitPos.z*-u.x,-rayHitPos.y)*abs(u.x);
               O+=vec2(rayHitPos.x,rayHitPos.z*u.y)*abs(u.y);
               O+=vec2(rayHitPos.x*u.z,-rayHitPos.y)*abs(u.z);
               vec4 A=texelFetch(shadowcolor1,ivec2(shadowCoord),0);
               float textureResolusion=TEXTURE_RESOLUTION;
               #if TEXTURE_RESOLUTION == 0
               textureResolusion=exp2(A.w*255.);
               #endif
               vec2 V=atlasTexSize/textureResolusion;
               vec2 ab=(floor(A.xy*V)+.5+O.xy)/V;
               vec4 ac=texture2DLod(colortex0,ab,0);
               ac.xyz=pow(ac.xyz,vec3(2.2));
               if(ac.w<.99&&abs(S-61.5)<31.)
                 {
                   if(S==37.)
                     {
                       ac.xyz=normalize(ac.xyz+1e-4)*pow(dot(ac.xyz,ac.xyz),.25);
                       ac.xyz=mix(vec3(1.),ac.xyz,vec3(pow(ac.w,.2)));
                       ac.xyz*=ac.xyz;
                       stainedColor*=ac.xyz;
                     }
                   J=far;
                   prevID=S;
                   i(P);
                   continue;
                 }
               ac.xyz*=mix(vec3(1.),Y.xyz,vec3(A.z));
               k=ac.xyz*stainedColor;
               #ifdef MC_SPECULAR_MAP
                 emissive=texture2DLod(depthtex2,ab,0)[SPEC_CHANNEL_EMISSIVE];
                 #if SPEC_CHANNEL_EMISSIVE==3
                 emissive-=step(1.0,emissive);
                 #endif
               #endif
               break;
             }
           i(P);
         }
       #ifdef SPEC_EMISSIVE
       if(emissive>0.)
         {
           N+=.1*k*GI_LIGHT_BLOCK_INTENSITY*emissive;
         }
       else
       #endif
         {
           if(S==31.)
             N+=.1*k*GI_LIGHT_BLOCK_INTENSITY;
           if(S==36.)
             {
               float d=saturate(k.x-(k.y+k.z)/2.-.3);
               N+=.1*k*GI_LIGHT_BLOCK_INTENSITY*vec3(2.,.35,.025)*step(1e-5,d);
             }
         }
       N+=(nightVision*0.005+0.0002)*k;
       vec3 ae=vec3(1.0-abs(u.x),abs(u.x),0.),af=vec3(0.,abs(u.z),1.0-abs(u.z)),offset=rayHitPos*(ae+af);
       vec3 irradiance=vec3(0.);
       float weight=0.;
       vec3 sampleOrigin=floor(F.origin+F.direction*J+u*0.01);
       for(int j=-1;j<2;j++)
         {
           for(int o=-1;o<2;o++)
             {
               vec3 sampleOffset=j*ae+o*af;
               vec3 sampleIrradiance=H(sampleOrigin+sampleOffset,u);
               float sampleWeight=max(1.5-length(-offset+sampleOffset),0.0)/1.5*step(1e-7,dot(sampleIrradiance,vec3(1.0)));
               irradiance+=sampleIrradiance*sampleWeight;
               weight+=sampleWeight;
             }
         }
       irradiance/=max(weight,1e-05);
       N+=irradiance*2.4*k;
       N+=k*nightVision*0.0047;
     }
   vec3 j=m.xyz+q*J,L=(gbufferModelViewInverse*vec4(j.xyz,0.)).xyz;
   #ifdef SCREEN_SPACE_CONNECTION_REFLECTION
   {
     vec3 Y=ProjectBack(j);
     if(abs(Y.x-.5)<.5-ScreenTexel.x&&abs(Y.y-.5)<.5-ScreenTexel.y&&j.z<0.)
       {
         TemporalJitterProjPos(Y.xy);
         vec2 DTY=Y.xy*.5;
         float d=GetDepth(DTY);
         vec3 Q=GetViewPositionNoJitter(Y.xy,d).xyz;
         d=step(.999999,d);
         #ifdef LOD
         d*=step(.999999,getLodDepthSolid(DTY));
         #endif
         vec3 posNormal=DecodeNormal(texture2DLod(colortex2,DTY,0).xy);
         float NdotV=saturate(dot(normalize(-L),posNormal));
         float weight=.005*pow(length(Q)+.5,1.3)/((NdotV+.1)*(length(Q-j)+1e-8));
         vec3 sampleGeoNormal=mat3(gbufferModelViewInverse)*GetGeoNormals(DTY);
         weight*=max(dot(u,sampleGeoNormal),0.0);
         weight=mix(weight,2.,step(2000.,J)*d);
         if(weight>1.)
           {
             vec2 I=Y.xy*2.-1.;
             float V=smoothstep(.5,1.,max(abs(I.x),abs(I.y)));
             vec3 colorTemp=mix(pow(texture2DLod(colortex1,DTY+HalfScreen.xy,0).xyz,vec3(2.2))*stainedColor*100.,N.xyz,vec3(V));
             N=mix(N.xyz,colorTemp,saturate(weight-1.));
           }
       }
   }
   #endif
   if(isEyeInWater==0)
     N*=1.2,TheEndFog(N,length(L),n),N/=1.2;
   if(isEyeInWater==1)
     N*=1.2,UnderwaterFog(N,length(L),n,vec3(0.),colorSunlight),N/=1.2;
   if(isEyeInWater==2)
     N*=1.2,UnderLavaFog(N,length(L),n),N/=1.2;
   J*=saturate(dot(-n,x))*2.;
   return vec4(N,saturate(J/4.));
 }
 void main()
 {
   Texcoord=texcoord.xy;
   if(texcoord.x<HalfScreen.x||texcoord.y<HalfScreen.y)
     gl_FragData[0]=texture2DLod(colortex7,Texcoord.xy,0);
   else
     {
       Texcoord=texcoord.xy-HalfScreen;
       GBufferData v=GetGBufferData(Texcoord.xy);
       GBufferDataTransparent y=GetGBufferDataTransparent(Texcoord.xy);
       MaterialMask i=CalculateMasks(v.materialID,Texcoord.xy),s=CalculateMasks(y.materialID,Texcoord.xy);
       bool x=y.depth<v.depth;
       float lodWaterDepth=1.0;
       #ifdef LOD
         float lodSolidDepth=getLodDepthSolid(Texcoord.xy);
         lodWaterDepth=getLodDepthWater(Texcoord.xy);
         x=x||(lodWaterDepth<lodSolidDepth&&y.depth==1.0);
       #endif
       if(x)
         v.depth=y.depth,v.normal=y.normal,v.smoothness=y.smoothness,v.metalness=0.,v.mcLightmap=y.mcLightmap,s.sky=0.;
       vec4 f;
       #ifdef LOD
         if (y.depth==1.0&&lodWaterDepth<1.0) {
           f=GetViewPositionLod(Texcoord.xy,lodWaterDepth);
         }else
       #endif
       {
         f=GetViewPosition(Texcoord.xy,v.depth);
       }
       vec4 m=gbufferModelViewInverse*vec4(f.xyz,1.),d=gbufferModelViewInverse*vec4(f.xyz,0.);
       vec3 r=normalize(d.xyz),n=normalize((gbufferModelViewInverse*vec4(v.normal,0.)).xyz),h=normalize((gbufferModelViewInverse*vec4(v.geoNormal,0.)).xyz);
       vec4 T=vec4(0.);
       float t=e(v.smoothness,v.metalness);
       if(t>.0001&&s.sky<.5)
         T=G(1.-v.smoothness,m.xyz,f.xyz,n.xyz,h,r.xyz,i.leaves,v.mcLightmap.y,v.parallaxOffset,x);
       gl_FragData[0]=max(vec4(0.),T*vec4(vec3(.1),1.));
     }
 }




/* DRAWBUFFERS:7 */
