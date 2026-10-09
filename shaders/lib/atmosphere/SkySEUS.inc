// =====================================================================================
//  SEUS sky / atmosphere functions (moved unchanged from lib/Common.inc so that compute
//  programs can use them too). To be replaced by the Hillaire 2020 atmosphere (phase 4).
//  Needs: wetness, nightBrightness, SUNLIGHT_BRIGHTNESS.
// =====================================================================================

#ifndef SKY_SEUS_INC
#define SKY_SEUS_INC

#ifndef SKY_SEUS_HELPERS_DEFINED
#define SKY_SEUS_HELPERS_DEFINED
float SmoothMin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float SmoothMax(float a, float b, float k)
{
    return -SmoothMin(-a, -b, k);
}
#endif

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

#endif
