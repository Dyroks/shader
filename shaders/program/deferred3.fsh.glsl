in vec4 texcoord;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"


 struct awIafiSlNY{float mwtAZpOIMX;float KZGLOOTLva;float yDFXZDbcEk;float cvVAxIXMRt;vec3 jbwXZaPXmq;};
 vec4 i(awIafiSlNY v)
 {
   vec4 i;
   v.jbwXZaPXmq=max(vec3(0.),v.jbwXZaPXmq);
   i.x=v.mwtAZpOIMX;
   v.jbwXZaPXmq=pow(v.jbwXZaPXmq,vec3(.125));
   i.y=PackTwo16BitTo32Bit(v.jbwXZaPXmq.x,v.yDFXZDbcEk);
   i.z=PackTwo16BitTo32Bit(v.jbwXZaPXmq.y,v.cvVAxIXMRt);
   i.w=PackTwo16BitTo32Bit(v.jbwXZaPXmq.z,v.KZGLOOTLva/255.);
   return i;
 }
 awIafiSlNY w(vec4 v)
 {
   awIafiSlNY i;
   vec2 m=UnpackTwo16BitFrom32Bit(v.y),n=UnpackTwo16BitFrom32Bit(v.z),x=UnpackTwo16BitFrom32Bit(v.w);
   i.mwtAZpOIMX=v.x;
   i.yDFXZDbcEk=m.y;
   i.cvVAxIXMRt=n.y;
   i.KZGLOOTLva=x.y*255.;
   i.jbwXZaPXmq=pow(vec3(m.x,n.x,x.x),vec3(8.));
   return i;
 }
 awIafiSlNY c(vec2 v)
 {
   v=(floor(v*ScreenSize)+.5)*ScreenTexel;
   return w(texture2DLod(colortex5,v,0));
 }
 void main()
 {
   vec4 x=texture2DLod(colortex7,texcoord.xy,0);
   if(texcoord.x<HalfScreen.x&&texcoord.y>HalfScreen.y)
     {
       vec2 m=texcoord.xy-vec2(0.,HalfScreen.y);
       awIafiSlNY g=c(m);
       float b=g.cvVAxIXMRt;
       vec4 n=texture2DLod(colortex4,m.xy,0);
       vec2 c=rand(texcoord.xy+sin(frameTimeCounter)).xy-.5;
       float d=mix(1.,4.,sqrt(b));
       vec3 a=vec3(0.),e=vec3(0.);
       vec2 ST4=ScreenTexel*4.;
       const float G=9+1e-06;
       for(int p=-1;p<=1;p++)
         {
           for(int R=-1;R<=1;R++)
             {
               vec2 o=m.xy+(vec2(p,R)+c)*ScreenTexel*d;
               o=clamp(o,ST4,1.-ST4);
               vec3 T=texture2DLod(colortex4,o,0).xyz;
               a+=T;
               e+=T*T;
             }
         }
       a/=G;
       e/=G;
       vec3 p=sqrt(max(vec3(0.),e-a*a));
       float o=dot(p.xyz,vec3(6.));
       o/=saturate(dot(a,vec3(400.))/(saturate(b)+.001))+1e-05;
       x=vec4(n.xyz,o);
     }
   awIafiSlNY m=c(texcoord.xy);
   if(texcoord.x<HalfScreen.x&&texcoord.y<HalfScreen.y)
     {
       float f=m.cvVAxIXMRt;
       for(int y=-1;y<=1;y++)
         {
           for(int z=-1;z<=1;z++)
             {
               vec2 n=vec2(y,z)*ScreenTexel,s=texcoord.xy+n.xy;
               float t=c(s.xy).cvVAxIXMRt;
               f=min(f,t);
             }
         }
       m.cvVAxIXMRt=f;
     }
   gl_FragData[0]=i(m);
   gl_FragData[1]=x;
 }




/* DRAWBUFFERS:57 */
