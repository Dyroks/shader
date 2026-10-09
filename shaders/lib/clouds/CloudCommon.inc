// =====================================================================================
//  Volumetric clouds - shared constants and helpers
//
//  Units: 1 block = 1 metre. Everything geometric is multiplied by CLOUD_SCALE and the
//  extinction is divided by it, so the optical depth (hence the look) does not depend
//  on the scale. Positions are camera relative ("player space") unless stated.
//  This file must stay valid GLSL 330 (it is used by compute and fragment programs).
// =====================================================================================

#ifndef CLOUD_COMMON_INC
#define CLOUD_COMMON_INC

// ---- Quality presets ------------------------------------------------------------------
#if CLOUD_QUALITY == 0
	#define CQ_STEPS 40
	#define CQ_LIGHT_STEPS 3
	#define CQ_MS_OCTAVES 2
	#define CQ_DETAIL_DISTANCE 10.0
	#define CQ_STEP_SCALE 1.5
#elif CLOUD_QUALITY == 1
	#define CQ_STEPS 56
	#define CQ_LIGHT_STEPS 4
	#define CQ_MS_OCTAVES 2
	#define CQ_DETAIL_DISTANCE 18.0
	#define CQ_STEP_SCALE 1.2
#elif CLOUD_QUALITY == 2
	#define CQ_STEPS 72
	#define CQ_LIGHT_STEPS 5
	#define CQ_MS_OCTAVES 3
	#define CQ_DETAIL_DISTANCE 25.0
	#define CQ_STEP_SCALE 1.0
#elif CLOUD_QUALITY == 3
	#define CQ_STEPS 128
	#define CQ_LIGHT_STEPS 7
	#define CQ_MS_OCTAVES 3
	#define CQ_DETAIL_DISTANCE 40.0
	#define CQ_STEP_SCALE 0.7
#else
	#define CQ_STEPS CLOUD_STEPS
	#define CQ_LIGHT_STEPS CLOUD_LIGHT_STEPS
	#define CQ_MS_OCTAVES CLOUD_MS_OCTAVES
	#define CQ_DETAIL_DISTANCE float(CLOUD_DETAIL_DISTANCE)
	#define CQ_STEP_SCALE CLOUD_STEP_SCALE
#endif

// ---- Geometry -------------------------------------------------------------------------
const float cloudScale       = CLOUD_SCALE;
const float cloudKm          = 1000.0 * CLOUD_SCALE;           // one "scaled kilometre" in blocks
const float cloudPlanetR     = 6360000.0 * CLOUD_SCALE;        // planet radius, follows the scale so the horizon looks the same
const float cloudAltitude    = float(CLOUD_ALTITUDE);          // base of the low cloud layer (absolute Y)
const float cloudLayerBottom = float(CLOUD_ALTITUDE) - 0.45 * cloudKm;
const float cloudLayerTop    = float(CLOUD_ALTITUDE) + 6.5 * cloudKm;
const float cloudMaxThick    = 6.0;                            // km (scaled), max thickness of a single cloud
const float cloudMaxDistance = float(CLOUD_MAX_DISTANCE) * cloudKm;

// Extinction of the densest part of a cloud, per block. ~0.06/m is a mean free path of ~16 m,
// typical of cumulus. Divided by the scale so a smaller cloud keeps the same optical depth.
const float cloudSigmaT = 0.06 * CLOUD_DENSITY / CLOUD_SCALE;

// Noise tiling periods (blocks)
const float cloudBasePeriod   = 2000.0 * CLOUD_SCALE;  // 128^3 Perlin-Worley texture
const float cloudDetailPeriod = 640.0 * CLOUD_SCALE;   // 32^3 Worley texture
const float cloudCurlPeriod   = 2400.0 * CLOUD_SCALE;  // 128^2 curl texture (warp of detail / footprints)

// Weather maps: near cascade 2048^2 texels, far cascade 1024^2 texels (2 layers each)
const float cloudWeatherNearTexel = 48.0 * CLOUD_SCALE;
const float cloudWeatherFarTexel  = 400.0 * CLOUD_SCALE;
const float cloudWeatherNearSize  = 2048.0;
const float cloudWeatherFarSize   = 1024.0;

const float cloudPI = 3.14159265359;

// ---- Small helpers -------------------------------------------------------------------
float CloudSat(float x) { return clamp(x, 0.0, 1.0); }
vec2  CloudSat(vec2 x)  { return clamp(x, 0.0, 1.0); }
vec3  CloudSat(vec3 x)  { return clamp(x, 0.0, 1.0); }

float CloudRemap(float x, float a, float b, float c, float d) {
	return c + (x - a) / (b - a) * (d - c);
}

float CloudRemap01(float x, float a, float b) {
	return clamp((x - a) / (b - a), 0.0, 1.0);
}

uvec4 CloudPcg4d(uvec4 v) {
	v = v * 1664525u + 1013904223u;
	v.x += v.y * v.w; v.y += v.z * v.x; v.z += v.x * v.y; v.w += v.y * v.z;
	v ^= v >> 16u;
	v.x += v.y * v.w; v.y += v.z * v.x; v.z += v.x * v.y; v.w += v.y * v.z;
	return v;
}

vec4 CloudHash(ivec2 cell, int salt) {
	uvec4 h = CloudPcg4d(uvec4(uvec2(cell), uint(salt), uint(CLOUD_SEED) * 7919u + 17u));
	return vec4(h) * (1.0 / 4294967295.0);
}

// ---- Time & wind ----------------------------------------------------------------------
float CloudTime() {
	#if CLOUD_TIME_SOURCE == 0
		// Wraps every 64 days (~21h of play) to keep float precision.
		return float(worldDay % 64) * 1200.0 + float(worldTime) * 0.05;
	#else
		return frameTimeCounter;
	#endif
}

vec2 CloudWindDir() {
	const float a = float(CLOUD_WIND_ANGLE) * 0.01745329;
	return vec2(cos(a), sin(a));
}

// Horizontal displacement of the cloud field (blocks)
vec2 CloudWindOffset(float time) {
	return CloudWindDir() * (float(CLOUD_WIND_SPEED) * CLOUD_SCALE * time);
}

// Displacement of the 3D shape noises: slightly faster than the envelope plus a slow
// upward drift, so clouds evolve (billows rise and change) instead of sliding rigidly.
vec3 CloudBaseNoiseOffset(float time) {
	vec2 w = CloudWindOffset(time) * (1.0 + 0.12 * CLOUD_EVOLUTION);
	return vec3(w.x, 0.6 * CLOUD_SCALE * CLOUD_EVOLUTION * time, w.y);
}

vec3 CloudDetailNoiseOffset(float time) {
	vec2 w = CloudWindOffset(time) * (1.0 + 0.25 * CLOUD_EVOLUTION);
	return vec3(w.x, 2.0 * CLOUD_SCALE * CLOUD_EVOLUTION * time, w.y);
}

// ---- Planet geometry ------------------------------------------------------------------
// Altitude (absolute Y) of a camera relative point on a curved planet whose surface is
// tangent to the world plane right below the camera. Written to avoid float cancellation.
float CloudAltitude(vec3 p, float camY) {
	float y = camY + p.y;
	float Y = y + cloudPlanetR;
	float e = dot(p.xz, p.xz) / (Y * Y);
	return y + Y * e / (sqrt(1.0 + e) + 1.0);
}

// Intersections (t0 <= t1) of a ray from the camera with the sphere of altitude h.
// Returns false when missed.
bool CloudSphere(float dirY, float camY, float h, out float t0, out float t1) {
	float B = dirY * (cloudPlanetR + camY);
	float C = (camY - h) * (2.0 * cloudPlanetR + camY + h);
	float D = B * B - C;
	t0 = t1 = -1.0;
	if (D < 0.0) return false;
	float s = sqrt(D);
	float q = B > 0.0 ? -(B + s) : (-B + s);
	float r0 = q, r1 = C / q;
	t0 = min(r0, r1);
	t1 = max(r0, r1);
	return true;
}

// Segment of the ray inside the cloud layer shell. Returns false if empty.
bool CloudShellSegment(vec3 dir, float camY, float bottom, float top, out float tStart, out float tEnd) {
	float tb0, tb1, tt0, tt1;
	bool hitB = CloudSphere(dir.y, camY, bottom, tb0, tb1);
	bool hitT = CloudSphere(dir.y, camY, top, tt0, tt1);
	tStart = 0.0; tEnd = -1.0;
	if (camY > top) {
		if (!hitT || tt0 < 0.0) return false;
		tStart = tt0;
		tEnd = (hitB && tb0 > 0.0) ? tb0 : tt1;
	} else if (camY < bottom) {
		tStart = tb1;
		tEnd = tt1;
	} else {
		tStart = 0.0;
		tEnd = (hitB && tb0 > 0.0) ? tb0 : tt1;
	}
	return tEnd > tStart;
}

// ---- Phase functions ------------------------------------------------------------------
float CloudPhaseHG(float c, float g) {
	float g2 = g * g;
	float d = 1.0 + g2 - 2.0 * g * c;
	return (1.0 - g2) / (4.0 * cloudPI * d * sqrt(d));
}

// Draine phase function (used by Jendersie & d'Eon 2023 to approximate Mie scattering)
float CloudPhaseDraine(float c, float g, float a) {
	float g2 = g * g;
	float d = 1.0 + g2 - 2.0 * g * c;
	return ((1.0 - g2) * (1.0 + a * c * c)) / (4.0 * cloudPI * (1.0 + a * (1.0 + 2.0 * g2) / 3.0) * d * sqrt(d));
}

// Water droplet phase function: HG forward lobe + Draine lobe (Jendersie & d'Eon 2023,
// parameters for ~20 um droplets: gD = 0.594, alpha = 27.1, wD = 0.5). The HG lobe is
// widened (0.995 -> 0.8) because the real diffraction peak is far narrower than a pixel and
// far brighter than the sun disc this pack renders. "k" scales anisotropy for the
// multiple scattering octaves.
float CloudPhase(float c, float k) {
	return mix(CloudPhaseHG(c, 0.8 * k), CloudPhaseDraine(c, 0.594 * k, 27.1), 0.5);
}

#endif
