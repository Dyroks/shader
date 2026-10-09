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
in vec3 colorSkyUp;

in mat4 gbufferPreviousModelViewInverse;
in mat4 gbufferPreviousProjectionInverse;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/GBufferData.inc"


const int shadowMapResolution = 8192; // Higher value impacts performance costs, but can get better shadow, and increase path tracing distance. Please increase the shadow distance at the same time. 4096 - 80 blocks path tracing. 8192 - 160 blocks path tracing. 16384 - 300 blocks path tracing, requires at least 6GB VRAM. 34768 - 530 blocks of path tracing, requires at least 20GB VRAM. [4096 8192 16384 32768]
const float SHADOW_MAP_RESOLUTION = shadowMapResolution * MC_SHADOW_QUALITY;
const float RAY_TRACING_RESOLUTION = SHADOW_MAP_RESOLUTION - 2048.0;
const float RAY_TRACING_DIAMETER_TEMP = floor(pow(RAY_TRACING_RESOLUTION, 2.0 / 3.0));
const float RAY_TRACING_DIAMETER = RAY_TRACING_DIAMETER_TEMP - mod(RAY_TRACING_DIAMETER_TEMP - 1.0, 2.0);
const float RAY_TRACING_RADIUS = RAY_TRACING_DIAMETER / 2.0;


/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


 vec3 b()
 {
   ivec2 f=ivec2(texcoord.st*ScreenSize);
   float z=viewWidth*float(f.y/altRTDiameter);
   f.x+=int(mod(z,altRTDiameter));
   float i=float(int(f.x)/altRTDiameter);
   i+=floor(z/altRTDiameter);
   f=f%altRTDiameter;
   vec3 t=vec3(f.x,i,f.y);
   t.xyz=floor(t.xyz);
   return t;
 }
 vec2 t(vec3 v)
 {
   ivec2 m=ivec2(viewWidth,viewHeight);
   vec3 f=floor(v.xzy+1e-05);
   f.x+=f.z*altRTDiameter;
   vec2 i;
   i.x=mod(f.x,m.x);
   i.y=f.y+floor(f.x/m.x)*altRTDiameter;
   i+=.5;
   i/=m;
   return i;
 }
 ivec2 d(vec3 v)
 {
   v=clamp(v,vec3(0.),vec3(RAY_TRACING_DIAMETER - 1.0));
   v.x+=v.y*RAY_TRACING_DIAMETER;
   v.y=v.z+floor(v.x/RAY_TRACING_RESOLUTION)*RAY_TRACING_DIAMETER;
   v.x=mod(v.x,RAY_TRACING_RESOLUTION);
   return ivec2(v.xy);
 }
 vec3 e(vec3 v)
 {
   vec4 f=vec4(v,1.);
   f=shadowModelView*f;
   f=shadowProjection*f;
   f/=f.w;
   float x=length(f.xy),y=1.f-SHADOW_MAP_BIAS+x*SHADOW_MAP_BIAS;
   f.xy*=.95f/y;
   f.z=mix(f.z,.5,.8);
   f=f*.5f+.5f;
   f.xy*=2048./SHADOW_MAP_RESOLUTION;
   f.xy+=(SHADOW_MAP_RESOLUTION-2048.)/SHADOW_MAP_RESOLUTION;
   return f.xyz;
 }
 struct rXuEJcsNQI{vec3 QbpObHBdUl;vec3 QbpObHBdUlOrigin;vec3 ZRrfSsHfvT;vec3 fgCeZiNBHZ;vec3 ZKdJsVHIyK;vec3 frnQIYJjVJ;};
 rXuEJcsNQI r(Ray v)
 {
   rXuEJcsNQI f;
   f.QbpObHBdUl=floor(v.origin);
   f.QbpObHBdUlOrigin=f.QbpObHBdUl;
   f.ZRrfSsHfvT=abs(vec3(length(v.direction))/(v.direction+1e-07));
   f.fgCeZiNBHZ=sign(v.direction);
   f.ZKdJsVHIyK=(f.fgCeZiNBHZ*(f.QbpObHBdUl-v.origin)+f.fgCeZiNBHZ*.5+.5)*f.ZRrfSsHfvT;
   f.frnQIYJjVJ=vec3(0);
   return f;
 }
 void i(inout rXuEJcsNQI v)
 {
   v.frnQIYJjVJ=step(v.ZKdJsVHIyK.xyz,vec3(min(v.ZKdJsVHIyK.x,min(v.ZKdJsVHIyK.y,v.ZKdJsVHIyK.z))));
   v.ZKdJsVHIyK+=v.frnQIYJjVJ*v.ZRrfSsHfvT,v.QbpObHBdUl+=v.frnQIYJjVJ*v.fgCeZiNBHZ;
 }
 vec3 f(vec3 v,vec3 f,vec3 y)
 {
   if(wetness>.99)
     return vec3(0.);
   vec3 i=v-vec3(RAY_TRACING_DIAMETER/2.-1);
   i-=FractedCameraPosition;
   vec3 t=e(i+y*.99);
   float shadowStrength=shadow2DLod(shadowtex0,vec3(t.xy,t.z-.0002),3).x;
   vec3 r=vec3(shadowStrength);
   r*=saturate(dot(f,y));
   r=TintUnderwaterDepth(r);
   if(shadowStrength<.1)
     return r*(1.-wetness);
   #ifdef GI_SUNLIGHT_STAINED_GLASS_TINT
   float m=shadow2DLod(shadowtex0,vec3(t.xy-vec2(.5,0.),t.z-.0002),3).x;
   if(m<.9)
     {
       vec3 c=texture2DLod(shadowcolor,vec2(t.xy-vec2(.5,0.)),3).xyz;
       c*=c;
       r=mix(r*c,r,vec3(m));
     }
   #endif
   float waterShadow=shadow2DLod(shadowtex0,vec3(t.xy-vec2(0.,.5),t.z),3).x;
   if(waterShadow<.9)
     {
       float waterDepth=texture2DLod(shadowcolor1,vec2(t.xy-vec2(0.,.5)),3).x*256.0-(i.y+cameraPosition.y);
       r/=sqrt(waterDepth)+1.;
     }
   #ifdef CLOUD_SHADOW
   r*=CloudShadow(i+y*.99,worldLightVector);
   #endif
   return r*(1.-wetness);
 }
 struct awIafiSlNY{float mwtAZpOIMX;float KZGLOOTLva;float yDFXZDbcEk;float cvVAxIXMRt;vec3 jbwXZaPXmq;};
 vec4 p(awIafiSlNY v)
 {
   vec4 f;
   v.jbwXZaPXmq=max(vec3(0.),v.jbwXZaPXmq);
   f.x=v.mwtAZpOIMX;
   v.jbwXZaPXmq=pow(v.jbwXZaPXmq,vec3(.125));
   f.y=PackTwo16BitTo32Bit(v.jbwXZaPXmq.x,v.yDFXZDbcEk);
   f.z=PackTwo16BitTo32Bit(v.jbwXZaPXmq.y,v.cvVAxIXMRt);
   f.w=PackTwo16BitTo32Bit(v.jbwXZaPXmq.z,v.KZGLOOTLva/255.);
   return f;
 }
 awIafiSlNY h(vec4 v)
 {
   awIafiSlNY f;
   vec2 t=UnpackTwo16BitFrom32Bit(v.y),m=UnpackTwo16BitFrom32Bit(v.z),i=UnpackTwo16BitFrom32Bit(v.w);
   f.mwtAZpOIMX=v.x;
   f.yDFXZDbcEk=t.y;
   f.cvVAxIXMRt=m.y;
   f.KZGLOOTLva=i.y*255.;
   f.jbwXZaPXmq=pow(vec3(t.x,m.x,i.x),vec3(8.));
   return f;
 }
 awIafiSlNY c(vec2 v)
 {
   v=(floor(v*ScreenSize)+.5)*ScreenTexel;
   return h(texture2DLod(colortex5,v,0));
 }
 vec3 a(vec2 v)
 {
   v=(floor(v*ScreenSize)+.5)*ScreenTexel;
   vec4 texLod=texture2DLod(colortex5,v,0);
   vec2 unpackY=UnpackTwo16BitFrom32Bit(texLod.y);
   vec2 unpackZ=UnpackTwo16BitFrom32Bit(texLod.z);
   vec2 unpackW=UnpackTwo16BitFrom32Bit(texLod.w);
   return pow(vec3(unpackY.x,unpackZ.x,unpackW.x),vec3(8.));
 }
 float D(vec2 v,float y,inout float lodDepth)
 {
   vec4 f;
   y=min(y,texture2D(depthtex1,v+ScreenTexel).x);
   y=min(y,texture2D(depthtex1,v+ScreenTexel*vec2(1.,-1.)).x);
   y=min(y,texture2D(depthtex1,v+ScreenTexel*vec2(-1.,1.)).x);
   y=min(y,texture2D(depthtex1,v-ScreenTexel).x);
   #ifdef LOD
   lodDepth=min(lodDepth,getLodDepthSolidDeferred(v+ScreenTexel));
   lodDepth=min(lodDepth,getLodDepthSolidDeferred(v+ScreenTexel*vec2(1.,-1.)));
   lodDepth=min(lodDepth,getLodDepthSolidDeferred(v+ScreenTexel*vec2(-1.,1.)));
   lodDepth=min(lodDepth,getLodDepthSolidDeferred(v-ScreenTexel));
   #endif
   return y;
 }
 vec3 e(vec3 v,vec3 y)
 {
   vec2 f=t(clamp(v-vec3(RAY_TRACING_DIAMETER/2.-1)+y+cameraPosCenterDiff+vec3(.5*altRTDiameter),vec3(0.),vec3(altRTDiameter)));
   return a(f);
 }
 vec3 D(vec3 irCachePos)
 {
   vec2 y=t(irCachePos+cameraPosCenterDiff);
   return a(y);
 }
 vec3 c(vec3 irCachePos)
 {
   vec3 x=irCachePos-vec3(.5*altRTDiameter);
   float s=1.;
   #ifdef CAVE_GI_LEAK_FIX
   if(isEyeInWater<1)
     s*=saturate(eyeBrightnessSmooth.y/12.);
   #endif
   vec3 x2=clamp(x+vec3(RAY_TRACING_DIAMETER/2.),vec3(0.),vec3(RAY_TRACING_DIAMETER));
   float c=1000.;
   float n=texelFetch(shadowcolor,d(floor(x2)),0).w*255.;
   c=min(c,texelFetch(shadowcolor,d(floor(x2+vec3(0.,0.,-1.))),0).w);
   c=min(c,texelFetch(shadowcolor,d(floor(x2+vec3(1.,0.,0.))),0).w);
   c=min(c,texelFetch(shadowcolor,d(floor(x2+vec3(0.,0.,1.))),0).w);
   c=min(c,texelFetch(shadowcolor,d(floor(x2+vec3(-1.,0.,0.))),0).w);
   c=min(c,texelFetch(shadowcolor,d(floor(x2+vec3(0.,1.,0.))),0).w);
   c=min(c,texelFetch(shadowcolor,d(floor(x2+vec3(0.,-1.,0.))),0).w);
   if(c*255.>254.5||(n<67.5&&n!=37.&&n!=39.))
     return vec3(0.);
   vec3 a=vec3(0.);
   float randNum=sin(frameTimeCounter*1.1)+x.x*.11+x.y*.12+x.z*.13;
   vec3 rayOrigin=clamp(x2,vec3(-1.),vec3(RAY_TRACING_DIAMETER-1.));
   for(int l=0;l<GI_SECONDARY_SAMPLES;l++)
     {
       vec3 q=normalize(rand(vec2(randNum+l*.1))*2.-1.);
       if(q.x==q.y||q.x==q.z)q.x+=.01;
       if(q.y==q.z)q.y+=.01;
       Ray R=MakeRay(rayOrigin,q);
       rXuEJcsNQI S=r(R);
       i(S);
       float prevU=0.;
       for(int K=0;K<1;K++)
         {
           vec4 G=vec4(0.);
           float U=0.;
           vec3 stainedColor=vec3(1.);
           for(int Z=0;Z<DIFFUSE_TRACE_LENGTH;Z++)
             {
               G=texelFetch(shadowcolor,d(S.QbpObHBdUl),0);
               U=G.w*255.;
               if(U<240.5)
                 {
                   if(U==37.||U==39.)
                     {
                       if(U==37.&&prevU==37.)
                         {
                           G.xyz=normalize(G.xyz+1e-4)*pow(dot(G.xyz,G.xyz),.25);
                           G.xyz=mix(vec3(1.),G.xyz,.5);
                           G.xyz*=G.xyz;
                           stainedColor*=G.xyz;
                         }
                       i(S);
                       prevU=U;
                       continue;
                     }
                   break;
                 }
               if(U==241.)
                 {
                   if(Z==0)
                     G.xyz*=.5;
                   a+=G.xyz*stainedColor*GI_LIGHT_TORCH_INTENSITY;
                 }
               i(S);
               prevU=U;
             }
           G.xyz*=stainedColor;
           if(U<1.f||U>254.f)
             {
               vec3 D=R.direction;
               if(isEyeInWater>0)
                 D=refract(D,vec3(0.,-1.,0.),1.3333);
               vec3 P=SkyShading(D,worldSunVector);
               P*=saturate(D.y*10.+1.);
               P=DoNightEyeAtNight(P*12.,timeMidnight)*.083333;
               vec3 Y=P,b=Y;
               #ifdef CLOUDS_IN_GI
               CloudPlane(Y,vec3(0.),-R.direction,worldLightVector,worldSunVector,colorSunlight,colorSkyUp,b,timeMidnight,false);
               #endif
               Y=TintUnderwaterDepth(Y*s);
               a+=Y*.1*stainedColor;
               break;
             }
           if(abs(U-31.)<.1||abs(U-36.)<.1)
             a+=.1*G.xyz*GI_LIGHT_BLOCK_INTENSITY;
           vec3 F=-S.frnQIYJjVJ*S.fgCeZiNBHZ;
           if(U>=32.&&U<=35.)
             {
               float D=max(-F.z,0.);
               if(abs(U-33.)<.1)
                 D=max(F.x,0.);
               if(abs(U-34.)<.1)
                 D=max(F.z,0.);
               if(abs(U-35.)<.1)
                 D=max(-F.x,0.);
               a+=.04*D*vec3(2.,.35,.025)*GI_LIGHT_BLOCK_INTENSITY;
             }
           if(U<240.5)
             {
               G.xyz=saturate(G.xyz/3.)*3.;
               if(abs(dot(S.QbpObHBdUl-S.QbpObHBdUlOrigin,F))>=1.1)
                 a+=DoNightEyeAtNight(f(S.QbpObHBdUl,worldLightVector,F)*SUNLIGHT_BRIGHTNESS*2.4*colorSunlight*G.xyz*s*12.,timeMidnight)/12.;
               a+=e(S.QbpObHBdUl,F)*G.xyz;
             }
         }
     }
   a/=float(GI_SECONDARY_SAMPLES);
   return saturate(a/2.4);
 }
 vec4 c(vec2 v,float x,float lodDepth)
 {
   vec4 f=vec4(texcoord.xy*4.-1.,x*2.-1.,1.);
   #ifdef LOD
   if(x>=1.0&&lodDepth<1.0){
     f.z=lodDepth*2.-1.;
     f=projInvLod()*f;
   }else
   #endif
   {
     f=gbufferProjectionInverse*f;
   }
   f/=f.w;
   vec3 t=(gbufferModelViewInverse*vec4(f.xyz,1.)).xyz;
   vec2 i=fract(v*ScreenSize)-.5;
   const vec2 m[4]=vec2[4](vec2(0.,0.),vec2(1.,0.),vec2(0.,1.),vec2(1.,1.));
   vec4 r[4];
   vec2 signI=ScreenTexel*sign(i);
   float lengthT=length(t.xyz)+.001;
   for(int c=0;c<4;c++)
     {
       vec2 z=m[c]*signI,w=LockRenderPixelCoord(v+z);
       vec4 texLod=texture2DLod(colortex4,w,0);
       vec4 n=gbufferPreviousProjectionInverse*vec4(w*4.-1.,texLod.w*2.-1.,1.);
       n/=n.w;
       vec3 d=(gbufferPreviousModelViewInverse*vec4(n.xyz,1.)).xyz;
       d-=cameraPositionDiff;
       float D=length(d.xyz-t.xyz)/lengthT;
       r[c]=vec4(texLod.xyz,1.)*step(D,.1);
     }
   vec2 s=abs(i);
   vec4 z=mix(r[0],r[1],vec4(s.x)),w=mix(r[2],r[3],vec4(s.x)),c=mix(z,w,vec4(s.y));
   c.xyz/=c.w+.0001;
   return vec4(c.xyz,c.w);
 }
 vec2 D(float v,float lodDepth,vec2 f,out vec3 i)
 {
   float y=D(texcoord.xy,v,lodDepth);
   if(y<.7)
     return texcoord.xy;
   vec4 m=vec4(texcoord.xy*4.-1.,y*2.-1.,1.);
   vec4 r;
   #ifdef LOD
   if(y>=1.0&&lodDepth<1.0){
     m.z=lodDepth*2.-1.;
     r=projInvLod()*m;
   }else
   #endif
   {
     r=gbufferProjectionInverse*m;
   }
   r.xyz/=r.w;
   vec4 t=gbufferModelViewInverse*vec4(r.xyz,1.);
   t.xyz+=cameraPositionDiff;
   vec4 s=gbufferPreviousModelView*vec4(t.xyz,1.),w=gbufferPreviousProjection*vec4(s.xyz,1.);
   w.xyz/=w.w;
   i=(m.xyz-w.xyz)*.5;
   vec2 n=f.xy-i.xy*.5;
   return n;
 }
 void main()
 {
   vec4 y=vec4(0.);
   awIafiSlNY v;
   v.mwtAZpOIMX=.1;
   v.yDFXZDbcEk=.1;
   v.cvVAxIXMRt=.1;
   v.jbwXZaPXmq=vec3(0.);
   if(texcoord.x<HalfScreen.x&&texcoord.y<HalfScreen.y)
     {
       vec4 tex2=texture2DLod(colortex2,texcoord.st,0);
       vec3 geoNormal=DecodeNormal(tex2.zw);
       float depth=texture2D(depthtex1,texcoord.xy).x;
       float lodDepth=1.0;
       vec4 i;
       #ifdef LOD
         lodDepth=getLodDepthSolidDeferred(texcoord.xy);
         if (depth==1.0&&lodDepth<1.0) {
           i=GetViewPositionLod(texcoord.xy,lodDepth);
           vec2 proj=mat2(gbufferProjection[2].zw,gbufferProjection[3].zw)*vec2(i.z,1.0);
           depth=proj.x/proj.y*0.5+0.5;
         }else
       #endif
       {
         i=GetViewPosition(texcoord.xy,depth);
       }
       vec3 z=normalize(i.xyz);
       vec3 a;
       vec2 g=D(depth,lodDepth,texcoord.xy,a),U=g.xy;
       U-=(vec2((frameCounter>>1)%2,frameCounter%2)-.5)*ScreenTexel*.125;
       vec4 S=c(U.xy,depth,lodDepth);
       awIafiSlNY F=c(g.xy);
       float e=1./(saturate(-dot(geoNormal,z))*100.+1.);
       F.mwtAZpOIMX+=1.;
       F.mwtAZpOIMX=min(F.mwtAZpOIMX,MAX_BLEND_WEIGHT);
       float k=0.,J=1.-1./(F.mwtAZpOIMX+1.);
       if(S.w<.01||abs(g.x-0.5)>0.5-ScreenTexel.x||abs(g.y-0.5)>0.5-ScreenTexel.y||abs(e-F.yDFXZDbcEk)>.1)
         J=0.,k=.99,F.mwtAZpOIMX=0.;
       vec3 l=texture2DLod(colortex7,texcoord.xy+vec2(0.,HalfScreen.y),0).xyz;
       l=mix(l,S.xyz,vec3(J));
       k=max(k,mix(k,.9,saturate(-a.z*520.)));
       F.yDFXZDbcEk=e;
       F.cvVAxIXMRt=mix(k,F.cvVAxIXMRt,mix(J*.25,0.,k));
       l=max(vec3(0.),l);
       y=vec4(l,depth);
       v=F;
     }
   vec3 irCachePos=b();
   v.jbwXZaPXmq=mix(D(irCachePos),c(irCachePos),vec3(.025));
   v.KZGLOOTLva=c(texcoord.xy).KZGLOOTLva;
   gl_FragData[0]=vec4(y);
   gl_FragData[1]=max(vec4(0.),p(v));
 }




/* DRAWBUFFERS:45 */
