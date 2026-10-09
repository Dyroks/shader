#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"


const bool colortex3MipmapEnabled = true;


in vec4 texcoord;


float AutoExposureMin = mix(0.00064, 0.0000001, nightVision);
const float AutoExposureMult = 25.0;
vec3 ApplyAutoExposure(vec3 color, float avgLum)
{
	return (color / (avgLum + AutoExposureMin)) * AutoExposureMult;
}

vec3 ApplyAutoExposureInverse(vec3 color, float avgLum)
{
	return (color / AutoExposureMult) * (avgLum + AutoExposureMin);
}
 float g(vec2 v)
 {
   v=(floor(v*ScreenSize)+.5)*ScreenTexel;
   vec4 texLod=texture2DLod(colortex5,v,0);
   return UnpackTwo16BitFrom32Bit(texLod.w).y*255.;
 }
 vec2 D(vec2 v,float m,inout float lodDepth,out float y)
 {
   vec2 i=v;
   y=m;
   for(int r=-1;r<=1;r+=2)
     {
       for(int f=-1;f<=1;f+=2)
         {
           vec2 n=v+vec2(r,f)*ScreenTexel;
           float z=texture2DLod(depthtex0,n,0).x;
           if(z<y)
             y=z,i=n;
           #ifdef LOD
           else if(y==1.0){
             float lodSampleDepth=getLodDepthWater(n);
             if(lodSampleDepth<lodDepth){
               i=n;lodDepth=lodSampleDepth;
             }
           }
           #endif
         }
     }
   return i;
 }
 vec3 c(vec3 y)
 {
   mat3 v=mat3(.2126,.7152,.0722,-.09991,-.33609,.436,.615,-.55861,-.05639);
   return y*v;
 }
 vec3 g(vec3 y)
 {
   mat3 v=mat3(1.,0.,1.28033,1.,-.21482,-.38059,1.,2.12798,0.);
   return y*v;
 }
 vec3 c(vec3 x,vec3 v,vec3 m)
 {
   vec3 f=m-x,s=f/v,d=abs(s);
   float r=max(d.x,max(d.y,d.z));
   if(r>1.)
     return x+f/r;
   else
      return m;
 }
 vec4 D(vec2 y)
 {
   return pow(texture2DLod(colortex6,y,0),vec4(vec3(1./2.2),1.));
 }
 vec4 c(vec2 y)
 {
   vec2 n=y*ScreenSize,i=floor(n-.5)+.5,s=n-i,z=s*s,e=s*z;
   vec2 r=.5*(-e+2.*z-s),
        t=1.5*e-2.5*z+1.,
        h=-1.5*e+2.*z+.5*s,
        d=.5*(e-z),
        o=t+h,
        c=ScreenTexel*(i+h/o);
   vec4 a=D(c);
   vec2 C=ScreenTexel*(i-1.),l=ScreenTexel*(i+2.);
   vec4 R=(vec4(D(vec2(c.x,C.y)).xyz,1.)*r.y+
           vec4(D(vec2(c.x,l.y)).xyz,1.)*d.y)*o.x+
          (vec4(D(vec2(C.x,c.y)).xyz,1.)*r.x+
           vec4(a.xyz,1.)*o.x+
           vec4(D(vec2(l.x,c.y)).xyz,1.)*d.x)*o.y;
   return pow(vec4(max(vec3(0.),R.xyz/R.w),a.w),vec4(vec3(2.2),1.));
 }
 float D()
 {
   float v=floor(log2(min(viewWidth,viewHeight)));
   return min(1.095,pow(dot(texture2DLod(colortex3,vec2(.65),v+1).xyz,vec3(.33333)),1.1))*.3;
 }
 void D(vec2 v,float x,float lodDepth,out vec2 y)
 {
   vec4 m=vec4(v.xy*2.-1.,x*2.-1.,1.);
   vec4 n;
   #ifdef LOD
   if(x==1.0){
     m.z=lodDepth*2.0-1.0;
     n=projInvLod()*m;
   }else
   #endif
   {
     n=gbufferProjectionInverse*m;
   }
   n.xyz/=n.w;
   vec4 f=gbufferModelViewInverse*vec4(n.xyz,1.);
   f.xyz+=cameraPosition-previousCameraPosition;
   vec4 s=gbufferPreviousModelView*vec4(f.xyz,1.),e=gbufferPreviousProjection*vec4(s.xyz,1.);
   e.xyz/=e.w;
   y=m.xy-e.xy;
 }
 vec3 D(vec3 v)
 {
   return 2./(1.+exp(-v))-1.;
 }
 void main()
 {
   float v=texture2D(depthtex0,texcoord.xy).x;
   vec3 i=texture2DLod(colortex3,texcoord.st,0).xyz;
   vec2 b=texcoord.st*.5;
   float f=texture2D(depthtex0,b).x,z;
   float lodNearestDepth=1.0;
   #ifdef LOD
   lodNearestDepth=getLodDepthWater(b);
   if(v==1.0){
     float lodDepth=ExpToLinearDepthLod(getLodDepthWater(texcoord.xy));
     vec2 d=mat2(
       gbufferProjection[2].zw,
       gbufferProjection[3].zw
     )*vec2(-lodDepth,1.0);
     v=saturate(d.x/d.y*0.5+0.5);
   }
   #endif
   vec2 e=D(b,f,lodNearestDepth,z);
   vec2 t;
   D(texcoord.xy,z,lodNearestDepth,t);
   f=step(.7,f);
   t*=f;
   vec2 d=texcoord.xy-t*.5;
   vec2 A=cos((fract(abs(texcoord.xy-d.xy)*ScreenSize)*2.-1.)*3.14159)*.5+.5;
   vec2 B=sqrt(A);
   vec4 R=c(d.xy);
   float p=1.4;
   vec3 q=vec3(0.);
   float j=g(texcoord.xy);
   q=vec3(1.)/(pow(j,1.4)+1.);
   q=max(q,vec3(.01));
   #if AA_STYLE!=1
   q=vec3(.01);
   #endif
   q=saturate(q*max(.05,frameTime)*30.);
   if(f<.7)
     p=.8;
   if(abs(d.x-.5)>.5||abs(d.y-.5)>.5)
     q=vec3(1.);
   vec3 S=vec3(0.),J=vec3(0.),F=vec3(0.),K=vec3(0.);
   for(int Z=-1;Z<=1;Z++)
     {
       bool Z0=Z==0;
       for(int P=-1;P<=1;P++)
         {
           vec2 Q=vec2(float(Z),float(P))*ScreenTexel;
           vec3 G=texture2D(colortex3,texcoord.st+Q).xyz;
           S+=G*float(P==0);
           J+=G*float(Z0);
           G=c(G);
           F+=G;
           K+=G*G;
         }
     }
   S/=3.;
   J/=3.;
   vec3 G=F/9.,Z=sqrt(max(vec3(0.),K/9.-G*G)),V=p*Z;
   #ifdef SKIP_AA
   q=vec3(1.);
   #endif
   float H=texture2DLod(colortex6,vec2(0.,0.),0).a*.01;
   vec3 m=ApplyAutoExposureInverse(D(ApplyAutoExposure(i-S,H)*.5),H)*2.,
        n=ApplyAutoExposureInverse(D(ApplyAutoExposure(i-J,H)*.5),H)*2.;
   i+=m*(.3/q)*B.x;
   i+=n*(.3/q)*B.y;
   i+=m*(5./q)*min(.05,abs(t.x));
   i+=n*(5./q)*min(.05,abs(t.y));
   R.xyz=g(c(G,V,c(R.xyz)));
   vec3 E=mix(R.xyz,i,q);
   if(length(texcoord.xy*ScreenSize)<1.)
     {
       float u=D()*1000.,O=texture2DLod(colortex6,texcoord.xy,0).w;
       u=mix(O,u,saturate(u>O?1.5*frameTime:6.*frameTime));
       v=u;
     }
   E=max(vec3(0.),E);
   vec2 u=t*min(inversesqrt(dot(t,t)),1.0);
   u*=f;
   gl_FragData[0]=vec4(u.xy*.5+.5,0.,1.);
   gl_FragData[1]=vec4(E,v);
 }




/* DRAWBUFFERS:26 */
