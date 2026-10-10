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
flat in vec3 colorSkyUp;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/GBufferData.inc"
#include "/lib/Materials.inc"

#ifdef VOLUMETRIC_CLOUDS
flat in vec3 cloudSkyAmbient;
#include "/lib/clouds/CloudLookups.inc"
#include "/lib/clouds/CloudComposite.inc"
#if ATMOSPHERE_MODEL == 1
#define AIR_LIGHT_UPSAMPLE
#include "/lib/atmosphere/Crepuscular.inc"
#endif
#endif


const int shadowMapResolution = 8192; // Higher value impacts performance costs, but can get better shadow, and increase path tracing distance. Please increase the shadow distance at the same time. 4096 - 80 blocks path tracing. 8192 - 160 blocks path tracing. 16384 - 300 blocks path tracing, requires at least 6GB VRAM. 34768 - 530 blocks of path tracing, requires at least 20GB VRAM. [4096 8192 16384 32768]
const float SHADOW_MAP_RESOLUTION = shadowMapResolution * MC_SHADOW_QUALITY;


vec3 WorldPosToShadowProjPos(vec3 worldPos)
{
	vec4 sp = (shadowModelView * vec4(worldPos, 1.0));
	sp = shadowProjection * sp;
	sp /= sp.w;

	float dist = length(sp.xy);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	sp.xy *= 0.95f / distortFactor;
	sp.z = mix(sp.z, 0.5, 0.8);
	sp = sp * 0.5f + 0.5f;		//Transform from shadow space to shadow map coordinates

	//move to quadrant
	sp.xy *= 2048.0 / SHADOW_MAP_RESOLUTION;
	sp.xy += (SHADOW_MAP_RESOLUTION - 2048.0) / SHADOW_MAP_RESOLUTION;

	return sp.xyz;
}
 float h(float v,float y)
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
   GBufferData v=GetGBufferData(texcoord.xy);
   GBufferDataTransparent y=GetGBufferDataTransparent(texcoord.xy);
   MaterialMask d=CalculateMasks(y.materialID,texcoord.xy);
   bool isWater=y.depth<v.depth;
   float lodWaterDepth=1.0;
   #ifdef LOD
     float lodSolidDepth=getLodDepthSolid(texcoord.xy);
     d.sky*=float(lodSolidDepth==1.0);
     lodWaterDepth=getLodDepthWater(texcoord.xy);
     isWater=isWater||(lodWaterDepth<lodSolidDepth&&y.depth==1.0);
   #endif
   if(isWater)
     v.normal=y.normal,v.smoothness=y.smoothness,v.metalness=0.,v.depth=y.depth,d.sky=0.;
   float r=ExpToLinearDepth(v.depth);
   vec4 i;
   #ifdef LOD
     if (y.depth==1.0&&lodWaterDepth<1.0) {
       v.depth=lodWaterDepth;
       i=GetViewPositionLod(texcoord.xy,v.depth);
     }else
   #endif
   {
     i=GetViewPosition(texcoord.xy,v.depth);
   }
   vec4 m=gbufferModelViewInverse*vec4(i.xyz,0.);
   vec3 c=normalize(m.xyz),V=normalize((gbufferModelViewInverse*vec4(v.normal,0.)).xyz);
   float a=1.-v.smoothness,w=a*a;
   vec3 q=-c,Y=normalize(reflect(-q,V)+V*w),b=normalize(q+Y);
   float g=max(0.,dot(V,Y)),F=max(0.,dot(V,q)),D=max(0.,dot(Y,b)),P=v.metalness*.96+.04,L=pow(1.-D,5.),u=P+(1.-P)*L,I=w*.5,invI=1.-I,k=1./((g*invI+I)*((F+.8)*invI+I)),T=g*u*k;
   bool eyeInWater=isEyeInWater==1;
   T=mix(T,1.,v.metalness);
   T*=step(v.depth,.999999);
   if(d.water>.5&&eyeInWater)
     {
       float n=0.75;
       float LdotH=dot(q,V);
       float sinR2=1.-LdotH*LdotH,cosR=sqrt(1.0-sinR2/(n*n));
       float r1=(n*LdotH-cosR)/(n*LdotH+cosR),r2=(n*cosR-LdotH)/(n*cosR+LdotH);
       float kR=min(1.0,0.5*(r1*r1+r2*r2));
       T=kR;
     }
   T*=h(v.smoothness,v.metalness);
   vec4 e=texture2DLod(colortex7,texcoord.xy+HalfScreen,0);
   e.xyz*=mix(vec3(1.),v.albedo.xyz,vec3(v.metalness))*12.;
   vec3 U=texture2DLod(colortex1,texcoord.xy+HalfScreen,0).xyz;
   U=pow(U,vec3(2.2));
   U*=120.;
   float lengthM=length(m.xyz);
   if(eyeInWater)
     UnderwaterFog(U,lengthM,c,colorSkyUp,colorSunlight);
   if(isEyeInWater==2)
     UnderLavaFog(U,lengthM,c);
   vec3 E=U;
   U=mix(U,e.xyz,saturate(T));
   if(d.sky<.5)
     U+=E*v.metalness;
   // light shafts of the pack (terrain shadows, close range): added after the clouds, the air
   // they light lies in front of them
   vec3 vlAdd=vec3(0.);
   if(wetness<.99)
     {
       #ifdef GODRAYS
       if(isEyeInWater<2)
       #else
       if(eyeInWater)
       #endif
         {
           float H=BlueNoiseTemporal(texcoord.xy).x,N=100.;
           vec3 C=vec3(0.),Q=gbufferModelViewInverse[3].xyz;
           #if defined VOLUMETRIC_CLOUDS && defined CLOUD_SHADOWS
           CloudShadowFrame cloudShadowFrame=CloudShadowMakeFrame(worldLightVector);
           #endif
           vec3 Temp=c.xyz*N;
           for(int M=0;M<32;M++)
             {
               float A=float(M+H)/32.;
               vec3 W=Temp*A+gbufferModelViewInverse[3].xyz;
               if(lengthM<length(W-Q))
                 break;
               vec3 K=WorldPosToShadowProjPos(W.xyz);
               K.z+=1e-06;
               float shadowStrength=shadow2DLod(shadowtex0,vec3(K.xyz),1).x;
               if(shadowStrength<.1)
                 continue;
               vec3 Z=vec3(shadowStrength);
               #ifdef GODRAYS_STAINED_GLASS_TINT
               float X=shadow2DLod(shadowtex0,vec3(K.xy-vec2(.5,0.),K.z),1).x;
               if(X<.9)
                 {
                   vec3 ad=texture2DLod(shadowcolor,vec2(K.xy-vec2(.5,0.)),2).xyz;
                   ad*=ad;
                   Z=mix(Z*ad,Z,vec3(X));
                   Z*=Z;
                 }
               #endif
               #if defined VOLUMETRIC_CLOUDS && defined CLOUD_SHADOWS
               Z*=CloudShadowTransmittance(CloudShadowOpticalDepth(cloudShadowFrame,W.xyz));
               #endif
               if(eyeInWater)
                 {
                   float ag=shadow2DLod(shadowtex0,vec3(K.xy-vec2(0.,.5),K.z),1).x,ae=(1.-texture2DLod(shadowcolor1,K.xy-vec2(0.,.5),1).x)*512.-(128.+W.y+cameraPosition.y),af=GetCausticsComposite(W,worldLightVector,max(0.,ae));
                   Z=mix(Z*af,Z,vec3(ag));
                   if(ae<0.)
                     continue;
                   C+=Z*exp(-vec3(0.25, 0.04, 0.01)*(N*A))*(400.0/(pow(ae,2.)+200.)/(1.0+length(W)*0.2));
                 }
               else
                 C+=sqrt(Z*colorSunlight)*.1;
             }
           float vlStrength=0.0;
           float Z=dot(worldLightVector,c.xyz),K=1.;
           if(isEyeInWater==0)
             {
               if(worldTime<=12500)
                 vlStrength=pow(abs(worldTime-6000)/6500.,2.0);
               else if(worldTime<=23500)
                 vlStrength=pow(abs(worldTime-18000)/5500.,2.0);
               else
                 vlStrength=pow(abs(worldTime-30000)/6500.,2.0);
               vlStrength=vlStrength*0.4+0.5;
               vlStrength*=Z*0.25+0.75;
               K=.5/(max(0.,pow(worldLightVector.y,2.)*2.)+.4);
             }
           else
             {
               vlStrength=dot(refract(worldLightVector,vec3(0.,-1.,0.),.750019),c.xyz);
               vlStrength=vlStrength*.3+.6;
             }
           float j=PhaseMie(.8,vlStrength,vlStrength*vlStrength+1.);
           vec3 vl=TintUnderwaterDepth(C*SUNLIGHT_BRIGHTNESS*colorSunlight*vec3(0.046, 0.05175, 0.0575)*j*K*(1.-wetness));
           vlAdd=vl*VOLUMETRIC_LIGHT_STRENGTH;
         }
     }
   if(d.sky<.5&&isEyeInWater<1)
     LandAtmosphericScattering(U,i.xyz,c.xyz,worldSunVector.xyz);
   #ifdef VOLUMETRIC_CLOUDS
   if(isEyeInWater==0)
     {
       vec2 cloudTD;
       CloudComposite(U,c.xyz,texcoord.xy,cloudSkyAmbient,cloudTD);
       #ifdef AIR_LIGHT_ACTIVE
       // crepuscular rays (the light the air in the shadow of the clouds does not scatter) and
       // the haze layer
       // computed at low resolution by composite4_c, integrated here only where the upsampling
       // finds no sample of a similar surface
       float airDist=CloudSurfaceDistance(texcoord.xy);
       AirLight air;
       if(!AirLightUpsample(ivec2(texcoord.xy*vec2(viewWidth,viewHeight)),airDist,air))
         air=AirLightIntegrate(c.xyz,airDist,cloudTD,BlueNoiseTemporal(texcoord.xy),cloudSkyAmbient,pow(saturate(eyeBrightnessSmooth.y/240.),6.));
       U=AirLightApply(U,air,cloudToComposite);
       #endif
     }
   #endif
   U+=vlAdd;
   U/=120.;
   U*=exp(-r*blindness);
   U=pow(U.xyz,vec3(.454545));
   gl_FragData[0]=vec4(U,Luminance(U));
 }





/* DRAWBUFFERS:1 */
