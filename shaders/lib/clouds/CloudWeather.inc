// =====================================================================================
//  Volumetric clouds - weather map
//
//  The cloud field is described by a 2D "weather map" centred on the camera:
//    layer 0 : x = footprint (0 outside a cloud, 1 at the centre of a cloud)
//              y = base altitude offset from CLOUD_ALTITUDE (scaled km)
//              z = thickness (scaled km)
//              w = cloud type: -1 = layered cloud (stratocumulus, stratus), 0..1 = cumulus from
//                  flat (humilis) to towering (congestus)
//    layer 1 : x = lower bound of the horizontal distance to the nearest cloud (scaled km)
//              y = radius of the cloud (body of a cumulonimbus), scaled km
//              z = highest cloud top within cloudSkipRadius (scaled km relative to CLOUD_ALTITUDE),
//                  lets the ray march skip the empty space above the clouds
//              w = mid level layer field (> 0 inside altocumulus / altostratus patches, its
//                  negative part is a distance: -w / cloudMidGrad km to the closest patch)
//  Cumulonimbus: type > 1 encodes the anvil. The footprint covers the anvil, the body is the
//  inner part of radius k = 2 - type (in footprint units).
//  Clouds are individual "cells" placed on three jittered grids (9, 3.5, 1.4 km), each
//  with its own size, base, thickness and type, plus a layered (stratiform) component.
//  Large scale fields (coverage, convection, base altitude) vary slowly in space and time.
//
//  Needs: cameraPosition, wetness, rainStrength, thunderStrength, worldTime, worldDay,
//         frameTimeCounter, sampler2D cloudCurl.
// =====================================================================================

#ifndef CLOUD_WEATHER_INC
#define CLOUD_WEATHER_INC

struct CloudWeather {
	float cov;    // footprint
	float base;   // km (scaled) relative to CLOUD_ALTITUDE
	float thick;  // km (scaled)
	float type;   // -1 layered cloud, 0..1 cumulus (flat .. towering), > 1 cumulonimbus with anvil
	float dist;   // km (scaled), lower bound of the distance to the closest cloud
	float size;   // km (scaled), radius of the cloud (body of a cumulonimbus)
	float maxTop; // km (scaled) relative to CLOUD_ALTITUDE, highest top within skipR
	float skipR;  // km (scaled), horizontal radius over which maxTop is valid after filtering
	float mid;    // mid layer field (> 0 inside a patch)
	float midDist;// km (scaled), lower bound of the distance to the closest mid layer patch
};

// ---- Sky regimes ------------------------------------------------------------------------
// Kind of sky of the day: offsets of the low cloud coverage / convection, amount of layered
// low clouds, mid and high layers. Days blend into each other in the afternoon / evening.
struct CloudSkyRegime {
	float cov;      // low cloud coverage offset
	float conv;     // convection offset
	float strat;    // layered low clouds (1 = default amount)
	float mid;      // coverage of the mid level layer
	float midType;  // 0 altocumulus .. 1 altostratus
	float high;     // coverage of the high layer
	float highType; // 0 fibrous cirrus .. 0.5 cirrocumulus .. 1 cirrostratus veil
	float cb;       // probability for big convective cells to be cumulonimbus
};

// (cov, conv, strat, mid) and (midType, high, highType, cb). Index 0 = manual.
const vec4 cloudRegimeA[9] = vec4[9](
	vec4( 0.00,  0.00, 0.5, 0.30),   // manual
	vec4(-0.45, -0.10, 0.0, 0.00),   // clear
	vec4(-0.05,  0.00, 0.3, 0.08),   // fair weather cumulus
	vec4(-0.12,  0.00, 0.3, 0.60),   // cumulus and altocumulus
	vec4(-0.35, -0.10, 0.0, 0.10),   // cirrus
	vec4( 0.00,  0.35, 0.2, 0.15),   // towering cumulus
	vec4( 0.30, -0.40, 1.0, 0.00),   // stratocumulus
	vec4(-0.30, -0.25, 0.3, 0.75),   // warm front
	vec4( 0.00,  0.00, 0.5, 0.40));  // mixed
const vec4 cloudRegimeB[9] = vec4[9](
	vec4(0.30, 0.35, 0.3, 0.0),
	vec4(0.00, 0.08, 0.0, 0.0),
	vec4(0.00, 0.25, 0.0, 0.0),
	vec4(0.15, 0.30, 0.4, 0.0),
	vec4(0.00, 0.85, 0.1, 0.0),
	vec4(0.20, 0.35, 0.0, 0.2),
	vec4(0.00, 0.10, 0.0, 0.0),
	vec4(0.85, 0.85, 0.9, 0.0),
	vec4(0.40, 0.55, 0.5, 0.0));

int CloudPickRegime(int day) {
	// weights: clear 1, fair cumulus 3, cumulus + altocumulus 2, cirrus 1, towering 1.5,
	// stratocumulus 1, warm front 1, mixed 2
	float x = CloudHash(ivec2(day, 1499), 977).x * 12.5;
	if (x < 1.0)  return 1;
	if (x < 4.0)  return 2;
	if (x < 6.0)  return 3;
	if (x < 7.0)  return 4;
	if (x < 8.5)  return 5;
	if (x < 9.5)  return 6;
	if (x < 10.5) return 7;
	return 8;
}

CloudSkyRegime CloudGetSkyRegime() {
	#if CLOUD_REGIME == 0
		#if CLOUD_TIME_SOURCE == 0
			float day = float(worldDay % 100000) + float(worldTime) / 24000.0 + 0.25;   // days start at midnight
		#else
			float day = frameTimeCounter / 1200.0;
		#endif
		float d0 = floor(day);
		float f = smoothstep(0.55, 1.0, day - d0);   // the next day's sky builds up from early afternoon
		int ia = CloudPickRegime(int(d0)), ib = CloudPickRegime(int(d0) + 1);
		vec4 A = mix(cloudRegimeA[ia], cloudRegimeA[ib], f);
		vec4 B = mix(cloudRegimeB[ia], cloudRegimeB[ib], f);
		A.xy *= CLOUD_WEATHER_VARIATION;
	#else
		vec4 A = cloudRegimeA[CLOUD_REGIME - 1];
		vec4 B = cloudRegimeB[CLOUD_REGIME - 1];
	#endif

	CloudSkyRegime R;
	float storm = thunderStrength;
	R.cov = A.x;
	R.conv = A.y;
	R.strat = A.z * 2.0 * (1.0 - 0.6 * storm);
	// rain: grey altostratus / nimbostratus deck; thunderstorms: broken skies with cumulonimbus
	R.mid = mix(A.w, 1.1, wetness * (1.0 - 0.6 * storm)) * (float(CLOUD_MID_LAYER) / 100.0);
	R.midType = mix(B.x, 1.0, wetness);
	R.high = B.y * (1.0 - 0.5 * wetness) * (float(CLOUD_HIGH_LAYER) / 100.0);
	R.highType = B.z;
	#ifdef CLOUD_STORMS
		R.cb = max(B.w, storm);
	#else
		R.cb = 0.0;
	#endif
	return R;
}

// Horizontal radius over which layer1.z (max cloud top) is computed. Must stay below
// 0.48 * the smallest cell size so cells outside the searched neighbourhood cannot matter.
const float cloudSkipRadius = 0.6;  // scaled km

// ---- Map placement --------------------------------------------------------------------
// Fractional part of the camera position inside a weather texel (precise even far from 0,0)
vec2 CloudWeatherCamOffset(float texel) {
	return cameraPosition.xz - floor(cameraPosition.xz / texel) * texel;
}

// World XZ (wind relative) at the centre of texel "id" of a cascade
vec2 CloudWeatherTexelWorld(ivec2 id, float texel, float size) {
	vec2 origin = floor(cameraPosition.xz / texel) * texel;
	return origin + (vec2(id) + 0.5 - size * 0.5) * texel;
}

// ---- Generation ------------------------------------------------------------------------
vec4 CloudCurlTex(vec2 uv) {
	return textureLod(cloudCurl, uv, 0.0);
}

// Large scale regime at wind relative position q: x = coverage, y = convection,
// z = base altitude offset (km). Very low frequency, evaluated once per cloud cell.
vec3 CloudRegime(vec2 q, float time, CloudSkyRegime R) {
	float evo = time * (0.00002 + 0.00002 * CLOUD_EVOLUTION);
	float v = CLOUD_WEATHER_VARIATION;

	float covField  = CloudCurlTex(q / (150.0 * cloudKm) + vec2(0.13, 0.71) + vec2(0.8, 0.5) * evo).a;
	float convField = CloudCurlTex(q / (190.0 * cloudKm) + vec2(0.57, 0.29) - vec2(0.4, 0.9) * evo).a;
	float lclField  = CloudCurlTex(q / (90.0 * cloudKm) + vec2(0.91, 0.43)).b;

	float cov = CLOUD_COVERAGE + R.cov + (covField - 0.5) * 0.9 * v;
	cov += wetness * 0.45 + thunderStrength * 0.2;

	float conv = CLOUD_CONVECTION + R.conv + (convField - 0.5) * 0.8 * v;
	conv += thunderStrength * 0.5 - wetness * 0.25;

	float base = (lclField - 0.5) * 0.35 * v;

	return vec3(cov, CloudSat(conv), base);
}

// Regime + clustering, packed for the regime map (x = coverage, y = convection,
// z = base offset, w = cluster factor)
vec4 CloudRegimeFull(vec2 q, float time, CloudSkyRegime R) {
	float cluster = CloudCurlTex(q / (9.0 * cloudKm) + vec2(0.23, 0.67)).b * 2.0 - 0.4;
	return vec4(CloudRegime(q, time, R), cluster);
}

// The regime map (begin.csh) stores CloudRegimeFull on a coarse grid in wind relative
// space, so each cloud cell costs one texture fetch instead of four.
const float cloudRegimeTexel = 900.0 * CLOUD_SCALE;
const float cloudRegimeSize  = 512.0;

vec2 CloudRegimeOrigin(float time) {
	vec2 qc = cameraPosition.xz - CloudWindOffset(time);
	return floor(qc / cloudRegimeTexel) * cloudRegimeTexel;
}

#ifdef CLOUD_REGIME_MAP
vec4 CloudRegimeLookup(vec2 q, vec2 origin) {
	vec2 uv = (q - origin) / (cloudRegimeTexel * cloudRegimeSize) + 0.5;
	return textureLod(cloudRegimeSampler, uv, 0.0);
}
#endif

// Noise driving the layered (stratiform) clouds
float CloudStratNoise(vec2 q, float time) {
	float evo = time * (0.00002 + 0.00002 * CLOUD_EVOLUTION);
	return CloudCurlTex(q / (11.0 * cloudKm) + vec2(0.37, 0.11) + evo * 6.0).b * 0.7
	     + CloudCurlTex(q / (37.0 * cloudKm) + vec2(0.81, 0.62)).a * 0.3;
}

// Domain warp of the footprints: xy = 3.2 km component, zw = 0.9 km component (each in [-1, 1])
vec4 CloudFootprintWarp(vec2 q) {
	return vec4(CloudCurlTex(q / (3.2 * cloudKm)).rg, CloudCurlTex(q / (0.9 * cloudKm) + 0.5).rg) * 2.0 - 1.0;
}

// One octave of cloud cells.
//   F    : union of the footprints
//   acc  : weighted sum of (base, thick, type, density)
//   dist : lower bound of the distance to the closest footprint (blocks)
void CloudCells(vec2 q, vec4 warp, float L, int octave, float time, vec2 regimeOrigin, CloudSkyRegime R,
                inout float F, inout vec4 acc, inout float wsum, inout float dist, inout float maxTop,
                inout float cbF, inout vec4 cbP)
{
	vec2 wind = CloudWindDir();
	ivec2 ci = ivec2(floor(q / L));
	// cells outside the 3x3 neighbourhood are at least 1.25 L - (radius incl. warp and elongation
	// margin 1.45) away: radius <= 0.52 L -> 0.48 L, cumulonimbus anvils (<= 0.6 L) -> 0.38 L
	dist = min(dist, (octave == 0 && R.cb > 0.0 ? 0.37 : 0.48) * L);

	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		ivec2 c = ci + ivec2(x, y);
		vec4 r = CloudHash(c, octave * 3 + 1);
		vec2 center = (vec2(c) + 0.5 + (r.xy - 0.5) * 0.5) * L;
		#ifdef CLOUD_REGIME_MAP
			vec4 reg = CloudRegimeLookup(center, regimeOrigin);
		#else
			vec4 reg = CloudRegimeFull(center, time, R);
		#endif
		float cov = reg.x, conv = reg.y, cluster = reg.w;

		float occ;
		// clusters: cloud cells group together, leaving clear gaps between groups
		if (octave == 0)      occ = CloudSat((cov - 0.22) * 1.5) * mix(0.55, 1.0, conv);
		else if (octave == 1) occ = CloudSat((cov - 0.08) * 1.35) * cluster;
		else                  occ = CloudSat(cov * 1.6 + 0.05) * (1.0 - 0.6 * CloudSat((cov - 0.65) * 2.5)) * cluster;
		if (r.z >= occ) continue;

		vec4 r2 = CloudHash(c, octave * 3 + 2);
		// many small, few large (power law like real cumulus fields)
		float rad = L * mix(0.15, 0.45, pow(r.w, 1.5)) * mix(0.85, 1.15, CloudSat(cov));
		// cells grow / shrink instead of popping when the coverage changes
		rad *= sqrt(CloudSat((occ - r.z) * 8.0));

		// Cumulonimbus: big convective cells of thunderstorms. They grow into a tall column
		// (cb = 0..1) topped by an anvil spreading at the tropopause.
		float cb = 0.0;
		vec4 r3 = vec4(0.0);
		if (octave == 0 && R.cb > 0.0) {
			r3 = CloudHash(c, 100);
			float chance = R.cb * 0.55 * CloudSat(conv * 1.6 - 0.2);
			cb = CloudSat((chance - r3.x) * 6.0);
		}
		float bodyRad = mix(rad, L * mix(0.19, 0.25, r3.y), cb);
		float outerRad = mix(bodyRad, min(bodyRad * mix(2.2, 2.8, r3.z), 0.6 * L), cb);
		rad = bodyRad;

		// Warped footprint. Each component moves points by less than its wavelength / 2 pi,
		// else big clouds would fold into torn, star shaped footprints. (<= 0.35 rad in total,
		// covered by the 1.45 margin of the distance bound)
		vec2 d = q + warp.xy * min(0.21 * rad, 0.45 * cloudKm) + warp.zw * min(0.14 * rad, 0.12 * cloudKm) - center;
		// slight elongation along the wind
		float along = dot(d, wind);
		vec2 perp = d - along * wind;
		float stretch = mix(1.0, 1.4, r2.z * r2.z);
		float len = length(perp + along * wind / stretch);

		float edgeDist = len - outerRad * 1.45;
		dist = min(dist, edgeDist);

		float type   = CloudSat(conv + (r2.x - 0.5) * 0.45);
		float aspect = mix(0.75, 1.15, r2.y) * mix(1.0, 2.6, type);
		// the depth of the convective layer bounds the thickness: wide clouds of weak convection
		// are flat (stratocumulus like), only strong convection builds deep towers
		float thick  = min(rad / cloudKm * aspect, mix(0.9, cloudMaxThick, type * type));
		thick = mix(thick, cloudCbMaxThick * mix(0.82, 1.0, r3.w), cb);
		// type > 1: anvil, body radius k = 2 - type in footprint units
		type = cb > 0.0 ? 2.0 - bodyRad / outerRad : type;
		float base   = reg.z + (r2.w - 0.5) * 0.12 - 0.05 * thick;
		float size   = bodyRad / cloudKm;

		if (edgeDist < cloudSkipRadius * cloudKm) maxTop = max(maxTop, base + thick * 1.15);  // 1.15 = cloudTurretMax

		float qn = len / outerRad;
		if (qn > 1.6) continue;
		float f = 1.0 - qn;

		if (cb > 0.0) {
			// cumulonimbus: kept apart, its parameters must not be averaged with other clouds
			// (a half-anvil type would turn the whole footprint into a tall column)
			if (f > cbF) {
				cbF = f;
				cbP = vec4(base, thick, type, size);
			}
			continue;
		}
		float w = f > 0.0 ? f * f + 1e-3 : 1e-4 * (1.6 - qn);
		acc  += w * vec4(base, thick, type, size);
		wsum += w;
		if (f > 0.0) F = 1.0 - (1.0 - F) * (1.0 - f);
	}
}

// Mid level layer: patches of altocumulus / altostratus, carried by a faster wind.
// Upper bound of the gradient of the field (per scaled km): 0.75 * 10 / 31 + 0.25 * 40 / 8.5
const float cloudMidGrad = 1.5;

float CloudMidField(vec2 q, float time, CloudSkyRegime R) {
	if (R.mid <= 0.0) return -1.0;
	vec2 qm = q - CloudWindOffset(time) * (cloudMidWind - 1.0);
	float evo = time * (0.00002 + 0.00002 * CLOUD_EVOLUTION);
	float n = CloudCurlTex(qm / (31.0 * cloudKm) + vec2(0.61, 0.17) + vec2(-0.5, 0.7) * evo).a * 0.75
	        + CloudCurlTex(qm / (8.5 * cloudKm) + vec2(0.29, 0.83) + vec2(0.3, 0.2) * evo).b * 0.25;
	// threshold so that the covered fraction is about R.mid
	return n - (0.44 - 0.47 * (R.mid - 0.5));
}

// Full weather at wind relative position q.  out0 = layer 0, out1 = layer 1.
void CloudGenerateWeather(vec2 q, float time, bool far, out vec4 out0, out vec4 out1) {
	CloudSkyRegime R = CloudGetSkyRegime();
	vec4 warp = CloudFootprintWarp(q);
	float F = 0.0, wsum = 0.0;
	vec4 acc = vec4(0.0);
	float dist = 1e9;
	float maxTop = -1.0;
	float cbF = 0.0;
	vec4 cbP = vec4(0.0);

	vec2 regimeOrigin = CloudRegimeOrigin(time);
	CloudCells(q, warp, 9.0 * cloudKm, 0, time, regimeOrigin, R, F, acc, wsum, dist, maxTop, cbF, cbP);
	CloudCells(q, warp, 3.5 * cloudKm, 1, time, regimeOrigin, R, F, acc, wsum, dist, maxTop, cbF, cbP);
	CloudCells(q, warp, 1.4 * cloudKm, 2, time, regimeOrigin, R, F, acc, wsum, dist, maxTop, cbF, cbP);

	// Layered clouds (stratocumulus / stratus), favoured by low convection and rain
	#ifdef CLOUD_REGIME_MAP
		vec4 reg = CloudRegimeLookup(q, regimeOrigin);
	#else
		vec4 reg = CloudRegimeFull(q, time, R);
	#endif
	float sn = CloudStratNoise(q, time);
	float covS = (reg.x - 0.2) * (1.0 - 0.85 * reg.y) * 1.7 * R.strat + wetness * 0.9 * (1.0 - 0.5 * thunderStrength);
	float fs = CloudSat((sn - (1.0 - covS)) * 4.0);
	float thickS = mix(0.25, 0.75, CloudSat(sn * 1.5 - 0.3)) + wetness * 0.9;
	if (covS > 0.0) {
		float gap = (1.0 - covS) - sn;
		dist = min(dist, max(gap, 0.0) * 0.9 * cloudKm);
		maxTop = max(maxTop, reg.z + 0.12 + thickS);
	}
	if (fs > 0.0) {
		float w = fs * fs + 1e-3;
		acc  += w * vec4(reg.z + 0.12, thickS, -1.0, 1.0);   // type -1: layered cloud
		wsum += w;
		F = 1.0 - (1.0 - F) * (1.0 - fs);
	}

	vec4 p = wsum > 0.0 ? acc / wsum : vec4(reg.z, 0.0, reg.y, 1.0);
	// Inside the footprint of a cumulonimbus (anvil included), only the cumulonimbus exists
	if (cbF > 0.0) {
		F = cbF;
		p = cbP;
		dist = 0.0;
	}
	dist = F > 0.0 ? 0.0 : max(dist, 0.0);

	out0 = vec4(F, p.x, p.y, p.z);
	out1 = vec4(dist / cloudKm, p.w, maxTop + 0.05, CloudMidField(q, time, R));
}

// ---- Sampling -----------------------------------------------------------------------
#ifdef CLOUD_WEATHER_SAMPLING
CloudWeather CloudUnpackWeather(vec4 a, vec4 b) {
	CloudWeather w;
	w.cov = a.x; w.base = a.y; w.thick = a.z; w.type = a.w;
	w.dist = b.x; w.size = b.y; w.maxTop = b.z;
	w.mid = b.w;
	return w;
}

// Bilinear filtering of a distance field / max field is only conservative up to ~1.41 texel
CloudWeather CloudFilterMargin(CloudWeather w, float texelKm) {
	w.dist = max(w.dist - 1.42 * texelKm, 0.0);
	w.skipR = max(cloudSkipRadius - 0.72 * texelKm, 0.0);
	w.midDist = max(-w.mid / cloudMidGrad - 1.42 * texelKm, 0.0);
	return w;
}

CloudWeather CloudMixWeather(CloudWeather a, CloudWeather b, float t) {
	CloudWeather w;
	w.cov = mix(a.cov, b.cov, t); w.base = mix(a.base, b.base, t); w.thick = mix(a.thick, b.thick, t);
	w.type = mix(a.type, b.type, t); w.dist = min(a.dist, b.dist); w.size = mix(a.size, b.size, t);
	w.maxTop = max(a.maxTop, b.maxTop); w.skipR = min(a.skipR, b.skipR);
	w.mid = mix(a.mid, b.mid, t); w.midDist = min(a.midDist, b.midDist);
	return w;
}

// p : camera relative position
CloudWeather CloudSampleWeather(vec2 pxz) {
	vec2 uvN = (CloudWeatherCamOffset(cloudWeatherNearTexel) + pxz) / (cloudWeatherNearTexel * cloudWeatherNearSize) + 0.5;
	vec2 dN = abs(uvN - 0.5);
	float edge = max(dN.x, dN.y);

	CloudWeather near, far;
	if (edge < 0.47) {
		near = CloudFilterMargin(CloudUnpackWeather(textureLod(cloudWeatherNearSampler, vec3(uvN, 0.25), 0.0),
		                                            textureLod(cloudWeatherNearSampler, vec3(uvN, 0.75), 0.0)),
		                         cloudWeatherNearTexel / cloudKm);
		if (edge < 0.42) return near;
	}
	vec2 uvF = (CloudWeatherCamOffset(cloudWeatherFarTexel) + pxz) / (cloudWeatherFarTexel * cloudWeatherFarSize) + 0.5;
	far = CloudFilterMargin(CloudUnpackWeather(textureLod(cloudWeatherFarSampler, vec3(uvF, 0.25), 0.0),
	                                           textureLod(cloudWeatherFarSampler, vec3(uvF, 0.75), 0.0)),
	                        cloudWeatherFarTexel / cloudKm);
	if (edge >= 0.47) return far;
	return CloudMixWeather(near, far, CloudSat((edge - 0.42) / 0.05));
}
#endif

#endif
