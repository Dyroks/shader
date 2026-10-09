#include "DataPacking.inc"
#include "TAA.inc"


vec3 TransformInputColor(vec3 c)
{
	return c * mat3(vec3(5.0/6.0, 1.0/6.0, 0.0),
				    vec3(0.0, 1.0, 0.0),
					vec3(0.0, 0.0, 1.0));
}

vec3 TransformOutputColor(vec3 c)
{
	return c * mat3(vec3(1.2, -0.2, 0.0),
				    vec3(0.0, 1.0, 0.0),
					vec3(0.0, 0.0, 1.0));
}

float saturate(float x)
{
	return clamp(x, 0.0, 1.0);
}

vec3 saturate(vec3 x)
{
	return clamp(x, vec3(0.0), vec3(1.0));
}

vec2 saturate(vec2 x)
{
	return clamp(x, vec2(0.0), vec2(1.0));
}

// polynomial smooth min (k = 0.1); https://www.iquilezles.org/www/articles/smin/smin.htm
float SmoothMin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float SmoothMax(float a, float b, float k)
{
    return -SmoothMin(-a, -b, k);
}

vec2 EncodeNormal(vec3 normal)
{
	float p = sqrt(normal.z * 8.0 + 8.0);
	return vec2(normal.xy / p + 0.5);
}

vec3 DecodeNormal(vec2 enc)
{
	vec2 fenc = enc * 4.0 - 2.0;
	float f = dot(fenc, fenc);
	vec3 normal;
	normal.xy = fenc * sqrt(1.0 - f / 4.0);
	normal.z = 1.0 - f / 2.0;
	return normal;
}

vec4 GetViewPosition(in vec2 coord, in float depth)
{
	vec2 tcoord = coord;
	TemporalJitterProjPosInv01(tcoord);

	vec4 fragposition = gbufferProjectionInverse * vec4(tcoord.st * 4.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

	return fragposition;
}

vec4 GetViewPositionNoJitter(in vec2 coord, in float depth)
{
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.st * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

	return fragposition;
}

vec3 ProjectBack(vec3 cameraSpace)
{
    vec4 clipSpace = gbufferProjection * vec4(cameraSpace, 1.0);
    vec3 NDCSpace = clipSpace.xyz / clipSpace.w;
    vec3 screenSpace = 0.5 * NDCSpace + 0.5;
    return screenSpace;
}

float ExpToLinearDepth(in float depth)
{
	vec2 a = vec2(depth * 2.0 - 1.0, 1.0);

	vec2 d = mat2(
		gbufferProjectionInverse[2].zw,
		gbufferProjectionInverse[3].zw
	) * a;

	d.x /= d.y;

	return -d.x;
}

#ifdef LOD
    mat4 projLod() {
        #ifdef DISTANT_HORIZONS
            return dhProjection;
        #endif
        #ifdef VOXY
            return vxProj;
        #endif
        return gbufferProjection;
    }

    mat4 projInvLod() {
        #ifdef DISTANT_HORIZONS
            return dhProjectionInverse;
        #endif
        #ifdef VOXY
            return vxProjInv;
        #endif
        return gbufferProjectionInverse;
    }

    float getLodDepthSolid(vec2 coord) {
        #ifdef DISTANT_HORIZONS
            return textureLod(dhDepthTex1, coord, 0.0).x;
        #endif
        #ifdef VOXY
            return textureLod(vxDepthTexOpaque, coord * 2.0, 0.0).x;
        #endif
        return textureLod(depthtex1, coord, 0.0).x;
    }

    float getLodDepthSolidDeferred(vec2 coord) {
        #ifdef DISTANT_HORIZONS
            return textureLod(dhDepthTex0, coord, 0.0).x;
        #endif
        #ifdef VOXY
            return textureLod(vxDepthTexOpaque, coord * 2.0, 0.0).x;
        #endif
        return textureLod(depthtex0, coord, 0.0).x;
    }

    float getLodDepthWater(vec2 coord) {
        #ifdef DISTANT_HORIZONS
            return textureLod(dhDepthTex0, coord, 0.0).x;
        #endif
        #ifdef VOXY
            return textureLod(vxDepthTexTrans, coord * 2.0, 0.0).x;
        #endif
        return textureLod(depthtex0, coord, 0.0).x;
    }

	vec4 GetViewPositionLod(in vec2 coord, in float depth)
	{
		vec2 tcoord = coord;
		TemporalJitterProjPosInv01(tcoord);

		vec4 fragposition = projInvLod() * vec4(tcoord.st * 4.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
			fragposition /= fragposition.w;

		return fragposition;
	}

	vec4 GetViewPositionNoJitterLod(in vec2 coord, in float depth)
	{
		vec4 fragposition = projInvLod() * vec4(coord.st * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
			fragposition /= fragposition.w;

		return fragposition;
	}

	float ExpToLinearDepthLod(in float depth)
	{
		vec2 a = vec2(depth * 2.0 - 1.0, 1.0);

		vec2 d = mat2(
			projInvLod()[2].zw,
			projInvLod()[3].zw
		) * a;

		d.x /= d.y;

		return -d.x;
	}

    float lodRenderDistance() {
        #ifdef DISTANT_HORIZONS
            return float(dhRenderDistance);
        #endif
        #ifdef VOXY
            return vxRenderDistance * 16.0;
        #endif
        return far;
    }
#endif

float GetDepthLinear(in vec2 coord)
{
	return ExpToLinearDepth(textureLod(depthtex1, coord, 0.0).x);
}

float GetDepth(vec2 coord)
{
	return textureLod(depthtex1, coord, 0.0).x;
}

float GetDepth2(vec2 coord)
{
	return textureLod(depthtex0, coord, 0.0).x;
}

vec3 GetNormals(vec2 coord)
{
	return DecodeNormal(textureLod(colortex2, coord, 0.0).xy);
}

vec3 GetGeoNormals(vec2 coord)
{
	return DecodeNormal(textureLod(colortex2, coord, 0.0).zw);
}

void GetBothNormals(vec2 coord, out vec3 normal, out vec3 geoNormal)
{
	vec4 texData = textureLod(colortex2, coord, 0.0);

	normal = DecodeNormal(texData.xy);
	geoNormal = DecodeNormal(texData.zw);
}

vec2 LockRenderPixelCoord(vec2 coord)
{
	coord = (floor(coord * ScreenSize) + 0.5) * ScreenTexel;

	return coord;
}

vec3 LinearToGamma(vec3 c)
{
	return pow(c, vec3(1.0 / 2.2));
}

vec3 GammaToLinear(vec3 c)
{
	return pow(c, vec3(2.2));
}

float curve(float x)
{
	return x * x * (3.0 - 2.0 * x);
}

float Luminance(in vec3 color)
{
	return dot(color.rgb, vec3(0.2125f, 0.7154f, 0.0721f));
}

vec3 rand(vec2 coord)
{
	float dotCoord = dot(coord, vec2(12.9898, 78.223));
	float noiseX = fract(sin(dotCoord	   ) * 43758.5453);
	float noiseY = fract(sin(dotCoord * 2.0) * 43758.5453);
	float noiseZ = fract(sin(dotCoord * 3.0) * 43758.5453);

	return vec3(noiseX, noiseY, noiseZ);
}

vec3 hash33(vec3 p3)
{
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx)*p3.zyx);
}

vec3 BlueNoiseTemporal(vec2 coord)
{
	const vec3 irrationals = vec3(0.447213595, 1.41421356, 1.61803398);

	vec2 noiseCoord = vec2(coord.st * ScreenSize) / 64.0;

	vec3 n = textureLod(noisetex, noiseCoord, 0.0).rgb;

	n = fract(n + irrationals * (frameCounter % 64));

	return n;
}

float Get2DNoise(in vec2 pos)
{
	pos.xy += 0.5f;

	vec2 p = floor(pos);
	vec2 f = fract(pos);

	f *= f * (3.0f - 2.0f * f);

	vec2 coord = (p.xy + f.xy  + 0.5f) / 64.0;
	float xy1 = textureLod(noisetex, coord, 0.0).a;
	return xy1;
}

float Get3DNoise(in vec3 pos)
{
	pos.xyz += 0.5f;

	vec3 p = floor(pos);
	vec3 f = fract(pos);

	vec2 uv =  p.xy + p.z * vec2(17.0f) + f.xy + 0.5f;
	vec2 uv2 = uv + vec2(17.0f);

	vec2 coord =  uv  / 64.0;
	vec2 coord2 = uv2 / 64.0;
	float xy1 = textureLod(noisetex, coord, 0.0).x;
	float xy2 = textureLod(noisetex, coord2, 0.0).x;
	return mix(xy1, xy2, f.z);
}


/* https://www.shadertoy.com/view/XsX3zB
 *
 * The MIT License
 * Copyright © 2013 Nikita Miropolskiy
 *
 * ( license has been changed from CCA-NC-SA 3.0 to MIT
 *
 *   but thanks for attributing your source code when deriving from this sample
 *   with a following link: https://www.shadertoy.com/view/XsX3zB )
 *
 * ~
 * ~ if you're looking for procedural noise implementation examples you might
 * ~ also want to look at the following shaders:
 * ~
 * ~ Noise Lab shader by candycat: https://www.shadertoy.com/view/4sc3z2
 * ~
 * ~ Noise shaders by iq:
 * ~     Value    Noise 2D, Derivatives: https://www.shadertoy.com/view/4dXBRH
 * ~     Gradient Noise 2D, Derivatives: https://www.shadertoy.com/view/XdXBRH
 * ~     Value    Noise 3D, Derivatives: https://www.shadertoy.com/view/XsXfRH
 * ~     Gradient Noise 3D, Derivatives: https://www.shadertoy.com/view/4dffRH
 * ~     Value    Noise 2D             : https://www.shadertoy.com/view/lsf3WH
 * ~     Value    Noise 3D             : https://www.shadertoy.com/view/4sfGzS
 * ~     Gradient Noise 2D             : https://www.shadertoy.com/view/XdXGW8
 * ~     Gradient Noise 3D             : https://www.shadertoy.com/view/Xsl3Dl
 * ~     Simplex  Noise 2D             : https://www.shadertoy.com/view/Msf3WH
 * ~     Voronoise: https://www.shadertoy.com/view/Xd23Dh
 * ~
 *
 */

/* discontinuous pseudorandom uniformly distributed in [-0.5, +0.5]^3 */
vec3 random3(vec3 c) {
  float j = 4096 * sin(dot(c,vec3(17.0, 59.4, 15.0)));
  vec3 r;
  r.z = fract(512.0*j);
  r.x = fract(64.0*j);
  r.y = fract(8.0*j);
  return r-0.5;
}

/* skew constants for 3d simplex functions */
const float F3 =  0.3333333;
const float G3 =  0.1666667;

/* 3d simplex noise */
float simplex3d(vec3 p) {
   /* 1. find current tetrahedron T and it's four vertices */
   /* s, s+i1, s+i2, s+1.0 - absolute skewed (integer) coordinates of T vertices */
   /* x, x1, x2, x3 - unskewed coordinates of p relative to each of T vertices*/

   /* calculate s and x */
   vec3 s = floor(p + dot(p, vec3(F3)));
   vec3 x = p - s + dot(s, vec3(G3));

   /* calculate i1 and i2 */
   vec3 e = step(vec3(0.0), x - x.yzx);
   vec3 i1 = e*(1.0 - e.zxy);
   vec3 i2 = 1.0 - e.zxy*(1.0 - e);

   /* x1, x2, x3 */
   vec3 x1 = x - i1 + G3;
   vec3 x2 = x - i2 + 2.0*G3;
   vec3 x3 = x - 1.0 + 3.0*G3;

   /* 2. find four surflets and store them in d */
   vec4 w, d;

   /* calculate surflet weights */
   w.x = dot(x, x);
   w.y = dot(x1, x1);
   w.z = dot(x2, x2);
   w.w = dot(x3, x3);

   /* w fades from 0.6 at the center of the surflet to 0.0 at the margin */
   w = max(0.6 - w, 0.0);

   /* calculate surflet components */
   d.x = dot(random3(s), x);
   d.y = dot(random3(s + i1), x1);
   d.z = dot(random3(s + i2), x2);
   d.w = dot(random3(s + 1.0), x3);

   /* multiply d by w^4 */
   d *= pow(w, vec4(4.0));

   /* 3. return the sum of the four surflets */
   return dot(d, vec4(52.0));
}

vec4 ToSH(float value, vec3 dir)
{
	const float sqrtPI = sqrt(3.14159265359);
	value *= sqrtPI;

	vec4 coeffs;
	float value1 = value / 3.0;

	coeffs.x =  value * 0.5;
	coeffs.yzw = dir.yzx * vec3(-1.0, 1.0, -1.0) * value1;

	return coeffs;
}


vec3 FromSH(vec4 cR, vec4 cG, vec4 cB, vec3 lightDir)
{
	const float PI = 3.14159265 * 4.0;

	const float sqrt1OverPI = sqrt(1.0 / PI);
	const float sqrt3OverPI = sqrt(3.0 / PI);

	vec4 sh;

	sh.x = sqrt1OverPI;
	sh.yzw = sqrt3OverPI * lightDir.yzx * vec3(-1.0, 1.0, -1.0);

	vec3 result;
	result.r  = dot(sh,cR);
	result.g  = dot(sh,cG);
	result.b  = dot(sh,cB);

	return result.rgb;
}

struct Ray
{
    vec3 origin;
    vec3 direction;
    vec3 inv_direction;
};

Ray MakeRay(vec3 origin, vec3 direction)
{
    vec3 inv_direction = vec3(1.0) / direction;
    return Ray(
        origin,
        direction,
        inv_direction
    );
}

vec3 DoNightEyeAtNight(in vec3 color, float timeFactor)
{
	return color;
	float luminance = Luminance(color);

	float rodFactor = 0.6f / (luminance * 1000.0 + 1.0);

	color = mix(color, luminance * vec3(0.3, 0.6, 1.35), vec3(rodFactor * timeFactor));

	return color;
}

vec3 GetWaterAbsorption()
{
	return vec3(0.25, 0.04, 0.01);
}

vec3 GetLavaAbsorption()
{
	return vec3(0.0, 0.05, 0.2);
}

const float WaterM = 0.03 * WATER_FOG_DENSITY;

vec3 TintUnderwaterDepth(vec3 color)
{
	if (isEyeInWater > 0)
	{
		float underwaterDepth = 1.0 - (eyeBrightnessSmooth.y / 240.);
		color *= exp(-(GetWaterAbsorption() + WaterM) * underwaterDepth * 8.0);
	}

	return color;
}

void UnderwaterFog(inout vec3 color, float eyeLength, vec3 eyeDir, vec3 skyColor, vec3 sunColor)
{
	float underwaterDepth = 1.0 - (eyeBrightnessSmooth.y / 240.0);
	underwaterDepth *= 16.0;

	float x = eyeLength * 0.2;
	float weight = eyeLength / far;
	x = (eyeLength - x) * weight + x ;

	const float fD = WaterM * 5.0;
	vec3 wAK = saturate(GetWaterAbsorption() * 4.0) + fD;
	float v = eyeDir.y - 1.0;

	color *= exp(-wAK * x);

	vec3 w = (0.1 * fD / v) * (exp(-wAK * (underwaterDepth - v * x)) - exp(-underwaterDepth * wAK)) / wAK;

	color += max(vec3(0.0), w * (0.0005 * (1.0 - wetness * 0.75) * sunColor * SUNLIGHT_BRIGHTNESS + 0.00025 * (1.0 - wetness * 0.5) * skyColor)) * (eyeBrightnessSmooth.y + 1.0);
}

void UnderLavaFog(inout vec3 color, float eyeLength, vec3 eyeDir)
{
	float underwaterDepth = 1.0 - (eyeBrightnessSmooth.y  / 240.0);

	float x = eyeLength * 5.0;
	vec3 wAK = GetLavaAbsorption() + WaterM;
	float v = eyeDir.y - 1.0;

	color *= exp(-wAK * x);

	vec3 w = (0.15 * WaterM / v) * (exp(-wAK * (underwaterDepth - v * x)) - exp(-underwaterDepth * wAK)) / wAK;

	color += max(vec3(0.0), w * vec3(1.,.08,0.));
}

void NetherFog(inout vec3 color, float eyeLength, vec3 eyeDir)
{

	float x = pow(eyeLength, 2.0) / 24.;
	vec3 wAK = -saturate(vec3(0.00001) / fogColor);
	float fD = WaterM;
	vec3 wFA = vec3(0.15 * fD);

	wAK -= fD;
	wFA /= wAK;

	color *= exp(wAK * x * WATER_FOG_DENSITY);

	vec3 w = wFA * (-exp(wAK) + exp(wAK * (1.0 + x)));

	color += max(vec3(0.0), w * fogColor * 0.00025);
}

void TheEndFog(inout vec3 color, float eyeLength, vec3 eyeDir)
{

	float x = pow(eyeLength, 2.0) / 64;
	float wAK = -0.1;
	float fD = WaterM * 0.1;
	float wFA = 0.15 * fD;

	wAK -= fD;
	wFA /= wAK;

	color *= exp(wAK * x * WATER_FOG_DENSITY);

	float w = wFA * (-exp(wAK) + exp(wAK * (1.0 + x)));

	color += vec3(max(0.0, w * 0.000025));
}

vec4 GetCausticsTexComposite(vec2 coord)
{
	vec2 lookupCoord = vec2(coord.x, (coord.y - floor(fract(frameTimeCounter) * 60.0f)) / 60.0f);
	return textureLod(colortex4, lookupCoord.st, 0.0);
}

float GetCausticsComposite(vec3 worldPos, vec3 worldLightVector, float waterDepth)
{
	vec3 causticPos = worldPos.xyz + cameraPosition.xyz;
	vec3 refractLightVector = refract(worldLightVector, vec3(0.0, 1.0, 0.0), 0.75);
	causticPos += refractLightVector * (causticPos.y / refractLightVector.y);

	vec4 causticsTex = GetCausticsTexComposite(fract(causticPos.xz / 2.0));

	float depthBlend = sqrt(waterDepth / 3.0);

	float caustics = mix(0.1, causticsTex.r, saturate(depthBlend));
	caustics = mix(caustics, causticsTex.g, saturate(depthBlend - 1.0));
	caustics = mix(caustics, causticsTex.b, saturate(depthBlend - 2.0));
	caustics = mix(caustics, causticsTex.a, saturate(depthBlend - 3.0));

	return caustics * 10.0 / (depthBlend + 1.);
}

vec4 GetCausticsTexDeferred(vec2 coord)
{
	vec2 lookupCoord = vec2(coord.x, (coord.y - floor(fract(frameTimeCounter) * 60.0f)) / 60.0f);
	return textureLod(colortex0, lookupCoord.st, 0.0);
}


float GetCausticsDeferred(vec3 worldPos, vec3 worldLightVector, float waterDepth)
{
	vec3 causticPos = worldPos.xyz + cameraPosition.xyz;
	vec3 refractLightVector = refract(worldLightVector, vec3(0.0, 1.0, 0.0), 0.75);
	causticPos += refractLightVector * (causticPos.y / refractLightVector.y);

	vec4 causticsTex = GetCausticsTexDeferred(fract(causticPos.xz / 2.0));

	float depthBlend = sqrt(waterDepth / 3.0);

	float caustics = mix(0.1, causticsTex.r, saturate(depthBlend));
	caustics = mix(caustics, causticsTex.g, saturate(depthBlend - 1.0));
	caustics = mix(caustics, causticsTex.b, saturate(depthBlend - 2.0));
	caustics = mix(caustics, causticsTex.a, saturate(depthBlend - 3.0));

	return caustics * 10.0 / (depthBlend + 1.);
}

// https://pubs.rsc.org/en/content/articlehtml/2019/nr/c9nr01707k
//
// Mie
// g : ( -0.75, -0.999 )
//      3 * ( 1 - g^2 )               1 + c^2
// F = ----------------- * -------------------------------
//      2 * ( 2 + g^2 )     ( 1 + g^2 - 2 * g * c )^(3/2)
float PhaseMie( float g, float LdotV, float LdotV2 ) {
	float gg = g * g;

	float a = (1.0 - gg) * LdotV2;

	float b = 1.0 + gg - 2.0 * g * LdotV;
	b *= sqrt(b);
	b *= 2.0 + gg;

	return 1.5 * a / b;
}

const vec3 Rayleigh = vec3(0.17, 0.40, 0.99);
const vec3 exp2Rayleigh = exp2(-Rayleigh * 0.2);

float AtmosphereMie = 0.005 + wetness * 0.5;
const float AtmosphereDensity = 0.07;
const float AtmosphereDensityFalloff = 0.3;
const float AtmosphereExtent = 80.0;

vec3 MplusR = AtmosphereMie + Rayleigh;

vec3 AtmosphereAbsorption(vec3 dir, float depth)
{
	float rDFv = AtmosphereDensityFalloff * dir.y;

	vec3 absorption = exp((-MplusR - wetness * 0.5) * (AtmosphereDensity / rDFv) * (1.0- exp(-rDFv * depth)));

	return absorption;
}

vec3 SunAbsorptionAtAltitude(float sunlightDir, float altitude)
{
	float rDFs = AtmosphereDensityFalloff * sunlightDir;
	float rDFa = AtmosphereDensityFalloff * altitude;

	return exp(AtmosphereDensity/rDFs * (-MplusR * exp(-rDFa) - exp(-rDFa - 1000*rDFs)));
}

vec3 Atmosphere(vec3 worldViewVector, vec3 worldSunVector, float mieAmount, float depthFactor, const float LdotV, const float LdotV2)
{
	float LdotV_2 = -LdotV * 0.5 + 0.5;
	vec3 color = vec3(0.0);

	float x = depthFactor;
	float s = SmoothMax(0.01, worldSunVector.y, 0.07);
	float v = pow(abs(worldViewVector.y), 1.0 + LdotV_2 * 0.0005 / (s + 0.0005)) * sign(worldViewVector.y);

	float M = AtmosphereMie;
	float rDF = AtmosphereDensityFalloff - LdotV_2 * max(0.0, -worldSunVector.y + 0.01) * 4.0;
	float halfWetness = wetness * 0.5;
	float energyFade = exp(min(0.0, worldSunVector.y) * 100.0);

	float floorDist = min(x, 0.5 / (-worldViewVector.y + 0.00918));
	if (worldViewVector.y < 0.0)
		x = floorDist;
	M += 0.007 / (max(worldViewVector.y, 0.0) + 0.05);

	float t1 = 1.0 + (-1.0 + exp(-1000.0 * rDF * s)) * v / s;
	vec3 MpR = M + Rayleigh;
	float t3 = rDF * v;
	vec3 t5 = MpR * (AtmosphereDensity / t3);
	x = exp(x * t3);
	vec3 t5x = t5 / x;

	vec3 atmos = (exp(t5 * (t1 - 1.0)) - exp(-t5 + t5x * t1))/ (MpR * t1);

	atmos *= energyFade;
	atmos *= pow(Rayleigh, vec3(0.005 / (max(worldSunVector.y, 0.0) + 0.009))); 	// Blue tint at twilight

	float rainEnergyLoss = 1.0 - 0.75 * wetness * wetness;

	atmos *= rainEnergyLoss;
	vec3 atmos2 = atmos * M * mieAmount;

	color = max(vec3(0.0), atmos * Rayleigh * 0.75 * LdotV2 + atmos2 * (PhaseMie(0.9 - halfWetness, LdotV, LdotV2) + 3.0 * PhaseMie(0.6 - halfWetness, LdotV, LdotV2)));


	{
		vec3 ms = (1.0 - exp(t5x - t5)) * rainEnergyLoss;
		color += max(vec3(0.0), ms) * (exp(SmoothMin(0.0, worldSunVector.y, 0.03) * 200.0) * 0.05);
	}

	color *= 7.0 * SUNLIGHT_BRIGHTNESS;

	color *= 1.0 - wetness * halfWetness;

	if (worldViewVector.y < 0.0 && depthFactor > 75.0) {
		color += vec3(0.1, 0.325, 0.5) * exp(-MpR * (floorDist * 0.1 + 0.2 / (max(worldSunVector.y, 0.0) + 0.001))) * (1.0 - wetness * wetness * 0.85);
	}

	return color;
}


vec3 Atmosphere(vec3 worldViewVector, vec3 worldSunVector, float mieAmount, float LdotV, float LdotV2)
{
	return Atmosphere(worldViewVector, worldSunVector, mieAmount, AtmosphereExtent, LdotV, LdotV2);
}

// Main sky shading function
vec3 SkyShading(vec3 worldViewVector, vec3 worldSunVector)
{
	float LdotV = dot(worldViewVector, worldSunVector);
	float LdotV2 = LdotV * LdotV + 1.0;
	vec3 atmosphere = Atmosphere(worldViewVector, worldSunVector, 0.25, LdotV, LdotV2);
	atmosphere += Atmosphere(worldViewVector, -worldSunVector, 0.25, -LdotV, LdotV2) * nightBrightness;

	return atmosphere;
}

vec3 RenderSunDisc(vec3 worldDir, vec3 sunDir, vec3 colorSunlight)
{
	float d = dot(worldDir, sunDir);

	float hardness = 2000.0;

	float disc = pow(curve(saturate((d - (0.99965)) * hardness)), 2.0);

	float visibility = curve(saturate(worldDir.y * 30.0));

	disc *= visibility;

	vec3 result = vec3(disc);
	result += pow(max(0.0, visibility / (-d * 250 + 250.01) - 0.1), 2.0) * 0.0002 * colorSunlight.r * SUNLIGHT_BRIGHTNESS;

	return result;
}

vec3 RenderSunDiscRefelction(vec3 worldDir, vec3 sunDir, vec3 colorSunlight)
{
	float d = dot(worldDir, sunDir);

	float hardness = 2000.0;

	float disc = pow(curve(saturate((d - 0.99960) * hardness)), 2.0);

	float visibility = curve(saturate(worldDir.y * 30.0));

	disc *= visibility;

	vec3 result = vec3(disc);
	result += pow(max(0.0, visibility / (-d * 250 + 250.01) - 0.1), 2.0) * 0.0002 * colorSunlight.r * SUNLIGHT_BRIGHTNESS;

	return result;
}

void LandAtmosphericScattering(inout vec3 color, in vec3 viewPos, vec3 worldDir, vec3 worldSunVector)
{
	float dist = length(viewPos);

	dist *= pow(saturate(eyeBrightnessSmooth.y / 240.), 6.0);

	color *= AtmosphereAbsorption(worldDir, dist * 0.005);

	worldDir = normalize(worldDir);
	float LdotV = dot(worldDir, worldSunVector);

	color += Atmosphere(worldDir, worldSunVector, wetness * 0.25, dist * mix(0.005, 0.015, wetness), LdotV, LdotV * LdotV + 1.0) * 0.1
		* pow(1.0 - exp2(-dist * 0.02), 2.0);
}

struct Intersection {
	vec3 pos;
	float dist;
	float angle;
};

vec3 KelvinToRGB(float k)
{
	const vec3 c = vec3(0.02, 0.48, 0.99);

	float x = k - 6500.0;
	float xc = pow(abs(x), 1.1) * sign(x);

	return exp(xc * (0.00045 * c - 0.00017)) * 0.5;
}


vec3 GetColorTorchlight()
{
	return KelvinToRGB(float(TORCHLIGHT_COLOR_TEMPERATURE));
}

void GetSkylightData(vec3 worldSunVector, vec3 worldLightVector, vec3 colorSunlight, float timeMidnight,
	out vec4 skySHR, out vec4 skySHG, out vec4 skySHB, out vec3 colorSkyUp)
{
	skySHR = vec4(0.0);
	skySHG = vec4(0.0);
	skySHB = vec4(0.0);
	colorSkyUp = SkyShading(vec3(0.0, 1.0, 0.0), worldSunVector);

	for (int i = 0; i < 5; i++)
	{
		float latitude = float(i) * 0.62831853;
		float cosLatitude = cos(latitude), sinLatitude = sin(latitude);
		for (int j = 0; j < 5; j++)
		{
			float longitude = float(j) * 1.25663706;

			vec3 rayDir;
			rayDir.x = cosLatitude * cos(longitude);
			rayDir.z = cosLatitude * sin(longitude);
			rayDir.y = sinLatitude;

			vec3 skyCol = SkyShading(rayDir, worldSunVector);
			skyCol = DoNightEyeAtNight(skyCol * 12., timeMidnight) * .083333;

			skySHR += ToSH(skyCol.r, rayDir);
			skySHG += ToSH(skyCol.g, rayDir);
			skySHB += ToSH(skyCol.b, rayDir);
		}
	}

	skySHR /= 25.;
	skySHG /= 25.;
	skySHB /= 25.;
}





// Time data
float GetTimeMidnight(vec3 worldSunVector)
{
	return saturate(-worldSunVector.y * 10.0);
}

vec3 GetGlowBerryColor(vec3 worldPos)
{
	worldPos = floor(worldPos);
	float hashTime = frameTimeCounter * 0.0;
	vec3 hash0 = hash33(worldPos + mod(floor(hashTime), 256.0));
	// vec3 hash1 = hash33(worldPos + mod(floor(hashTime + 1.0), 256.0));
	// vec3 hashSmooth = mix(hash0, hash1, fract(hashTime));


	float time = frameTimeCounter;

	vec3 color = textureLod(noisetex, (worldPos.xz + time) * 0.002 , 0.0).rgb;
	color *= color;
	// vec3 color = vec3(1.0);

	// color *= hashSmooth;
	// color *= hashSmooth;
	// color *= hashSmooth;

	// color *= exp((hash0 * hash0 * hash0 - 0.9) * 5.0);
	color *= pow(hash0, vec3(1.0)) + 0.05;
	color = color.rrr * 5.0;
	color += 0.05;

	color *= vec3(0.3, 0.09, 0.003);

	return color;
}
