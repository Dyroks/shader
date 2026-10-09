// =====================================================================================
//  Volumetric clouds - weather map
//
//  The cloud field is described by a 2D "weather map" centred on the camera:
//    layer 0 : x = footprint (0 outside a cloud, 1 at the centre of a cloud)
//              y = base altitude offset from CLOUD_ALTITUDE (scaled km)
//              z = thickness (scaled km)
//              w = cloud type (0 = flat layered cloud, 1 = towering convective cloud)
//    layer 1 : x = lower bound of the horizontal distance to the nearest cloud (scaled km)
//              y = density multiplier of the cloud
//              z = highest cloud top within cloudSkipRadius (scaled km relative to CLOUD_ALTITUDE),
//                  lets the ray march skip the empty space above the clouds
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
	float type;   // 0 stratiform .. 1 convective
	float dist;   // km (scaled), lower bound of the distance to the closest cloud
	float dens;   // density multiplier
	float maxTop; // km (scaled) relative to CLOUD_ALTITUDE, highest top within skipR
	float skipR;  // km (scaled), horizontal radius over which maxTop is valid after filtering
};

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
vec3 CloudRegime(vec2 q, float time) {
	float evo = time * (0.00002 + 0.00002 * CLOUD_EVOLUTION);
	float v = CLOUD_WEATHER_VARIATION;

	float covField  = CloudCurlTex(q / (150.0 * cloudKm) + vec2(0.13, 0.71) + vec2(0.8, 0.5) * evo).a;
	float convField = CloudCurlTex(q / (190.0 * cloudKm) + vec2(0.57, 0.29) - vec2(0.4, 0.9) * evo).a;
	float lclField  = CloudCurlTex(q / (90.0 * cloudKm) + vec2(0.91, 0.43)).b;

	float cov = CLOUD_COVERAGE + (covField - 0.5) * 0.9 * v;
	cov += wetness * 0.45 + thunderStrength * 0.2;

	float conv = CLOUD_CONVECTION + (convField - 0.5) * 0.8 * v;
	conv += thunderStrength * 0.5 - wetness * 0.25;

	float base = (lclField - 0.5) * 0.35 * v;

	return vec3(cov, CloudSat(conv), base);
}

// Regime + clustering, packed for the regime map (x = coverage, y = convection,
// z = base offset, w = cluster factor)
vec4 CloudRegimeFull(vec2 q, float time) {
	float cluster = CloudCurlTex(q / (9.0 * cloudKm) + vec2(0.23, 0.67)).b * 2.0 - 0.4;
	return vec4(CloudRegime(q, time), cluster);
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

vec2 CloudFootprintWarp(vec2 q) {
	vec2 w = (CloudCurlTex(q / (3.2 * cloudKm)).rg - 0.5) * 2.0 * 0.6;
	w += (CloudCurlTex(q / (0.9 * cloudKm) + 0.5).rg - 0.5) * 2.0 * 0.4;
	return w;
}

// One octave of cloud cells.
//   F    : union of the footprints
//   acc  : weighted sum of (base, thick, type, density)
//   dist : lower bound of the distance to the closest footprint (blocks)
void CloudCells(vec2 q, vec2 warp, float L, int octave, float time, vec2 regimeOrigin,
                inout float F, inout vec4 acc, inout float wsum, inout float dist, inout float maxTop)
{
	vec2 wind = CloudWindDir();
	ivec2 ci = ivec2(floor(q / L));
	// cells outside the 3x3 neighbourhood are at least ~0.48 L away (centre jitter <= 0.25 L,
	// radius <= 0.52 L, warp and elongation margin 1.45)
	dist = min(dist, 0.48 * L);

	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		ivec2 c = ci + ivec2(x, y);
		vec4 r = CloudHash(c, octave * 3 + 1);
		vec2 center = (vec2(c) + 0.5 + (r.xy - 0.5) * 0.5) * L;
		#ifdef CLOUD_REGIME_MAP
			vec4 reg = CloudRegimeLookup(center, regimeOrigin);
		#else
			vec4 reg = CloudRegimeFull(center, time);
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

		// slight elongation along the wind
		vec2 d = q + warp * (0.35 * rad) - center;
		float along = dot(d, wind);
		vec2 perp = d - along * wind;
		float stretch = mix(1.0, 1.4, r2.z * r2.z);
		float len = length(perp + along * wind / stretch);

		float edgeDist = len - rad * 1.45;
		dist = min(dist, edgeDist);

		float type   = CloudSat(conv + (r2.x - 0.5) * 0.45);
		float aspect = mix(0.55, 1.15, r2.y) * mix(0.55, 2.4, type);
		float thick  = min(rad / cloudKm * aspect, cloudMaxThick);
		float base   = reg.z + (r2.w - 0.5) * 0.12 - 0.05 * thick;
		float dens   = mix(0.8, 1.2, fract(r2.x * 7.31 + r2.w));

		if (edgeDist < cloudSkipRadius * cloudKm) maxTop = max(maxTop, base + thick);

		float qn = len / rad;
		if (qn > 1.6) continue;
		float f = 1.0 - qn;

		float w = f > 0.0 ? f * f + 1e-3 : 1e-4 * (1.6 - qn);
		acc  += w * vec4(base, thick, type, dens);
		wsum += w;
		if (f > 0.0) F = 1.0 - (1.0 - F) * (1.0 - f);
	}
}

// Full weather at wind relative position q.  out0 = layer 0, out1 = layer 1.
void CloudGenerateWeather(vec2 q, float time, bool far, out vec4 out0, out vec4 out1) {
	vec2 warp = CloudFootprintWarp(q);
	float F = 0.0, wsum = 0.0;
	vec4 acc = vec4(0.0);
	float dist = 1e9;
	float maxTop = -1.0;

	vec2 regimeOrigin = CloudRegimeOrigin(time);
	CloudCells(q, warp, 9.0 * cloudKm, 0, time, regimeOrigin, F, acc, wsum, dist, maxTop);
	CloudCells(q, warp, 3.5 * cloudKm, 1, time, regimeOrigin, F, acc, wsum, dist, maxTop);
	CloudCells(q, warp, 1.4 * cloudKm, 2, time, regimeOrigin, F, acc, wsum, dist, maxTop);

	// Layered clouds (stratocumulus / stratus), favoured by low convection and rain
	#ifdef CLOUD_REGIME_MAP
		vec4 reg = CloudRegimeLookup(q, regimeOrigin);
	#else
		vec4 reg = CloudRegimeFull(q, time);
	#endif
	float sn = CloudStratNoise(q, time);
	float covS = (reg.x - 0.2) * (1.0 - 0.85 * reg.y) * 1.7 + wetness * 0.9;
	float fs = CloudSat((sn - (1.0 - covS)) * 4.0);
	float thickS = mix(0.25, 0.75, CloudSat(sn * 1.5 - 0.3)) + wetness * 0.9;
	if (covS > 0.0) {
		float gap = (1.0 - covS) - sn;
		dist = min(dist, max(gap, 0.0) * 0.9 * cloudKm);
		maxTop = max(maxTop, reg.z + 0.12 + thickS);
	}
	if (fs > 0.0) {
		float w = fs * fs + 1e-3;
		acc  += w * vec4(reg.z + 0.12, thickS, 0.0, 1.0);
		wsum += w;
		F = 1.0 - (1.0 - F) * (1.0 - fs);
	}

	vec4 p = wsum > 0.0 ? acc / wsum : vec4(reg.z, 0.0, reg.y, 1.0);
	dist = F > 0.0 ? 0.0 : max(dist, 0.0);

	out0 = vec4(F, p.x, p.y, p.z);
	out1 = vec4(dist / cloudKm, p.w, maxTop + 0.05, 0.0);
}

// ---- Sampling -----------------------------------------------------------------------
#ifdef CLOUD_WEATHER_SAMPLING
CloudWeather CloudUnpackWeather(vec4 a, vec4 b) {
	CloudWeather w;
	w.cov = a.x; w.base = a.y; w.thick = a.z; w.type = a.w;
	w.dist = b.x; w.dens = b.y; w.maxTop = b.z;
	return w;
}

// Bilinear filtering of a distance field / max field is only conservative up to ~1.41 texel
CloudWeather CloudFilterMargin(CloudWeather w, float texelKm) {
	w.dist = max(w.dist - 1.42 * texelKm, 0.0);
	w.skipR = max(cloudSkipRadius - 0.72 * texelKm, 0.0);
	return w;
}

CloudWeather CloudMixWeather(CloudWeather a, CloudWeather b, float t) {
	CloudWeather w;
	w.cov = mix(a.cov, b.cov, t); w.base = mix(a.base, b.base, t); w.thick = mix(a.thick, b.thick, t);
	w.type = mix(a.type, b.type, t); w.dist = min(a.dist, b.dist); w.dens = mix(a.dens, b.dens, t);
	w.maxTop = max(a.maxTop, b.maxTop); w.skipR = min(a.skipR, b.skipR);
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
