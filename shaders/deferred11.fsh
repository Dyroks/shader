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

const int shadowMapResolution = 8192; // Higher value impacts performance costs, but can get better shadow, and increase path tracing distance. Please increase the shadow distance at the same time. 4096 - 80 blocks path tracing. 8192 - 160 blocks path tracing. 16384 - 300 blocks path tracing, requires at least 6GB VRAM. 34768 - 530 blocks of path tracing, requires at least 20GB VRAM. [4096 8192 16384 32768]
const float SHADOW_MAP_RESOLUTION = shadowMapResolution * MC_SHADOW_QUALITY;
const float RAY_TRACING_RESOLUTION = SHADOW_MAP_RESOLUTION - 2048.0;
const float RAY_TRACING_DIAMETER_TEMP = floor(pow(RAY_TRACING_RESOLUTION, 2.0 / 3.0));
const float RAY_TRACING_DIAMETER = RAY_TRACING_DIAMETER_TEMP - mod(RAY_TRACING_DIAMETER_TEMP - 1.0, 2.0);
const float RAY_TRACING_RADIUS = RAY_TRACING_DIAMETER / 2.0;

vec3 WorldPosToShadowProjPosBias(vec3 worldPos, vec3 worldNormal)
{
	vec4 sp = (shadowModelView * vec4(worldPos, 1.0));
	sp = shadowProjection * sp;

	float dist = length(sp.xy);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;

	sp.xy *= 0.95f / distortFactor;
	sp.z = mix(sp.z, 0.5, 0.8);
	sp = sp * 0.5f + 0.5f;		//Transform from shadow space to shadow map coordinates

	sp.xy *= 2048.0 / SHADOW_MAP_RESOLUTION;
	sp.xy += (SHADOW_MAP_RESOLUTION - 2048.0) / SHADOW_MAP_RESOLUTION;

	return sp.xyz;
}

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
 void main()
 {
   float r=i(texcoord.xy);
   vec2 c=vec2(0.,HalfScreen.y);
   vec4 e=texture2DLod(colortex7,texcoord.xy+c,0);
   vec3 h=e.xyz;
   vec3 a,t;
   GetBothNormals(texcoord.xy,a,t);
   float R=GetDepth(texcoord.xy);
   vec3 d;
   #ifdef LOD
   if(R==1.0){
     float lodDepth=getLodDepthSolidDeferred(texcoord.xy);
     R=lodDepth;
     d=GetViewPositionLod(texcoord.xy,R).xyz;
   }else
   #endif
   {
     d=GetViewPosition(texcoord.xy,R).xyz;
   }
   int taps=1;
   #ifdef AB_GI_VOLUME
   // sky or outside the voxel volume: no filtering (see PathTraceDenoiser.glsl), caustics still needed
   vec3 worldPosC=mat3(gbufferModelViewInverse)*d+gbufferModelViewInverse[3].xyz;
   if(R>=1.0||max(max(abs(worldPosC.x),abs(worldPosC.y)),abs(worldPosC.z))>RAY_TRACING_RADIUS)
     taps=0;
   #endif
   float o=-d.z;
   vec3 H=normalize(d);
   vec2 j=vec2(0.0);
   if (r>.95)
     j=BlueNoiseTemporal(texcoord.xy).xy-.5;
   float p=2.,Y=2.;
   G(p,Y,e.w,r,o);
   float Z=24.*mix(1.,0.,r),S=mix(3.,1.,r)/o;
   vec4 X=vec4(0.);
   float F=0.;
   vec2 P=normalize(cross(t,vec3(0.,0.,1.)).xy),l=P.yx*vec2(1.,-1.);
   l*=saturate(dot(t,-H))*.8+.2;
   vec2 coordTemp=P*p*ScreenTexel;
   float luminaceH=Luminance(h.xyz);
   for(int C=-taps;C<=taps;C++)
     {
       vec2 B=texcoord.xy+vec2(C+j)*coordTemp;
       B=clamp(B,ScreenTexel*2.,HalfScreen-ScreenTexel*2.);
       vec4 T=texture2DLod(colortex7,B+c,0);
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
         q*=4./2.;
       else
         q*=pow(saturate(dot(a,A)),Z);
       float K=exp(-G(T.xyz,h,Y)),W=K*q;
       X+=T*W;
       F+=W;
     }
   vec4 y=e;
   if(F>.0001)
     {
       X/=F+.0001;
       y=X;
     }
   float z=1.;
   if(R < 0.999999)
     {
       vec3 worldPos = (gbufferModelViewInverse * vec4(d, 1.0)).xyz;
       vec3 worldGeoNormal = normalize(mat3(gbufferModelViewInverse) * t);
       vec3 shadowProjPos = WorldPosToShadowProjPosBias(worldPos, worldGeoNormal);
		   float waterDepth = max(0.0, (1.0 - texture2DLod(shadowcolor1, shadowProjPos.st - vec2(0.0, 0.5), 0).x) * 512.0 - 128.0 - (worldPos.y + cameraPosition.y));
		   float caustics = GetCausticsDeferred(worldPos, worldLightVector, waterDepth);
       z = caustics;
     }
   gl_FragData[0]=vec4(y.xyz,z);
 }

/* DRAWBUFFERS:7 */
