// =====================================================================================
//  Volumetric clouds - density, lighting and ray marching
//
//  Needs CloudCommon.inc, CloudWeather.inc (with CLOUD_WEATHER_SAMPLING) and the samplers
//  cloudNoiseBase, cloudNoiseDetail, cloudCurl.
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

	// One 2D lookup gives a domain warp (rg) and a turret field (ba):
	//  - turrets: the local top height varies inside a cloud, so a big cumulus has several
	//    towers of different heights instead of one smooth dome
	//  - warp: bends the 3D noise so the bulges are not the regular round Worley cells
	vec4 aux = textureLod(cloudCurl, (baseOrigin.xz + p.xz) / (2.6 * cloudKm) + vec2(0.31, 0.77), 0.0);
	float turret = aux.b * 0.55 + aux.a * 0.45;
	float topScale = mix(1.0, mix(0.6, cloudTurretMax, CloudSat(turret * 1.4 - 0.2)), w.type * min(CLOUD_IRREGULARITY, 1.0));
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
	float cov = w.cov + (lowFbm - 0.5) * 0.5;

	float profileExp = mix(1.5, 2.8, w.type);
	float radius = sqrt(max(1.0 - pow(h, profileExp), 0.0)) * mix(0.8, 1.0, CloudSat(h * 8.0));
	float envConv = CloudSat((cov - (1.0 - radius)) * 2.2);
	float stratTop = 0.45 + 0.55 * CloudSat(cov * 1.6);   // thicker in the middle of a patch
	float envStrat = CloudSat(cov * 1.8) * CloudSat(h * 6.0) * CloudSat((stratTop - h) * 4.0);
	float env = mix(envStrat, envConv, w.type);
	if (env <= 0.0) return 0.0;

	shape = mix(mix(shape, 0.7, 0.2), shape, w.type);   // layered clouds are a bit smoother (still lumpy)
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

	// Convective clouds are denser in their upper part
	d *= mix(1.0, mix(0.5, 1.0, CloudSat(h * 2.5)), w.type);

	return d * w.dens;
}

// Density at an arbitrary position (used by the light march)
float CloudDensityAt(vec3 p, float camY, float detailAmount, vec3 baseOrigin, vec3 detailOrigin, int lod) {
	CloudWeather w = CloudSampleWeather(p.xz);
	if (w.cov <= 0.0 || w.thick <= 0.0) return 0.0;
	float h = (CloudAltitude(p, camY) - (cloudAltitude + w.base * cloudKm)) / (w.thick * cloudKm);
	if (h < 0.0 || h > cloudTurretMax) return 0.0;
	return CloudDensity(p, h, w, detailAmount, baseOrigin, detailOrigin, lod);
}

// ---- Lighting -----------------------------------------------------------------------------
// Optical depth toward the light: geometrically growing steps over ~2.4 km (scaled), the
// first one short enough (~20-60 m) to self-shadow the cauliflower bulges.
float CloudLightOpticalDepth(vec3 p, vec3 L, float camY, float jitter, float detailAmount, vec3 baseOrigin, vec3 detailOrigin) {
	const float total = 2400.0 * CLOUD_SCALE;
	const float ratio = 2.6;
	const float norm = total * (ratio - 1.0) / (pow(ratio, float(CQ_LIGHT_STEPS)) - 1.0);
	float tau = 0.0, d = 0.0;
	for (int i = 0; i < CQ_LIGHT_STEPS; i++) {
		float len = norm * pow(ratio, float(i));
		vec3 sp = p + L * (d + len * jitter);
		d += len;
		tau += CloudDensityAt(sp, camY, i == 0 ? detailAmount : 0.0, baseOrigin, detailOrigin, i < 2 ? 0 : 1) * len;
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

	float tStart, tEnd;
	if (!CloudShellSegment(dir, camY, cloudLayerBottom, cloudLayerTop, tStart, tEnd)) return r;
	tEnd = min(tEnd, min(sceneDist, cloudMaxDistance));
	if (tEnd <= tStart) return r;

	float time = CloudTime();
	vec3 baseOrigin   = mod(cameraPosition - CloudBaseNoiseOffset(time), vec3(cloudBasePeriod));
	vec3 detailOrigin = mod(cameraPosition - CloudDetailNoiseOffset(time), vec3(cloudDetailPeriod));

	// Phase function per scattering octave (anisotropy halves each octave)
	float cosTheta = dot(dir, L);
	float phase[CQ_MS_OCTAVES];
	for (int k = 0; k < CQ_MS_OCTAVES; k++) phase[k] = CloudPhase(cosTheta, exp2(-float(k)));
	// Diffuse (high order) scattering lobe: mildly forward
	float diffusePhase = mix(1.0, 4.0 * cloudPI * CloudPhaseHG(cosTheta, 0.3), 0.4) / cloudPI;

	// Sun light reflected by the ground onto cloud bases (isotropic, ~half the ground shadowed)
	float groundLight = CLOUD_GROUND_BOUNCE * max(L.y, 0.0) * 0.5 / cloudPI;

	float horiz = max(length(dir.xz), 1e-4);
	float detailDist = CQ_DETAIL_DISTANCE * cloudKm;

	float t = tStart + CloudStepLength(tStart) * noise.x;
	bool fine = false;
	int empty = 0, samples = 0;
	float wsum = 0.0, dsum = 0.0;

	for (int i = 0; i < CQ_STEPS * 3; i++) {
		if (t >= tEnd || samples >= CQ_STEPS) break;
		r.cost += 1.0;

		vec3 p = dir * t;
		float stepT = CloudStepLength(t);
		CloudWeather w = CloudSampleWeather(p.xz);

		float alt = CloudAltitude(p, camY);

		// Empty space skipping: above every cloud top of the neighbourhood, the ray can go
		// down to that top or leave the neighbourhood (whichever comes first).
		float topAlt = cloudAltitude + w.maxTop * cloudKm;
		float skip = 0.0;
		if (alt > topAlt) {
			float vertical = dir.y < -1e-4 ? (alt - topAlt) / -dir.y : 1e9;
			skip = min(vertical, w.skipR * cloudKm / horiz);
		}

		if (w.cov <= 0.0 || w.thick <= 0.0) {
			// ... and outside footprints, the 2D distance field gives a safe horizontal skip
			t += max(max(w.dist * cloudKm / horiz, skip), stepT);
			fine = false;
			continue;
		}

		float h = (alt - (cloudAltitude + w.base * cloudKm)) / (w.thick * cloudKm);
		if (h < 0.0 || h > cloudTurretMax) {
			t += max(skip, stepT);
			fine = false;
			continue;
		}

		float detailAmount = 1.0 - smoothstep(detailDist * 0.6, detailDist, t);
		float dens = CloudDensity(p, h, w, detailAmount, baseOrigin, detailOrigin, 0);

		if (!fine) {
			if (dens > 0.0) {
				// entering a cloud: step back and refine
				fine = true;
				empty = 0;
				t = max(t - stepT * 0.6, tStart);
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

		float tauL = CloudLightOpticalDepth(p, L, camY, noise.y, detailAmount, baseOrigin, detailOrigin);
		// sun below the local horizon of this sample (dusk / dawn)
		float lightVis = isSun ? CloudSunVisibility(L.y, alt) : 1.0;

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
		float opticalSize = w.thick * cloudKm * cloudSigmaT * w.dens;
		float diffuse = (1.0 - exp(-opticalSize * 0.12)) * CloudSat(dens * 4.0);
		sun += diffusePhase * exp(-tauL * CLOUD_DIFFUSION_DECAY) * diffuse * 0.85;
		sun *= lightVis;
		sun += groundLight * CloudSat(1.0 - h) * CloudSat(1.0 - h);

		// Sky light: higher parts of a cloud see more of the sky
		float sky = 0.2 + 0.8 * pow(min(h, 1.0), 0.7);

		// Energy conserving integration (Hillaire 2016), albedo ~1
		float wT = r.T * (1.0 - ext);
		r.sun += wT * sun;
		r.sky += wT * sky;
		dsum += wT * t;
		wsum += wT;
		r.T *= ext;
		if (r.T < 0.004) {
			r.T = 0.0;
			break;
		}
		t += dt;
	}

	r.depth = wsum > 1e-5 ? dsum / wsum : -1.0;
	return r;
}

#endif
