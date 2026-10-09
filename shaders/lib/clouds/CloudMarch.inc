// =====================================================================================
//  Volumetric clouds - density, lighting and ray marching
//
//  Needs CloudCommon.inc, CloudWeather.inc (with CLOUD_WEATHER_SAMPLING) and the samplers
//  cloudNoiseBase, cloudNoiseDetail, cloudCurl, cloudCirrus.
//
//  Three layers: low / convective clouds (weather map cells, up to cumulonimbus anvils),
//  a mid level layer (altocumulus / altostratus, marched in the same loop) and a thin high
//  sheet (cirrus, cirrocumulus, cirrostratus, analytic).
//
//  The march returns lighting as scalars (the light colours are applied at composite time):
//    sun   : integrated in-scattered sun light, to multiply by the sun irradiance
//    sky   : integrated in-scattered sky light, to multiply by the sky radiance
//    T     : transmittance of the clouds along the view ray
//    depth : transmittance weighted mean distance of the clouds (blocks), -1 if none
// =====================================================================================

#ifndef CLOUD_MARCH_INC
#define CLOUD_MARCH_INC

struct CloudResult {
	float sun;
	float sky;
	float T;
	float depth;
	float cost;
};

// ---- Density ----------------------------------------------------------------------------
// Convective clouds may rise up to this fraction above their nominal thickness (turrets)
const float cloudTurretMax = 1.15;
#ifndef CLOUD_DIFFUSION_DECAY
	#define CLOUD_DIFFUSION_DECAY 0.22
#endif

// p: camera relative position, h: normalised height inside the cloud (0 base .. 1 top)
// lod 0: full density, lod 1: low frequency only (for distant light samples, which would
// otherwise turn every small bulge into a long shadow streak)
float CloudDensity(vec3 p, float h, CloudWeather w, float detailAmount, vec3 baseOrigin, vec3 detailOrigin, int lod) {
	if (w.cov <= 0.0) return 0.0;

	// Cumulonimbus: type in 1..2 encodes the anvil, the body is the inner part of the
	// footprint (radius anvilK in footprint units)
	float type = w.type, anvilK = 1.0;
	if (type > 1.0) {
		anvilK = max(2.0 - type, 0.2);
		type = 1.0;
	}
	float anvil = CloudSat((1.0 - anvilK) * 4.0);

	// One 2D lookup gives a domain warp (rg) and a turret field (ba):
	//  - turrets: the local top height varies inside a cloud, so a big cumulus has several
	//    towers of different heights instead of one smooth dome
	//  - warp: bends the 3D noise so the bulges are not the regular round Worley cells
	vec4 aux = textureLod(cloudCurl, (baseOrigin.xz + p.xz) / (2.6 * cloudKm) + vec2(0.31, 0.77), 0.0);
	float turret = aux.b * 0.55 + aux.a * 0.45;
	float topScale = mix(1.0, mix(0.6, cloudTurretMax, CloudSat(turret * 1.4 - 0.2)), type * min(CLOUD_IRREGULARITY, 1.0) * (1.0 - anvil));
	h /= topScale;
	if (h > 1.0) return 0.0;

	vec2 warp = (aux.rg - 0.5) * (2.0 * 220.0 * cloudScale * CLOUD_IRREGULARITY);
	// wind shear: upper parts of clouds lean downwind
	vec2 shear = CloudWindDir() * (h * w.thick * 0.18 * cloudKm);
	vec3 bp = baseOrigin + p + vec3(warp.x + shear.x, (warp.x - warp.y) * 0.35, warp.y + shear.y);

	// Base shape noise: Perlin-Worley eroded by billowy Worley fBm
	vec4 bn = textureLod(cloudNoiseBase, bp / cloudBasePeriod, 0.0);
	float lowFbm = bn.g * 0.625 + bn.b * 0.25 + bn.a * 0.125;
	float shape = CloudRemap(bn.r, lowFbm - 1.0, 1.0, 0.0, 1.0);
	if (lod > 0) {
		lowFbm = bn.g;
		shape = mix(shape, 0.6, 0.5);
	}

	// Envelope ("dimensional profile"). w.cov is the radial footprint (1 at the centre of a
	// cloud, 0 at its edge). Convective clouds: flat, slightly rounded base, wide body and a
	// rounded top that gets more tower-like with the cloud type. Layered clouds: a slab.
	// The footprint is a 2D field: it is perturbed in 3D so cloud sides are not vertical walls.
	float pert = (lowFbm - 0.5) * 0.5;
	float cov = w.cov + pert;
	// footprint of the body (= cov without anvil). The body is narrower than the stored
	// footprint, so its 2D detail is magnified: a stronger 3D perturbation keeps a towering
	// column from looking like an extruded 2D shape.
	// (no perturbation where the footprint vanishes: the filtered edge of an anvil footprint
	// must not grow columns)
	float covBody = (w.cov - (1.0 - anvilK)) / anvilK + pert * mix(1.0, 2.2 * CloudSat(w.cov * 5.0), anvil);

	// cumulonimbus: tall column with a small overshooting dome above the anvil
	float profileExp = mix(mix(1.5, 2.8, type), 4.5, anvil);
	float radius = sqrt(max(1.0 - pow(h, profileExp), 0.0)) * mix(0.8, 1.0, CloudSat(h * 8.0));
	float envConv = CloudSat((covBody - (1.0 - radius)) * 2.2);
	float anvilPart = 0.0;
	if (anvil > 0.0) {
		// the anvil flares out between 68 and 90 % of the height, under a flat top
		float aRad = mix(anvilK, 1.0, smoothstep(0.68, 0.9, h)) * CloudSat((0.96 - h) * 30.0);
		float envAnvil = CloudSat((cov - (1.0 - aRad)) * 4.0) * anvil * smoothstep(0.64, 0.74, h);
		anvilPart = CloudSat((envAnvil - envConv) * 4.0);
		envConv = max(envConv, envAnvil);
	}
	float stratTop = 0.45 + 0.55 * CloudSat(cov * 1.6);   // thicker in the middle of a patch
	float envStrat = CloudSat(cov * 1.8) * CloudSat(h * 6.0) * CloudSat((stratTop - h) * 4.0);
	float env = mix(envStrat, envConv, type);
	if (env <= 0.0) return 0.0;

	shape = mix(mix(shape, 0.7, 0.2), shape, type);   // layered clouds are a bit smoother (still lumpy)
	shape = mix(shape, max(shape, 0.75), anvilPart);   // anvils: smoother ice sheets
	float d = CloudSat(CloudRemap(shape, 1.0 - env, 1.0, 0.0, 1.0)) * env;
	if (d <= 0.0) return 0.0;

	// Detail erosion: wispy at the bottom, billowy (cauliflower) higher up. Applied before the
	// sharpening below so it carves the silhouette instead of only adding fuzz.
	if (detailAmount > 0.0) {
		vec2 curl = (textureLod(cloudCurl, (detailOrigin.xz + p.xz) / cloudCurlPeriod, 0.0).rg - 0.5) * 2.0;
		vec3 dp = detailOrigin + p + vec3(curl.x, 0.0, curl.y) * ((1.0 - h) * 140.0 * cloudScale);
		vec3 dn = textureLod(cloudNoiseDetail, dp / cloudDetailPeriod, 0.0).rgb;
		float hf = dn.r * 0.5 + dn.g * 0.3 + dn.b * 0.2;
		float erosion = mix(hf, 1.0 - hf, CloudSat(h * 10.0));
		d = CloudSat(CloudRemap(d, erosion * CLOUD_EROSION * detailAmount, 1.0, 0.0, 1.0));
	}

	// Sharpen the density ramp: real cumulus edges are crisp (liquid water content rises
	// within tens of metres of the boundary)
	d = CloudSat(d * 2.0);

	// Convective clouds are denser in their upper part, anvils are thinner (ice)
	d *= mix(1.0, mix(0.5, 1.0, CloudSat(h * 2.5)), type);
	d *= mix(1.0, 0.45, anvilPart);

	return d * w.dens;
}

// ---- Context ---------------------------------------------------------------------------
struct CloudCtx {
	CloudSkyRegime R;
	vec3 baseOrigin;    // wrapped noise origins (camera position - noise offset)
	vec3 detailOrigin;
	vec3 midOrigin;
	vec2 midWorld;      // camera xz in the frame of the mid level wind (not wrapped)
	vec2 highWorld;     // camera xz in the frame of the high level wind
};

CloudCtx CloudMakeCtx(float time) {
	CloudCtx c;
	c.R = CloudGetSkyRegime();
	c.baseOrigin   = mod(cameraPosition - CloudBaseNoiseOffset(time), vec3(cloudBasePeriod));
	c.detailOrigin = mod(cameraPosition - CloudDetailNoiseOffset(time), vec3(cloudDetailPeriod));
	c.midOrigin    = mod(cameraPosition - CloudMidNoiseOffset(time), vec3(cloudMidPeriod));
	c.midWorld     = cameraPosition.xz - CloudWindOffset(time) * cloudMidWind;
	c.highWorld    = cameraPosition.xz - CloudHighWindOffset(time);
	return c;
}

// ---- Mid level layer ---------------------------------------------------------------------
// Altocumulus: rows of small rounded cloudlets. Altostratus: smooth grey sheet. The local
// type follows the regime and gets more stratiform where the deck is dense.
// Returns the density (in units of cloudSigmaT); h: height in the layer (0..1),
// thick: local thickness (scaled km).
// lod 1: no small scale noise (distant light march samples)
float CloudMidDensity(vec3 p, float alt, CloudWeather w, CloudCtx ctx, float detailAmount, int lod, out float h, out float thick) {
	h = 0.0; thick = 0.0;
	float c = CloudSat(w.mid * 5.0);
	if (c <= 0.0) return 0.0;

	vec4 aux = textureLod(cloudCurl, (ctx.midWorld + p.xz) / (13.0 * cloudKm) + vec2(0.71, 0.29), 0.0);
	float type = CloudSat(ctx.R.midType + (w.mid - 0.2) * 0.8 + (aux.b - 0.5) * 0.4);
	float maxThick = mix(0.28, 1.3, type);
	float baseKm = mix(2.7, 2.2, type) + (aux.a - 0.5) * mix(0.8, 0.4, type);

	// early out above / below the thickest the layer can be here
	float thickBound = maxThick * sqrt(CloudSat(c + 0.25 * (1.0 - c)));
	float hb = (alt - (cloudAltitude + (baseKm + (maxThick - thickBound) * 0.5) * cloudKm)) / max(thickBound * cloudKm, 1.0);
	thick = thickBound;
	if (hb <= 0.0 || hb >= 1.0) return 0.0;
	if (lod > 0) {
		h = hb;
		float profile = CloudSat(hb * 4.0) * CloudSat((1.0 - hb) * 3.0);
		return mix(0.3 * c, 0.35 * c * (0.5 + 0.35 * aux.b), smoothstep(0.4, 0.8, type)) * profile;
	}
	// Cloudlets: Worley cells, stretched into rows (x2 along one axis: keeps the tiling),
	// flattened vertically, bent by the curl field
	vec3 mp = ctx.midOrigin + p;
	#if (CLOUD_WIND_ANGLE > 45 && CLOUD_WIND_ANGLE < 135) || (CLOUD_WIND_ANGLE > 225 && CLOUD_WIND_ANGLE < 315)
		vec3 np = mp / cloudMidPeriod * vec3(1.0, 2.0, 2.0);   // wind along z: rows along x
	#else
		vec3 np = mp / cloudMidPeriod * vec3(2.0, 2.0, 1.0);
	#endif
	vec2 wv = (aux.rg - 0.5) * 0.3;
	vec4 bn = textureLod(cloudNoiseBase, np + vec3(wv.x, 0.0, wv.y), 0.0);

	// The layer thins out toward the edge of a patch (a ragged wedge, not a vertical wall)
	// and its base undulates gently (less for the altostratus sheets)
	thick = maxThick * sqrt(CloudSat(c + (bn.r - 0.5) * 0.5 * (1.0 - c)));
	baseKm += (maxThick - thick) * 0.5;
	h = (alt - (cloudAltitude + baseKm * cloudKm)) / max(thick * cloudKm, 1.0);
	if (h <= 0.0 || h >= 1.0) return 0.0;

	float cells = bn.g * 0.55 + bn.b * 0.45;
	// rounded cloudlets; toward the edge of a patch they get thinner rather than smaller
	// (cloudlets smaller than the march steps would alias)
	float puff = 1.0 - pow(abs(h * 2.0 - 1.0), 2.0);
	float th = mix(0.7, 0.45, c) + (1.0 - puff) * 0.45;
	float ac = CloudSat((cells * 0.85 + bn.r * 0.15 - th) * 7.0) * CloudSat(c * 4.0);

	if (detailAmount > 0.0 && ac > 0.0) {
		vec3 dn = textureLod(cloudNoiseDetail, (ctx.detailOrigin + p) / cloudDetailPeriod, 0.0).rgb;
		float hf = dn.g * 0.6 + dn.b * 0.4;
		ac = CloudSat(CloudRemap(ac, (1.0 - hf) * 0.45 * CLOUD_EROSION * detailAmount, 1.0, 0.0, 1.0));
	}

	// altostratus: large soft undulations only
	float as = CloudSat(c * 3.0) * CloudSat(h * 4.0) * CloudSat((1.0 - h) * 3.0) * (0.5 + 0.35 * aux.b + 0.15 * bn.r);
	return mix(ac * 0.8, as * 0.35, smoothstep(0.4, 0.8, type));
}

// ---- High layer --------------------------------------------------------------------------
// x: vertical optical depth of the high clouds at a camera relative horizontal position,
// y: weight of the cirrostratus veil (halo). fineW: weight of the fine fibres (fade with distance).
vec2 CloudHighTau(vec2 xz, CloudCtx ctx, float fineW) {
	if (ctx.R.high <= 0.0) return vec2(0.0);
	// along / across the high level wind: cirrus bands and fibres are stretched along it
	const float ang = float(CLOUD_WIND_ANGLE + 25) * 0.01745329;
	const vec2 hw = vec2(cos(ang), sin(ang));
	vec2 q = ctx.highWorld + xz;
	vec2 qr = vec2(dot(q, hw), dot(q, vec2(-hw.y, hw.x)));

	vec4 a = textureLod(cloudCurl, qr / (vec2(110.0, 40.0) * cloudKm) + vec2(0.17, 0.53), 0.0);
	vec4 b = textureLod(cloudCurl, qr / (vec2(36.0, 12.0) * cloudKm) + vec2(0.83, 0.37), 0.0);
	float patchField = a.a * 0.65 + b.b * 0.35;
	float cover = CloudSat((patchField - (0.44 - 0.47 * (ctx.R.high - 0.5))) * 2.5);
	if (cover <= 0.0) return vec2(0.0);
	float ht = CloudSat(ctx.R.highType + (a.b - 0.5) * 0.5);

	vec2 uv = qr / cloudHighPeriod + (b.rg - 0.5) * 0.02;
	vec4 t1 = textureLod(cloudCirrus, uv, 0.0);
	vec4 t2 = textureLod(cloudCirrus, uv * 3.0 + vec2(0.37, 0.61), 0.0);

	// cirrus: fibres, feathery where the patch thins out
	float fib = t1.a * 0.5 + mix(0.5, t2.r, fineW) * 0.5;
	float ci = CloudSat(cover * (0.6 + fib) - 0.55) * 1.3;
	// cirrocumulus: grains in ripples
	float cc = CloudSat(cover * (0.5 + mix(0.5, t2.g, fineW)) - 0.65) * 1.6;
	// cirrostratus: thin veil
	float cs = cover * (0.45 + 0.55 * t1.b);
	float wCi = CloudSat(1.0 - 2.0 * ht), wCs = CloudSat(2.0 * ht - 1.0), wCc = 1.0 - wCi - wCs;
	float tau = ci * wCi + cc * 0.7 * wCc + cs * 0.4 * wCs;
	return vec2(tau, wCs * cover);
}

// The high sheet crossed by a view ray. x, y: sun and sky scattering (already weighted by
// 1 - T), z: transmittance, w: distance (-1 if none)
vec4 CloudHighLayer(vec3 dir, float sceneDist, float camY, vec3 L, bool isSun, CloudCtx ctx, float cosTheta) {
	vec4 res = vec4(0.0, 0.0, 1.0, -1.0);
	float t0, t1;
	if (ctx.R.high <= 0.0 || !CloudSphere(dir.y, camY, cloudHighAlt, t0, t1)) return res;
	float t = camY < cloudHighAlt ? t1 : t0;
	float maxD = 2.5 * cloudMaxDistance;
	if (t <= 0.0 || t > sceneDist || t > maxD) return res;

	vec3 p = dir * t;
	float fineW = 1.0 - smoothstep(15.0 * cloudKm, 60.0 * cloudKm, t);
	vec2 hs = CloudHighTau(p.xz, ctx, fineW);
	float tauV = hs.x * (1.0 - smoothstep(0.6 * maxD, maxD, t));
	if (tauV <= 1e-4) return res;

	vec3 up = normalize(vec3(p.x, p.y + camY + cloudPlanetR, p.z));
	float mu = max(abs(dot(dir, up)), 0.04);
	float muL = max(dot(L, up), 0.04);
	float T = exp(-tauV / mu);
	float tauL = tauV / muL;

	// ice crystals: forward peak + broad lobe, 22 degree halo in cirrostratus
	float ph = mix(CloudPhaseHG(cosTheta, 0.75), 0.25 / cloudPI, 0.4);
	float da = (acos(clamp(cosTheta, -1.0, 1.0)) - 0.3840) / 0.012;
	ph += exp(-da * da) * 0.05 * hs.y;
	float sun = ph * exp(-0.5 * tauL) + 0.25 / cloudPI * exp(-0.15 * tauL);
	if (isSun) sun *= CloudSunVisibility(dot(L, up), cloudHighAlt);

	res = vec4(sun * (1.0 - T), (1.0 - T), T, t);
	return res;
}

// Light blocked by the mid and high layers above a point (when the light march does not
// reach them). Broken altocumulus lets light through its gaps; thick decks transmit diffuse light.
float CloudOverheadTransmittance(vec3 p, float alt, vec3 L, CloudCtx ctx) {
	float T = 1.0;
	if (L.y < 0.03) return T;
	#if CLOUD_MID_LAYER > 0
		const float reach = 2400.0 * CLOUD_SCALE;   // length of the light march
		if (ctx.R.mid > 0.0 && alt + reach * L.y < cloudMidBottom) {
			float midAlt = cloudAltitude + 2.6 * cloudKm;
			CloudWeather w = CloudSampleWeather(p.xz + L.xz * ((midAlt - alt) / L.y));
			float c = CloudSat(w.mid * 5.0);
			if (c > 0.0) {
				float type = CloudSat(ctx.R.midType + (w.mid - 0.2) * 0.8);
				float tau = mix(8.0, 22.0, type) * c / L.y;
				float e = exp(-tau);
				float Td = e + (1.0 - e) * 0.45 / (1.0 + 0.15 * tau);
				T *= 1.0 - c * mix(0.6, 1.0, type) * (1.0 - Td);
			}
		}
	#endif
	#if CLOUD_HIGH_LAYER > 0
		if (alt < cloudHighAlt && ctx.R.high > 0.0) {
			float tau = CloudHighTau(p.xz + L.xz * ((cloudHighAlt - alt) / L.y), ctx, 0.0).x / L.y;
			T *= mix(1.0, exp(-tau), 0.4);   // mostly scattered forward: little light lost
		}
	#endif
	return T;
}


// Density of all the marched layers at an arbitrary position (used by the light march)
float CloudDensityAt(vec3 p, float camY, float detailAmount, CloudCtx ctx, int lod) {
	CloudWeather w = CloudSampleWeather(p.xz);
	float alt = CloudAltitude(p, camY);
	float d = 0.0;
	if (w.cov > 0.0 && w.thick > 0.0) {
		float h = (alt - (cloudAltitude + w.base * cloudKm)) / (w.thick * cloudKm);
		if (h >= 0.0 && h <= cloudTurretMax) d = CloudDensity(p, h, w, detailAmount, ctx.baseOrigin, ctx.detailOrigin, lod);
	}
	#if CLOUD_MID_LAYER > 0
		if (w.mid > 0.0 && alt > cloudMidBottom && alt < cloudMidTop) {
			float hm, tm;
			d += CloudMidDensity(p, alt, w, ctx, lod == 0 ? detailAmount : 0.0, lod, hm, tm);
		}
	#endif
	return d;
}

// ---- Lighting -----------------------------------------------------------------------------
// Optical depth toward the light: geometrically growing steps over ~2.4 km (scaled), the
// first one short enough (~20-60 m) to self-shadow the cauliflower bulges.
float CloudLightOpticalDepth(vec3 p, vec3 L, float camY, float jitter, float detailAmount, CloudCtx ctx) {
	const float total = 2400.0 * CLOUD_SCALE;
	const float ratio = 2.6;
	const float norm = total * (ratio - 1.0) / (pow(ratio, float(CQ_LIGHT_STEPS)) - 1.0);
	float tau = 0.0, d = 0.0;
	for (int i = 0; i < CQ_LIGHT_STEPS; i++) {
		float len = norm * pow(ratio, float(i));
		vec3 sp = p + L * (d + len * jitter);
		d += len;
		tau += CloudDensityAt(sp, camY, i == 0 ? detailAmount : 0.0, ctx, i < 2 ? 0 : 1) * len;
	}
	return tau * cloudSigmaT;
}

float CloudStepLength(float t) {
	return (60.0 * CLOUD_SCALE + t * 0.012) * CQ_STEP_SCALE;
}

// ---- Ray march ------------------------------------------------------------------------------
// dir: normalised world direction, sceneDist: distance to the first opaque surface,
// L: light direction, noise: two blue noise values in [0,1)
CloudResult CloudMarch(vec3 dir, float sceneDist, float camY, vec3 L, bool isSun, vec2 noise) {
	CloudResult r;
	r.sun = 0.0; r.sky = 0.0; r.T = 1.0; r.depth = -1.0; r.cost = 0.0;

	float time = CloudTime();
	CloudCtx ctx = CloudMakeCtx(time);
	float cosTheta = dot(dir, L);
	float wsum = 0.0, dsum = 0.0;

	// High clouds: in front of the other layers only when flying above them
	#if CLOUD_HIGH_LAYER > 0
		vec4 high = CloudHighLayer(dir, sceneDist, camY, L, isSun, ctx, cosTheta);
		bool highFirst = camY > cloudHighAlt;
		if (highFirst && high.w > 0.0) {
			r.sun = high.x; r.sky = high.y; r.T = high.z;
			wsum = 1.0 - high.z;
			dsum = wsum * high.w;
		}
	#endif

	float tStart, tEnd;
	float topLimit = cloudAltitude + (ctx.R.cb > 0.0 ? 9.0 : 7.2) * cloudKm;
	bool layerHit = CloudShellSegment(dir, camY, cloudLayerBottom, topLimit, tStart, tEnd);
	tEnd = min(tEnd, min(sceneDist, cloudMaxDistance));

	if (layerHit && tEnd > tStart) {
		// Phase function per scattering octave (anisotropy halves each octave)
		float phase[CQ_MS_OCTAVES];
		for (int k = 0; k < CQ_MS_OCTAVES; k++) phase[k] = CloudPhase(cosTheta, exp2(-float(k)));
		// Diffuse (high order) scattering lobe: mildly forward
		float diffusePhase = mix(1.0, 4.0 * cloudPI * CloudPhaseHG(cosTheta, 0.3), 0.4) / cloudPI;

		// Sun light reflected by the ground onto cloud bases (isotropic, ~half the ground shadowed)
		float groundLight = CLOUD_GROUND_BOUNCE * max(L.y, 0.0) * 0.5 / cloudPI;

		float horiz = max(length(dir.xz), 1e-4);
		float detailDist = CQ_DETAIL_DISTANCE * cloudKm;

		// part of the ray inside the mid level layer
		float tm0 = 1e9, tm1 = -1.0;
		#if CLOUD_MID_LAYER > 0
			if (ctx.R.mid <= 0.0 || !CloudShellSegment(dir, camY, cloudMidBottom, cloudMidTop, tm0, tm1)) {
				tm0 = 1e9; tm1 = -1.0;
			}
		#endif

		float t = tStart + CloudStepLength(tStart) * noise.x;
		float tKnown = tStart;   // the ray is known to be empty before this distance
		bool fine = false;
		int empty = 0, samples = 0;
		float overheadT = 1.0, overheadAt = -1e9;

		for (int i = 0; i < CQ_STEPS * 3; i++) {
			if (t >= tEnd || samples >= CQ_STEPS || r.T < 0.004) break;
			r.cost += 1.0;

			vec3 p = dir * t;
			float stepT = CloudStepLength(t);
			CloudWeather w = CloudSampleWeather(p.xz);
			float alt = CloudAltitude(p, camY);
			float detailAmount = 1.0 - smoothstep(detailDist * 0.6, detailDist, t);

			// ---- low / convective clouds
			// Empty space skipping: above every cloud top of the neighbourhood, the ray can go
			// down to that top or leave the neighbourhood (whichever comes first) ...
			float topAlt = cloudAltitude + w.maxTop * cloudKm;
			float skip = 0.0;
			if (alt > topAlt) {
				float vertical = dir.y < -1e-4 ? (alt - topAlt) / -dir.y : 1e9;
				skip = min(vertical, w.skipR * cloudKm / horiz);
			}
			float densLow = 0.0, hLow = 0.0, jump;
			bool evalLow = false;
			if (w.cov <= 0.0 || w.thick <= 0.0) {
				// ... and outside footprints, the 2D distance field gives a safe horizontal skip
				jump = max(max(w.dist * cloudKm / horiz, skip), stepT);
			} else {
				hLow = (alt - (cloudAltitude + w.base * cloudKm)) / (w.thick * cloudKm);
				if (hLow < 0.0 || hLow > cloudTurretMax) {
					jump = max(skip, stepT);
				} else {
					evalLow = true;
					jump = stepT;
					densLow = CloudDensity(p, hLow, w, detailAmount, ctx.baseOrigin, ctx.detailOrigin, 0);
				}
			}

			// ---- mid level layer (skips are limited by its own distance field inside it)
			float densMid = 0.0, hMid = 0.0, thickMid = 0.0;
			bool evalMid = false;
			#if CLOUD_MID_LAYER > 0
				if (t >= tm0 && t <= tm1) {
					jump = min(jump, max(w.midDist * cloudKm / horiz, stepT));
					if (w.mid > 0.0) {
						evalMid = true;
						densMid = CloudMidDensity(p, alt, w, ctx, detailAmount, 0, hMid, thickMid);
						// shorter steps in thin parts of the layer (at most 2x more)
						stepT = min(stepT, max(thickMid * cloudKm * 0.5, stepT * 0.5));
					}
				} else if (t < tm0) {
					jump = min(jump, tm0 - t + 0.5);   // never jump over the mid layer
				}
			#endif

			if (!evalLow && !evalMid) {
				t += jump;
				tKnown = t;
				fine = false;
				continue;
			}

			float dens = densLow + densMid;
			if (!fine) {
				if (dens > 0.0) {
					// entering a cloud: step back and refine
					fine = true;
					empty = 0;
					t = max(t - stepT * 0.6, tKnown);
				} else {
					t += stepT;
				}
				continue;
			}

			float dt = stepT * 0.4;
			if (dens <= 0.0) {
				if (++empty > 6) fine = false;
				t += dt;
				continue;
			}
			empty = 0;
			samples++;

			float sigma = dens * cloudSigmaT;
			float ext = exp(-sigma * dt);

			// light blocked by the layers above (refreshed every few km along the ray)
			if (abs(t - overheadAt) > 3.0 * cloudKm) {
				overheadT = CloudOverheadTransmittance(p, alt, L, ctx);
				overheadAt = t;
			}

			float tauL = CloudLightOpticalDepth(p, L, camY, noise.y, detailAmount, ctx);
			// sun below the local horizon of this sample (dusk / dawn)
			float lightVis = (isSun ? CloudSunVisibility(L.y, alt) : 1.0) * overheadT;

			float wMid = densMid / dens;
			float h = mix(CloudSat(hLow), hMid, wMid);

			// Sun light:
			//  - single scattering + low order octaves (Wrenninge 2013 / Hillaire 2016): sharp
			//    silver linings and forward glow
			//  - diffusion term: in a nearly non absorbing medium the light that keeps being
			//    scattered forms a diffuse field of radiance ~E/pi near the lit surface, that
			//    decays with the *transport* optical depth tau * (1 - g). It is what makes the lit
			//    side of thick clouds bright. Scaled down for optically small clouds and wisps.
			float sun = 0.0, a = 1.0, b = 1.0;
			for (int k = 0; k < CQ_MS_OCTAVES; k++) {
				sun += a * phase[k] * exp(-tauL * b);
				a *= 0.5;
				b *= 0.4;
			}
			float opticalSize = mix(w.thick * w.dens, thickMid * 0.5, wMid) * cloudKm * cloudSigmaT;
			float diffuse = (1.0 - exp(-opticalSize * 0.12)) * CloudSat(dens * 4.0);
			sun += diffusePhase * exp(-tauL * CLOUD_DIFFUSION_DECAY) * diffuse * 0.85;
			sun *= lightVis;
			sun += groundLight * overheadT * CloudSat(1.0 - h) * CloudSat(1.0 - h);

			// Sky light: higher parts of a cloud see more of the sky
			float sky = mix(0.2 + 0.8 * pow(min(h, 1.0), 0.7), 0.4 + 0.6 * h, wMid);

			// Energy conserving integration (Hillaire 2016), albedo ~1
			float wT = r.T * (1.0 - ext);
			r.sun += wT * sun;
			r.sky += wT * sky;
			dsum += wT * t;
			wsum += wT;
			r.T *= ext;
			if (r.T < 0.004) r.T = 0.0;
			t += dt;
		}
	}

	#if CLOUD_HIGH_LAYER > 0
		if (!highFirst && high.w > 0.0 && r.T > 0.0) {
			float wT = r.T * (1.0 - high.z);
			r.sun += r.T * high.x;
			r.sky += r.T * high.y;
			dsum += wT * high.w;
			wsum += wT;
			r.T *= high.z;
		}
	#endif

	r.depth = wsum > 1e-5 ? dsum / wsum : -1.0;
	return r;
}

#endif
