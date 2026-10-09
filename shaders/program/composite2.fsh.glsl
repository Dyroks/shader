#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/GBufferData.inc"


in vec4 texcoord;


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
 vec4 G(sampler2D v,float x)
 {
   GBufferData s=GetGBufferData(texcoord.xy);
   GBufferDataTransparent f=GetGBufferDataTransparent(texcoord.xy);
   bool c=f.depth<s.depth;
   if(c)
     s.normal=f.normal,s.smoothness=f.smoothness,s.metalness=0.,s.depth=f.depth;
   vec4 r=GetViewPosition(texcoord.xy,s.depth);
   vec3 h=normalize(r.xyz);
   float p=GetDepthLinear(texcoord.xy),a=dot(-h,s.normal.xyz),l=1.-s.smoothness,w=l*l,b=e(s.smoothness,s.metalness);
   vec4 F=texture2DLod(v,texcoord.xy+HalfScreen,0);
   if(b<.001)
     return F;
   float T=x*.9;
   T*=min(w*20.,1.1);
   T*=mix(F.w,1.,.2);
   vec2 k=BlueNoiseTemporal(texcoord.xy).xy*.99-.495;
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
   D*=Temp,L*=Temp;
   w=115./w;
   for(int W=-1;W<=1;W++)
     {
       vec2 offsetPart1=(W+k.x)*D+texcoord.st;
       for(int C=-1;C<=1;C++)
         {
           vec2 X=offsetPart1+(C+k.y)*L;
           X=clamp(X,4.*ScreenTexel,1.-4.*ScreenTexel);
           vec4 V=texture2DLod(v,X+HalfScreen,0);
           float Z=GetDepthLinear(X),j=pow(saturate(dot(A,reflect(-h,GetNormals(X)))),w),ab=exp(-(abs(Z-p)*1.1)),ac=j*ab;
           U+=vec4(pow(dot(V.xyz,V.xyz),J*.5)*normalize(V.xyz+1e-10),V.w)*ac;
           E+=ac;
         }
     }
   if(E<.001)
     return F;
   U/=E+.0001;
   U.xyz=pow(dot(U.xyz,U.xyz),.5/J)*normalize(U.xyz+1e-06);
   vec4 q=U;
   return q;
 }
 void main()
 {
   vec4 i=G(colortex7,15.);
   gl_FragData[0]=vec4(i);
 }




/* DRAWBUFFERS:7 */
