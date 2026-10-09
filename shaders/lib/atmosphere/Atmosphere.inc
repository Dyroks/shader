// =====================================================================================
//  Physical atmosphere (Hillaire 2020, "A Scalable and Production Ready Sky and Atmosphere
//  Rendering Technique"), used when ATMOSPHERE_MODEL == 1.
//
//  LUTs computed every frame by compute programs:
//    begin_d.csh  transmittance          256 x 64   (Bruneton parametrisation)
//    begin_e.csh  multiple scattering     32 x 32   (infinite orders, isotropic approximation)
//    begin_f.csh  sky-view              192 x 216   (top half: lit by the sun, bottom: by the moon)
//  Aerial perspective is a short ray march through the transmittance / multiple scattering LUTs.
//
//  Units: kilometres "of the real atmosphere". One block = 1 m * CLOUD_SCALE, so the atmosphere
//  scales with the clouds (the image does not depend on the scale). Ground level: Y = 63.
//  Luminance is computed for a sun illuminance of 1 (times the sun colour) and converted to the
//  pack's sky units with atmoUnit (a white wall facing the sun has a radiance of 24 x sunlight).
//
//  Needs: cameraPosition, wetness. Lookups need ATMOSPHERE_LUTS defined.
// =====================================================================================

#ifndef ATMOSPHERE_INC
#define ATMOSPHERE_INC

const float atmoPI = 3.14159265359;
const float atmoRg = 6360.0;                       // ground radius (km)
const float atmoRt = 6460.0;                       // top of the atmosphere (km)
const float atmoKmPerBlock = 0.001 / CLOUD_SCALE;
const float atmoGroundY = 63.0;

const vec3  atmoRayleighScat = vec3(5.802, 13.558, 33.1) * 1e-3;   // per km, sea level
const float atmoMieScat = 3.996e-3;
const float atmoMieExt  = 4.40e-3;
const vec3  atmoOzoneAbs = vec3(1.4, 1.881, 0.085) * 1e-3;   // red: ~610 nm (sRGB red) rather than 680 nm
const float atmoMieG = 0.8;
const vec3  atmoGroundAlbedo = vec3(0.25);
const vec3  atmoSunColor = vec3(0.976709, 0.946058, 0.871758);     // the pack's sun colour above the atmosphere
const float atmoHaze = exp2(float(ATMOSPHERE_HAZE) - 2.0);          // 0.25 .. 16 x the clean air aerosols
const float atmoUnit = 24.0 * atmoPI * SUNLIGHT_BRIGHTNESS * ATMOSPHERE_SKY_BRIGHTNESS;

const vec2 atmoTransmittanceSize = vec2(256.0, 64.0);
const vec2 atmoMultiScatSize = vec2(32.0, 32.0);
const vec2 atmoSkyViewSize = vec2(192.0, 108.0);

// ---- Medium ---------------------------------------------------------------------------
float AtmoMieDensityScale() {
	return atmoHaze * (1.0 + 6.0 * wetness);   // rain: grey, hazy air
}

struct AtmoMedium {
	vec3 scatR;
	float scatM;
	vec3 ext;
};

AtmoMedium AtmoSampleMedium(float h, float mieScale) {
	AtmoMedium m;
	float dR = exp(-h / 8.0);
	float dM = exp(-h / 1.2) * mieScale;
	float dO = max(0.0, h < 25.0 ? h / 15.0 - 2.0 / 3.0 : 8.0 / 3.0 - h / 15.0);
	m.scatR = atmoRayleighScat * dR;
	m.scatM = atmoMieScat * dM;
	m.ext = m.scatR + vec3(atmoMieExt * dM) + atmoOzoneAbs * dO;
	return m;
}

float AtmoPhaseRayleigh(float c) {
	return 3.0 / (16.0 * atmoPI) * (1.0 + c * c);
}

// Cornette-Shanks
float AtmoPhaseMie(float c, float g) {
	float g2 = g * g;
	float d = 1.0 + g2 - 2.0 * g * c;
	return 3.0 / (8.0 * atmoPI) * (1.0 - g2) * (1.0 + c * c) / ((2.0 + g2) * d * sqrt(d));
}

// ---- Geometry -------------------------------------------------------------------------
// Distance to a sphere of radius R centred on the planet from ro (planet centred), -1 if missed
float AtmoRaySphere(vec3 ro, vec3 rd, float R) {
	float r = length(ro);
	float b = dot(ro, rd);
	float c = (r - R) * (r + R);   // stable close to the surface
	float disc = b * b - c;
	if (disc < 0.0) return -1.0;
	float s = sqrt(disc);
	float t0 = -b - s, t1 = -b + s;
	if (t0 >= 0.0) return t0;
	if (t1 >= 0.0) return t1;
	return -1.0;
}

// Distance from the camera to the planet centre (km)
float AtmoCameraRadius() {
	return atmoRg + max((cameraPosition.y - atmoGroundY) * atmoKmPerBlock, 0.002);
}

// ---- LUT parametrisations -------------------------------------------------------------
vec2 AtmoTransmittanceUv(float r, float mu) {
	float H = sqrt(atmoRt * atmoRt - atmoRg * atmoRg);
	float rho = sqrt(max(0.0, r * r - atmoRg * atmoRg));
	float disc = r * r * (mu * mu - 1.0) + atmoRt * atmoRt;
	float d = max(0.0, -r * mu + sqrt(max(disc, 0.0)));
	float dMin = atmoRt - r, dMax = rho + H;
	vec2 uv = vec2((d - dMin) / (dMax - dMin), rho / H);
	return (uv * (atmoTransmittanceSize - 1.0) + 0.5) / atmoTransmittanceSize;
}

void AtmoTransmittanceParams(vec2 uv, out float r, out float mu) {
	uv = (uv * atmoTransmittanceSize - 0.5) / (atmoTransmittanceSize - 1.0);
	float H = sqrt(atmoRt * atmoRt - atmoRg * atmoRg);
	float rho = H * uv.y;
	r = sqrt(rho * rho + atmoRg * atmoRg);
	float dMin = atmoRt - r, dMax = rho + H;
	float d = dMin + uv.x * (dMax - dMin);
	mu = d == 0.0 ? 1.0 : (H * H - rho * rho - d * d) / (2.0 * r * d);
	mu = clamp(mu, -1.0, 1.0);
}

vec2 AtmoMultiScatUv(float r, float mu) {
	vec2 uv = vec2(mu * 0.5 + 0.5, clamp((r - atmoRg) / (atmoRt - atmoRg), 0.0, 1.0));
	return (uv * (atmoMultiScatSize - 1.0) + 0.5) / atmoMultiScatSize;
}

// Sky-view LUT: more resolution near the horizon and toward the sun (Hillaire 2020)
vec2 AtmoSkyViewUv(bool groundHit, float viewZenithCos, float lightViewCos, float r) {
	float vHorizon = sqrt(max(r * r - atmoRg * atmoRg, 0.0));
	float beta = acos(clamp(vHorizon / r, -1.0, 1.0));
	float zenithHorizonAngle = atmoPI - beta;
	float vza = acos(clamp(viewZenithCos, -1.0, 1.0));
	vec2 uv;
	if (!groundHit) {
		float c = clamp(vza / zenithHorizonAngle, 0.0, 1.0);
		uv.y = (1.0 - sqrt(1.0 - c)) * 0.5;
	} else {
		float c = clamp((vza - zenithHorizonAngle) / beta, 0.0, 1.0);
		uv.y = sqrt(c) * 0.5 + 0.5;
	}
	uv.x = sqrt(clamp(-lightViewCos * 0.5 + 0.5, 0.0, 1.0));
	return (uv * (atmoSkyViewSize - 1.0) + 0.5) / atmoSkyViewSize;
}

void AtmoSkyViewParams(vec2 uv, float r, out float viewZenithCos, out float lightViewCos) {
	uv = (uv * atmoSkyViewSize - 0.5) / (atmoSkyViewSize - 1.0);
	float vHorizon = sqrt(max(r * r - atmoRg * atmoRg, 0.0));
	float beta = acos(clamp(vHorizon / r, -1.0, 1.0));
	float zenithHorizonAngle = atmoPI - beta;
	float vza;
	if (uv.y < 0.5) {
		float c = 1.0 - uv.y * 2.0;
		vza = zenithHorizonAngle * (1.0 - c * c);
	} else {
		float c = uv.y * 2.0 - 1.0;
		vza = zenithHorizonAngle + beta * c * c;
	}
	viewZenithCos = cos(vza);
	float c = uv.x * uv.x;
	lightViewCos = -(c * 2.0 - 1.0);
}

// ---- Lookups ----------------------------------------------------------------------------
#ifdef ATMOSPHERE_LUTS
uniform sampler2D atmoTransmittanceSampler;
uniform sampler2D atmoMultiScatSampler;
uniform sampler2D atmoSkyViewSampler;

// Transmittance from radius r toward the top of the atmosphere (mu: cosine to the zenith)
vec3 AtmoTransmittance(float r, float mu) {
	return textureLod(atmoTransmittanceSampler, AtmoTransmittanceUv(r, mu), 0.0).rgb;
}

vec3 AtmoMultiScat(float r, float mu) {
	return textureLod(atmoMultiScatSampler, AtmoMultiScatUv(r, mu), 0.0).rgb;
}

// Light from L reaching a point (planet centred): transmittance and the planet's shadow
vec3 AtmoLightAt(vec3 P, float r, vec3 L) {
	float mu = dot(P, L) / r;
	// below the local horizon of the planet: shadowed (smoothed over ~0.3 degree)
	float horizonCos = -sqrt(max(1.0 - (atmoRg / r) * (atmoRg / r), 0.0));
	float vis = clamp((mu - horizonCos) * 200.0 + 0.5, 0.0, 1.0);
	return AtmoTransmittance(r, mu) * vis;
}

// In-scattered luminance (sun illuminance 1, single + multiple scattering) and transmittance
// along a ray from ro (planet centred) over tMax km, lit from L.
vec3 AtmoIntegrate(vec3 ro, vec3 rd, float tMax, vec3 L, int steps, float offset, float mieScale, out vec3 T) {
	float c = dot(rd, L);
	float phaseR = AtmoPhaseRayleigh(c), phaseM = AtmoPhaseMie(c, atmoMieG);
	vec3 lum = vec3(0.0);
	T = vec3(1.0);
	for (int i = 0; i < steps; i++) {
		// quadratic distribution: short steps near the camera (dense air, close terrain)
		float t0 = float(i) / float(steps), t1 = float(i + 1) / float(steps);
		t0 *= t0 * tMax; t1 *= t1 * tMax;
		float dt = t1 - t0;
		vec3 P = ro + rd * mix(t0, t1, offset);
		float r = length(P);
		AtmoMedium m = AtmoSampleMedium(r - atmoRg, mieScale);
		float mu = dot(P, L) / r;
		vec3 S = AtmoLightAt(P, r, L) * (m.scatR * phaseR + m.scatM * phaseM)
		       + AtmoMultiScat(r, mu) * (m.scatR + m.scatM);
		vec3 sampleT = exp(-m.ext * dt);
		lum += T * (S - S * sampleT) / max(m.ext, vec3(1e-7));
		T *= sampleT;
	}
	return lum;
}

// Aerial perspective between the camera and a point dist blocks away in direction dir.
// Returns the in-scattered radiance (pack sky units), T: transmittance.
// sunVec: sun direction, moonLight: weight of the moon (the pack's nightBrightness).
vec3 AtmoAerialPerspective(vec3 dir, float dist, vec3 sunVec, float moonLight, int steps, out vec3 T) {
	vec3 ro = vec3(0.0, AtmoCameraRadius(), 0.0);
	float t = dist * atmoKmPerBlock;
	float tTop = AtmoRaySphere(ro, dir, atmoRt);
	if (tTop > 0.0) t = min(t, tTop);
	T = vec3(1.0);
	if (t <= 1e-4) return vec3(0.0);
	steps = clamp(int(3.0 + t * 2.0), 3, steps);   // fewer steps for close points
	float mieScale = AtmoMieDensityScale();
	vec3 lum = AtmoIntegrate(ro, dir, t, sunVec, steps, 0.5, mieScale, T);
	if (moonLight > 0.0 && sunVec.y < 0.15) {
		vec3 Tm;
		lum += AtmoIntegrate(ro, dir, t, -sunVec, steps, 0.5, mieScale, Tm) * moonLight;
	}
	return lum * atmoSunColor * atmoUnit;
}

// Sky radiance seen from the camera (pack sky units), from the sky-view LUT
vec3 AtmoSkyRadiance(vec3 dir, vec3 sunVec, float moonLight) {
	float r = AtmoCameraRadius();
	bool groundHit = AtmoRaySphere(vec3(0.0, r, 0.0), dir, atmoRg) > 0.0;
	float hl = length(sunVec.xz), dl = length(dir.xz);
	float lightViewCos = (hl > 1e-5 && dl > 1e-5) ? dot(sunVec.xz, dir.xz) / (hl * dl) : 1.0;
	vec2 uv = AtmoSkyViewUv(groundHit, dir.y, lightViewCos, r);
	vec3 lum = textureLod(atmoSkyViewSampler, vec2(uv.x, uv.y * 0.5), 0.0).rgb;
	if (moonLight > 0.0) {
		vec2 uvm = AtmoSkyViewUv(groundHit, dir.y, -lightViewCos, r);
		lum += textureLod(atmoSkyViewSampler, vec2(uvm.x, 0.5 + uvm.y * 0.5), 0.0).rgb * moonLight;
	}
	return lum * atmoSunColor * atmoUnit;
}

// Transmittance from the camera to space (sun disc, stars); 0 toward the ground
vec3 AtmoViewTransmittance(vec3 dir) {
	float r = AtmoCameraRadius();
	if (AtmoRaySphere(vec3(0.0, r, 0.0), dir, atmoRg) > 0.0) return vec3(0.0);
	return AtmoTransmittance(r, dir.y);
}

// Colour of the sunlight (above the atmosphere = the pack's sun colour) at a point dist blocks
// away from the camera in direction dir. For the clouds.
vec3 AtmoSunColorAt(vec3 dir, float dist, vec3 sunVec) {
	vec3 P = vec3(0.0, AtmoCameraRadius(), 0.0) + dir * (dist * atmoKmPerBlock);
	return AtmoLightAt(P, length(P), sunVec) * atmoSunColor;
}
#endif

#endif
