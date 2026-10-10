// =====================================================================================
//  Light in the lower air: crepuscular rays and the haze layer
//
//  The sky (sky-view LUT) and the aerial perspective assume air lit everywhere by the sun.
//  Along each view ray, below the top of the cloud layer, this integrates:
//   - crepuscular rays: the single scattering (Rayleigh + Mie, real phase functions, sunlight
//     transmittance) of the air in the shadow of the clouds, to be subtracted from the scene.
//     Light that diffused through thin clouds still lights the air below them (isotropically).
//   - the haze layer: the dense aerosols of the boundary layer that pool in valleys (the
//     planetary scale aerosols of the atmosphere model are far too thin for visible shafts
//     over a few km). A participating medium of its own, added to the scene: sunlight with
//     the cloud shadows and its own extinction, sky and ground light, and its transmittance.
//     Its density decreases exponentially above HAZE_ALTITUDE (scale height HAZE_HEIGHT).
//  The shafts of light appear by contrast: Jacob's ladders below broken clouds, sunset rays
//  fanning out from the sun, anticrepuscular rays converging at the antisolar point.
//  Shadows come from the light space cloud shadow map (CloudSky.inc, +-80 km).
//
//  Needs Atmosphere.inc (with ATMOSPHERE_LUTS), CloudCommon.inc, CloudSky.inc with
//  CLOUD_SKY_LOOKUPS, and the uniforms worldLightVector, worldSunVector, nightBrightness.
//  Defines AIR_LIGHT_ACTIVE when there is anything to do.
// =====================================================================================

#ifndef CREPUSCULAR_INC
#define CREPUSCULAR_INC

#if defined CREPUSCULAR_RAYS && defined CLOUD_SHADOWS
	#define CREPUSCULAR_ACTIVE
#endif
#if HAZE_DENSITY > 0
	#define HAZE_ACTIVE
#endif

#if defined CREPUSCULAR_ACTIVE || defined HAZE_ACTIVE
#define AIR_LIGHT_ACTIVE

#ifdef HAZE_ACTIVE
	const float hazeSigma = 0.01 * exp2(float(HAZE_DENSITY));   // extinction at 550 nm, per km: 0.02 .. 0.64
	const vec3  hazeSpectral = vec3(0.87, 1.0, 1.24);   // Angstrom exponent 1.3 (610, 550, 465 nm)
	const float hazeAlbedo = 0.92;
	const float hazeH = float(HAZE_HEIGHT) * 0.001;   // scale height, km
	const float hazeGroundAlbedo = 0.2;
#endif

struct AirLight {
	vec3 removed;     // light of the air to subtract (CrepuscularApply): without haze, the direct
	                  // light the shadowed air does not scatter; with it, all the light of the air
	                  // of the segment, added back to inscatter behind the haze
	vec3 inscatter;   // light scattered toward the camera by the air and the haze: add
	vec3 T;           // transmittance of the haze
};

// dir: normalised view direction, dist: distance to the first surface (blocks, 1e9 for the sky),
// cloudTD: transmittance and distance (blocks) of the clouds seen through the pixel,
// noise: three values in [0, 1), different every frame, skyAmbient: average sky radiance,
// apFade: fade of the aerial perspective with the sky light at the eye (caves).
// removed and inscatter are in deferred12 sky units.
AirLight AirLightIntegrate(vec3 dir, float dist, vec2 cloudTD, vec3 noise, vec3 skyAmbient, float apFade) {
	AirLight res;
	res.removed = vec3(0.0);
	res.inscatter = vec3(0.0);
	res.T = vec3(1.0);

	vec3 L = worldLightVector;
	bool lit = L.y > -0.05;
	float lightScale = worldSunVector.y > 0.0 ? 1.0 : nightBrightness;   // the moon at night

	// Only the air below the top of the cloud layer can be in the shadow of a cloud, and the
	// haze lies far below it
	float camY = cameraPosition.y;
	float t0 = 0.0, t1 = min(dist, float(CREPUSCULAR_DISTANCE) * cloudKm);
	if (camY > cloudLayerTop) {
		if (dir.y >= -1e-4) return res;
		t0 = (camY - cloudLayerTop) / -dir.y;
	} else if (dir.y > 1e-4) {
		t1 = min(t1, (cloudLayerTop - camY) / dir.y);
	}
	if (t1 <= t0) return res;

	// The aerial perspective of surfaces is scaled (LandAtmosphericScattering): the same air
	float apScale = dist < 1e8 ? ATMOSPHERE_AERIAL_PERSPECTIVE * apFade : 1.0;
	vec3 ro = vec3(0.0, AtmoCameraRadius(), 0.0);   // planet centred, km
	float c = dot(dir, L);
	float phaseR = AtmoPhaseRayleigh(c), phaseM = AtmoPhaseMie(c, atmoMieG);
	float mieScale = AtmoMieDensityScale();
	const float strength = float(CREPUSCULAR_STRENGTH) * 0.01;
	#ifdef CREPUSCULAR_ACTIVE
		CloudShadowFrame frame = CloudShadowMakeFrame(L);
	#endif
	#ifdef HAZE_ACTIVE
		// aerosols: forward peak and some back scattering (two lobe Henyey-Greenstein)
		float phaseH = mix(AtmoPhaseHG(c, 0.78), AtmoPhaseHG(c, -0.3), 0.15);
		float hazeSig = hazeSigma * apFade * (1.0 + 2.0 * wetness);
		// radius of the haze altitude, relative to the camera: the atmosphere clamps the camera
		// to its ground (Y = 63), the haze follows the true altitudes (negative ones included)
		float hazeBase = ro.y + (float(HAZE_ALTITUDE) - camY) * atmoKmPerBlock;
		float muL = max(L.y, 0.0) + 0.012;   // the horizontal path through the layer is finite
		// ground lit by the sun below the haze (isotropic, half the sphere)
		float groundSun = 0.5 * hazeGroundAlbedo / atmoPI * max(L.y, 0.0);
	#endif

	// sums in front of the clouds (F) and behind them (B), per unit light irradiance (amb: per
	// unit ambient radiance)
	vec3 remF = vec3(0.0), remB = vec3(0.0), sunF = vec3(0.0), sunB = vec3(0.0), ambF = vec3(0.0), ambB = vec3(0.0);
	// Ta: transmittance of the air (already applied to the scene by the sky and the aerial
	// perspective), Th: of the haze (applied here)
	vec3 Ta = vec3(1.0), Th = vec3(1.0), Thcloud = vec3(1.0);

	// camera above the clouds: transmittance down to t0, one step
	if (t0 > 0.0) {
		vec3 Pm = ro + dir * (0.5 * t0 * atmoKmPerBlock);
		Ta = exp(-AtmoSampleMedium(length(Pm) - atmoRg, mieScale).ext * (apScale * t0 * atmoKmPerBlock));
		#ifdef HAZE_ACTIVE
			Th = exp(-hazeSig * hazeSpectral * (exp(-max(length(Pm) - hazeBase, 0.0) / hazeH) * t0 * atmoKmPerBlock));
		#endif
	}
	if (t0 >= cloudTD.y) Thcloud = Th;

	// quadratic distribution (shafts close to the camera are the largest on screen), one jitter
	// for all the steps (stratified), filtered by the temporal anti-aliasing
	// fewer steps over short segments (close terrain): 8 below ~3 km, all of them from 30 km
	int N = clamp(int(ceil(float(CREPUSCULAR_STEPS) * sqrt((t1 - t0) * atmoKmPerBlock / 30.0))), min(8, CREPUSCULAR_STEPS), CREPUSCULAR_STEPS);
	for (int i = 0; i < N; i++) {
		float a0 = float(i) / float(N), a1 = float(i + 1) / float(N);
		float ta = t0 + (t1 - t0) * a0 * a0, tb = t0 + (t1 - t0) * a1 * a1;
		float t = mix(ta, tb, noise.x);
		float dtKm = (tb - ta) * atmoKmPerBlock;
		vec3 P = ro + dir * (t * atmoKmPerBlock);
		float r = length(P);
		AtmoMedium m = AtmoSampleMedium(r - atmoRg, mieScale);
		vec3 extA = m.ext * apScale;
		vec3 sampleTa = exp(-extA * dtKm);
		vec3 wa = Ta * (1.0 - sampleTa) / max(extA, vec3(1e-7));   // integral of Ta over the step
		#ifdef HAZE_ACTIVE
			float hRel = r - hazeBase;
			vec3 hazeExt = hazeSig * hazeSpectral * exp(-max(hRel, 0.0) / hazeH);
			vec3 ext = extA + hazeExt;
			vec3 sampleTh = exp(-hazeExt * dtKm);
			vec3 wh = Ta * Th * (1.0 - sampleTa * sampleTh) / max(ext, vec3(1e-7));   // of Ta Th
		#endif
		bool front = t < cloudTD.y;

		// sunlight reaching the point: direct (exaggerated shadows above 100 %) and diffused
		// through the clouds; multiple scattering: the radiance field of the sky and the ground
		// (isotropic, Hillaire's multiple scattering LUT)
		float dirEff = 1.0, difEff = 0.0;
		vec3 sunL = vec3(0.0), ms = vec3(0.0);
		if (lit) {
			sunL = AtmoLightAt(P, r, L);
			#ifdef CREPUSCULAR_ACTIVE
				vec2 odv = CloudShadowOpticalDepthSplit(frame, dir * t, noise.yz - 0.5);
				float od = odv.x + odv.y;
				float direct = exp(-od);
				// the strength exaggerates the shadows of the low clouds (the shafts) only
				dirEff = clamp(1.0 - strength * (1.0 - exp(-odv.x)), 0.0, 1.0) * exp(-odv.y);
				difEff = (1.0 - direct) * 0.2 * exp(-od * 0.13) * min(1.0, 1.0 / strength);
			#endif
		}
		vec3 airSun = (m.scatR * phaseR + m.scatM * phaseM) * apScale, airIso = (m.scatR + m.scatM) * apScale;

		#ifdef HAZE_ACTIVE
			// The air of the segment is replaced: removed as the sky / aerial perspective
			// integrated it (lit, without haze), added back shadowed and behind the haze
			if (lit) ms = AtmoMultiScat(r, dot(P, L) / r);
			vec3 air0 = (sunL * airSun + ms * airIso) * wa;
			vec3 air1 = (sunL * (airSun * dirEff + airIso * (difEff * 0.25 / atmoPI)) + ms * airIso) * wh;
			// haze: sunlight through the haze above the point (vertical column / sun elevation)
			float column = max(-hRel, 0.0) + hazeH * exp(-max(hRel, 0.0) / hazeH);
			vec3 sunH = sunL * exp(-hazeSig * hazeSpectral * (column / muL));
			vec3 scat = hazeExt * hazeAlbedo * wh;
			vec3 add = air1 + scat * (sunH * (phaseH * dirEff + difEff * 0.25 / atmoPI + groundSun * dirEff) + ms);
			if (front) { remF += air0; sunF += add; ambF += scat; } else { remB += air0; sunB += add; ambB += scat; }
		#else
			// only the light the shadowed air does not scatter is removed
			vec3 rem = sunL * (airSun * (1.0 - dirEff) - airIso * (difEff * 0.25 / atmoPI)) * wa;
			if (front) remF += rem; else remB += rem;
		#endif

		Ta *= sampleTa;
		#ifdef HAZE_ACTIVE
			Th *= sampleTh;
			if (front) Thcloud = Th;
		#endif
	}

	float Tc = cloudTD.x;
	vec3 sunUnit = atmoSunColor * (atmoUnit * lightScale);
	res.removed = (remF + remB * Tc) * sunUnit;
	#ifdef HAZE_ACTIVE
		// no light above the horizon: the average sky radiance
		vec3 ambient = lit ? vec3(0.0) : skyAmbient * (0.5 + 0.5 * hazeGroundAlbedo);
		res.inscatter = (sunF + sunB * Tc) * sunUnit + (ambF + ambB * Tc) * ambient;
		// clouds: only the haze in front of them; the background: all of it
		res.T = mix(Thcloud, Th, Tc);
	#endif
	return res;
}

// Subtracts the shadowed light from a colour without changing its hue when it would exceed
// it (the sky / aerial perspective integrators differ a little from this one)
vec3 CrepuscularApply(vec3 color, vec3 shadowed) {
	vec3 r = color * 0.95 / max(shadowed, vec3(1e-9));
	return color - shadowed * min(1.0, min(r.r, min(r.g, r.b)));
}

#ifdef AIR_LIGHT_UPSAMPLE
uniform sampler2D airLightASampler;
uniform sampler2D airLightBSampler;

// Light in the air of an internal pixel from the low resolution pass (composite4_c, one pixel
// of each 2x2 block, a different one every frame): the 4 nearest samples, bilinear weights
// times the similarity of their surface distance. Returns false when no sample sees a similar
// surface (thin objects against the sky, edges): integrate the pixel itself then.
bool AirLightUpsample(ivec2 px, float dist, out AirLight a) {
	int i = frameCounter & 3;
	ivec2 off = ivec2(i == 1 || i == 2 ? 1 : 0, i == 1 || i == 3 ? 1 : 0);   // CloudCheckerOffset
	ivec2 rsz = (ivec2(ceil(vec2(viewWidth, viewHeight) * 0.5)) + 1) / 2;
	vec2 f = vec2(px - off) * 0.5;
	ivec2 b = ivec2(floor(f));
	vec2 fr = f - vec2(b);
	float dKm = min(dist * 0.001, 60000.0);
	vec4 sumA = vec4(0.0);
	vec3 sumB = vec3(0.0);
	float sumW = 0.0, best = 1e9;
	for (int k = 0; k < 4; k++) {
		ivec2 o = ivec2(k & 1, k >> 1);
		ivec2 q = clamp(b + o, ivec2(0), rsz - 1);
		vec4 A = texelFetch(airLightASampler, q, 0);
		vec4 B = texelFetch(airLightBSampler, q, 0);
		float rel = abs(B.w - dKm) / max(min(B.w, dKm), 0.02);
		best = min(best, rel);
		vec2 bw = mix(1.0 - fr, fr, vec2(o));
		float w = bw.x * bw.y * exp2(-rel * 20.0) + 1e-6;
		sumA += A * w;
		sumB += B.rgb * w;
		sumW += w;
	}
	a.removed = sumA.rgb / sumW;
	a.inscatter = sumB / sumW;
	#ifdef HAZE_ACTIVE
		a.T = exp(-(sumA.w / sumW) * hazeSpectral);
	#else
		a.T = vec3(1.0);
	#endif
	return best < 0.15;
}
#endif

// The whole lower air on a colour in composite4 units (unit: sky units -> composite units)
vec3 AirLightApply(vec3 color, AirLight a, float unit) {
	return CrepuscularApply(color, a.removed * unit) * a.T + a.inscatter * unit;
}

#endif
#endif
