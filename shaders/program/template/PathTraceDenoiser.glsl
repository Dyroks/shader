in vec4 texcoord;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"


 float i(vec2 v)
 {
   v=(floor(v*ScreenSize)+.5)*ScreenTexel;
   float texLod=texture2DLod(colortex5,v,0).z;
   return UnpackTwo16BitFrom32Bit(texLod).y;
 }
 void G(inout float v,inout float x,float i,float y,float z)
 {
   v*=mix(3.,4.25,y);
   if(z<.12)
     x=0.;
   else
     {
       x*=1.-pow(y,.4);
       x/=i*.4+8e-06;
     }
 }
 float G(vec3 v,vec3 y,float m)
 {
   float x=dot(abs(v-y),vec3(.3333));
   x*=m;
   return x;
 }
 vec4 G(sampler2D v,vec2 f,bool x,float y,float m,vec2 s)
 {
   float r=i(f.xy);
   vec2 c=vec2(0.,HalfScreen.y);
   vec4 e=texture2DLod(v,f.xy+c,0);
   vec3 h=e.xyz;
   vec3 a,t;
   GetBothNormals(f.xy,a,t);
   float R=GetDepth(f.xy);
   vec3 d;
   #ifdef LOD
   if(R==1.0){
     float lodDepth=getLodDepthSolidDeferred(f.xy);
     d=GetViewPosition(f.xy,lodDepth).xyz;
   }else
   #endif
   {
     d=GetViewPosition(f.xy,R).xyz;
   }
   float o=-d.z;
   vec3 H=normalize(d);
   vec2 j=vec2(0.0);
   if (x||r>.95)
     j=BlueNoiseTemporal(texcoord.xy).xy-.5;
   float p=y,Y=m;
   G(p,Y,e.w,r,o);
   float Z=24.*mix(1.,0.,r),S=mix(3.,1.,r)/o;
   vec4 X=vec4(0.);
   float F=0.;
   vec2 P=normalize(cross(t,vec3(0.,0.,1.)).xy),l=P.yx*vec2(1.,-1.);
   l*=saturate(dot(t,-H))*.8+.2;
   vec2 coordTemp=(s.x*P+s.y*l)*p*ScreenTexel;
   float luminaceH=Luminance(h.xyz);
   for(int C=-1;C<=1;C++)
     {
       vec2 B=f.xy+vec2(C+j)*coordTemp;
       B=clamp(B,ScreenTexel*2.,HalfScreen-ScreenTexel*2.);
       vec4 T=texture2DLod(v,B+c,0);
       vec3 A,L;
       GetBothNormals(B,A,L);
       float depth=GetDepth(B);
       vec3 E;
       #ifdef LOD
       if(depth==1.0){
         float lodDepth=getLodDepthSolidDeferred(B);
         E=GetViewPositionLod(B,lodDepth).xyz;
       }else
       #endif
       {
         E=GetViewPosition(B,depth).xyz;
       }
       vec3 g=E.xyz-d.xyz;
       float D=length(g);
       float M=dot(g,t);
       bool k=M>.05&&Luminance(T.xyz)<luminaceH;
       float q=saturate(exp(-abs(M)*20.*S));
       if(k&&D<1.&&dot(-g,L)>0.)
         q*=4./y;
       else
         q*=pow(saturate(dot(a,A)),Z);
       float K=exp(-G(T.xyz,h,Y)),W=K*q;
       X+=T*W;
       F+=W;
     }
   if(F<.0001)
     return e;
   X/=F+.0001;
   return X;
 }
