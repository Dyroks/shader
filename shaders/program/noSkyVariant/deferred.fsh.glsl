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


 vec2 s(vec3 v)
 {
   ivec2 m=ivec2(viewWidth,viewHeight);
   v=v+vec3(.5*altRTDiameter);
   v=clamp(v,vec3(0.),vec3(altRTDiameter));
   vec3 i=floor(v.xzy+1e-05);
   i.x+=i.z*altRTDiameter;
   vec2 n;
   n.x=mod(i.x,m.x);
   n.y=i.y+floor(i.x/m.x)*altRTDiameter;
   n+=.5;
   n/=m;
   return n;
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
 vec3 c(vec2 v)
 {
   v=(floor(v*ScreenSize)+.5)*ScreenTexel;
   vec4 texLod=texture2DLod(colortex5,v,0);
   vec2 unpackY=UnpackTwo16BitFrom32Bit(texLod.y);
   vec2 unpackZ=UnpackTwo16BitFrom32Bit(texLod.z);
   vec2 unpackW=UnpackTwo16BitFrom32Bit(texLod.w);
   return pow(vec3(unpackY.x,unpackZ.x,unpackW.x),vec3(8.));
 }


#if SHAPE_CALC_FUNC == 0
#include "/program/template/BlockShapes_CompileTime.glsl"
#else
#include "/program/template/BlockShapes_Performance.glsl"
#endif


 vec3 w(vec2 x)
 {
   vec2 v=vec2(x.xy*ScreenSize);
   v*=1./64.;
   v=(floor(v*64.)+.5)/64.;
   vec3 i=texture2D(noisetex,v).xyz,c=vec3(sqrt(.2),sqrt(2.),1.61803);
   i=fract(i+float(frameCounter%64)*c);
   return i;
 }
 vec2 Texcoord;
 vec3 M(vec2 v)
 {
   float x=2*3.14159*v.x,y=acos(1.-2.*v.y);
   return vec3(sin(x)*sin(y),cos(x)*sin(y),cos(y));
 }
 vec3 e(vec3 v,vec2 x)
 {
   vec3 f=M(x);
   return f*sign(dot(f,v));
 }
 vec3 h(vec3 v,vec3 y)
 {
   vec2 f=s(v-RAY_TRACING_DIAMETER/2.+1+y+cameraPosCenterDiff);
   return c(f);
 }
 vec4 c(vec3 v,vec3 m,vec3 x,vec3 s,vec3 z,MaterialMask n,float a,float g)
 {
   if(n.sky>.5)
   {
     return vec4(0.);
   }
   float o=1.;
   float J=1.;
   if(isEyeInWater<1)
     {
       #ifdef SUNLIGHT_LEAK_FIX
       o=saturate(a*100.);
       #endif
       #ifdef CAVE_GI_LEAK_FIX
       J=saturate(a*10.);
       #endif
     }
   float lightFix=o*J;
   vec3 R=w(Texcoord.xy).xyz;
   vec3 q=e(x,R.xy);
   #ifdef GI_SCREEN_SPACE_TRACING
   {
     bool b=false;
     float F=-m.z/256.;
     vec2 M=Texcoord.xy;
     vec3 H=normalize((gbufferModelView*vec4(q.xyz,0.)).xyz);
     float RzTemp=R.z+.5;
     for(int S=0;S<8;S++)
       {
         float k=(float(S)+RzTemp),X=F*k*k;
         vec3 Q=m.xyz+H*X,P=ProjectBack(Q),U=GetViewPositionNoJitter(P.xy,GetDepth(P.xy*.5)).xyz;
         float j=length(Q)-length(U)-.02;
         if(abs(j-0.5)<0.5)
           {
             b=true;
             M=P.xy;
             break;
           }
       }
     if(b)
       {
         vec3 C=pow(texture2DLod(colortex6,M.xy,0).xyz,vec3(2.2));
         return vec4(C*100.,1.);
       }
   }
   #endif
   vec3 D=v+x*(.0001*length(v))-z*(g*.4/(saturate(dot(s,-z))+1e-06)+.0008);
   D+=FractedCameraPosition;
   vec3 rayPos=clamp(D+vec3(RAY_TRACING_DIAMETER/2.-1.),vec3(-1.),vec3(RAY_TRACING_DIAMETER-1.));
   vec4 Y=vec4(0.);
   vec2 atlasTexSize=vec2(textureSize(colortex3,0));
   for(int t=0;t<GI_RAY_COUNT;t++)
     {
       vec3 K=q;
       float G=10000.;
       if(t>0)
         q=normalize(q+random3(q*frameTimeCounter));
       q=-faceforward(q,q,x);
       Ray P=MakeRay(rayPos,q);
       rXuEJcsNQI T=r(P);
       vec3 M=vec3(1.),y=vec3(0.0);
       float j=0.;
       vec4 U=vec4(0.);
       float emissive=0.;
       vec3 stainedColor=vec3(1.);
       vec2 shadowCoord=vec2(0.);
       float prevID=255.;
       for(int u=0;u<DIFFUSE_TRACE_LENGTH;u++)
         {
           shadowCoord=d(T.QbpObHBdUl);
           U=texelFetch(shadowcolor,ivec2(shadowCoord),0);
           j=U.w*255.;
           if(j<255.)
             {
               if(j==241.)
                 {
                   if(u==0)
                     U.xyz*=.5;
                   y+=U.xyz*stainedColor*.5*GI_LIGHT_TORCH_INTENSITY;
                   prevID=241.;
                   i(T);
                   continue;
                 }
               if((prevID==j&&(j==39.||j==37.))||!c(T.QbpObHBdUl,j,P,G,K))
                 {
                   i(T);
                   continue;
                 }
               if(abs(j-33.5)<2.)
                 break;
               vec3 rayPos=fract(P.origin+P.direction*G)-.5;
               vec2 coordOffset=vec2(0.);
               coordOffset+=vec2(rayPos.z*-K.x,-rayPos.y)*abs(K.x);
               coordOffset+=vec2(rayPos.x,rayPos.z*K.y)*abs(K.y);
               coordOffset+=vec2(rayPos.x*K.z,-rayPos.y)*abs(K.z);
               vec4 coordData=texelFetch(shadowcolor1,ivec2(shadowCoord),0);
               float textureResolusion=TEXTURE_RESOLUTION;
               #if TEXTURE_RESOLUTION == 0
               textureResolusion=exp2(coordData.w*255.);
               #endif
               vec2 terrainSize=atlasTexSize/textureResolusion;
               vec2 coord=(floor(coordData.xy*terrainSize)+.5+coordOffset.xy)/terrainSize;
               vec4 texColor=texture2DLod(colortex3,coord,0);
               texColor.xyz=pow(texColor.xyz,vec3(2.2));
               if(texColor.w<.99&&abs(j-61.5)<31.)
                 {
                   if(j==37.)
                     {
                       texColor.xyz=normalize(texColor.xyz+1e-4)*pow(dot(texColor.xyz,texColor.xyz),.25);
                       texColor.xyz=mix(vec3(1.),texColor.xyz,vec3(pow(texColor.w,.2)));
                       texColor.xyz*=texColor.xyz;
                       stainedColor*=texColor.xyz;
                     }
                   G=10000.;
                   prevID=j;
                   i(T);
                   continue;
                 }
               texColor.xyz*=mix(vec3(1.),U.xyz,vec3(coordData.z));
               M=texColor.xyz*stainedColor;
               #ifdef MC_SPECULAR_MAP
                 emissive=texture2DLod(depthtex0,coord,0)[SPEC_CHANNEL_EMISSIVE];
                 #if SPEC_CHANNEL_EMISSIVE==3
                 emissive-=step(1.0,emissive);
                 #endif
               #endif
               break;
             }
           i(T);
         }
       y*=0.25;
       #ifdef SPEC_EMISSIVE
       if(emissive>0.)
         {
           y+=.1*M*GI_LIGHT_BLOCK_INTENSITY*emissive;
         }
       else
       #endif
         {
           if(abs(j-31.)<.1)
             y+=.1*M*GI_LIGHT_BLOCK_INTENSITY;
           if(abs(j-36.)<.1)
             {
               float d=saturate(M.x-(M.y+M.z)/2.-.3);
               y+=.1*M*GI_LIGHT_BLOCK_INTENSITY*vec3(2.,.35,.025)*step(1e-5,d);
             }
           if(abs(j-33.5)<2.)
             {
               float L=max(-K.z,0.);
               if(abs(j-33.)<.1)
                 L=max(K.x,0.);
               if(abs(j-34.)<.1)
                 L=max(K.z,0.);
               if(abs(j-35.)<.1)
                 L=max(-K.x,0.);
               y+=.1*M*L*vec3(2.,.35,.025)*GI_LIGHT_BLOCK_INTENSITY;
             }
         }
       if(j<240.5||abs(j-248.)<7.)
         {
           y+=h(T.QbpObHBdUl,K)*M*2.4;
         }
       Y+=vec4(y,G);
     }
   Y/=GI_RAY_COUNT;
   Y.w=saturate(Y.w*.1);
   return Y;
 }
 void main()
 {
   vec4 i=texture2DLod(colortex7,texcoord.xy,0);
   Texcoord=texcoord.xy;
   if(Texcoord.x<HalfScreen.x&&Texcoord.y>HalfScreen.y)
     {
       Texcoord.y-=HalfScreen.y;
       GBufferData m=GetGBufferData(Texcoord.xy);
       MaterialMask x=CalculateMasks(m.materialID,Texcoord.xy);
       vec4 s;
       #ifdef LOD
         float lodDepth=getLodDepthSolidDeferred(Texcoord.xy);
         if (m.depth==1.0&&lodDepth<1.0) {
           s=GetViewPositionLod(Texcoord.xy,lodDepth);
           x.sky=0.0;
         }else
       #endif
       {
         s=GetViewPosition(Texcoord.xy,m.depth);
       }
       vec4 f=gbufferModelViewInverse*vec4(s.xyz,1.),n=gbufferModelViewInverse*vec4(s.xyz,0.);
       vec3 r=normalize(n.xyz),z=normalize((gbufferModelViewInverse*vec4(m.normal,0.)).xyz),e=normalize((gbufferModelViewInverse*vec4(m.geoNormal,0.)).xyz);
       i=c(f.xyz,s.xyz,z,e,r,x,m.mcLightmap.y,m.parallaxOffset);
     }
   gl_FragData[0]=texture2DLod(colortex1,texcoord.xy,0);
   gl_FragData[1]=vec4(i);
 }




/* DRAWBUFFERS:17 */
