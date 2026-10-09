// =====================================================================================
//  Crepuscular rays: the shadows of the clouds in the air
//
//  The sky (sky-view LUT) and the aerial perspective assume air lit everywhere by the sun.
//  Air in the shadow of a cloud does not scatter the direct sunlight: this integrates, along
//  the view ray, the single scattering (Rayleigh + Mie, real phase functions, sunlight
//  transmittance) of the shadowed air, to be subtracted from the scene. Shafts of light
//  between the shadows appear by contrast: Jacob's ladders below broken clouds, sunset rays
//  fanning out from the sun, anticrepuscular rays converging at the antisolar point. Light
//  that diffused through thin clouds still lights the air below them (isotropically).
//  Shadows come from the light space cloud shadow map (CloudSky.inc, +-80 km).
//
//  Needs Atmosphere.inc (with ATMOSPHERE_LUTS), CloudCommon.inc, CloudSky.inc with
//  CLOUD_SKY_LOOKUPS, and the uniforms worldLightVector, worldSunVector, nightBrightness.
// =====================================================================================

#ifndef CREPUSCULAR_INC
#define CREPUSCULAR_INC

// Radiance of the direct sun (or moon) light that the shadowed air does not scatter toward the
// camera, in deferred12 sky units.
// dir: normalised view direction, dist: distance to the first surface (blocks, 1e9 for the sky),
// cloudTD: transmittance and distance (blocks) of the clouds seen through the pixel,
// noise: three values in [0, 1), different every frame.
vec3 CrepuscularShadowedLight(vec3 dir, float dist, vec2 cloudTD, vec3 noise) {
	vec3 L = worldLightVector;
	if (L.y < -0.05) return vec3(0.0);
	float lightScale = worldSunVector.y > 0.0 ? 1.0 : nightBrightness;   // the moon at night

	// Only the air below the top of the cloud layer can be in the shadow of a cloud
	float camY = cameraPosition.y;
	float t0 = 0.0, t1 = min(dist, float(CREPUSCULAR_DISTANCE) * cloudKm);
	if (camY > cloudLayerTop) {
		if (dir.y >= -1e-4) return vec3(0.0);
		t0 = (camY - cloudLayerTop) / -dir.y;
	} else if (dir.y > 1e-4) {
		t1 = min(t1, (cloudLayerTop - camY) / dir.y);
	}
	if (t1 <= t0) return vec3(0.0);

	vec3 ro = vec3(0.0, AtmoCameraRadius(), 0.0);   // planet centred, km
	float c = dot(dir, L);
	float phaseR = AtmoPhaseRayleigh(c), phaseM = AtmoPhaseMie(c, atmoMieG);
	float mieScale = AtmoMieDensityScale();
	vec3 front = vec3(0.0), back = vec3(0.0);
	#if CREPUSCULAR_STRENGTH > 100
		// exaggerated rays: never remove more than the light the air scatters in total
		vec3 fullFront = vec3(0.0), fullBack = vec3(0.0);
	#endif
	CloudShadowFrame frame = CloudShadowMakeFrame(L);

	// transmittance from the camera to t0 (camera above the clouds): one step
	vec3 T = vec3(1.0);
	if (t0 > 0.0) {
		vec3 Pm = ro + dir * (0.5 * t0 * atmoKmPerBlock);
		T = exp(-AtmoSampleMedium(length(Pm) - atmoRg, mieScale).ext * (t0 * atmoKmPerBlock));
	}

	// quadratic distribution (shafts close to the camera are the largest on screen), one jitter
	// for all the steps (stratified), filtered by the temporal anti-aliasing
	const int N = CREPUSCULAR_STEPS;
	for (int i = 0; i < N; i++) {
		float a0 = float(i) / float(N), a1 = float(i + 1) / float(N);
		float ta = t0 + (t1 - t0) * a0 * a0, tb = t0 + (t1 - t0) * a1 * a1;
		float t = mix(ta, tb, noise.x);
		float dtKm = (tb - ta) * atmoKmPerBlock;
		vec3 P = ro + dir * (t * atmoKmPerBlock);
		float r = length(P);
		AtmoMedium m = AtmoSampleMedium(r - atmoRg, mieScale);
		vec3 sampleT = exp(-m.ext * dtKm);
		float od = CloudShadowOpticalDepth(frame, dir * t, noise.yz - 0.5, true);
		#if CREPUSCULAR_STRENGTH > 100
			vec3 sunL = AtmoLightAt(P, r, L);
			vec3 Sf = sunL * (m.scatR * phaseR + m.scatM * phaseM);
			vec3 addF = T * (Sf - Sf * sampleT) / max(m.ext, vec3(1e-7));
			if (t < cloudTD.y) fullFront += addF; else fullBack += addF;
		#endif
		if (od > 0.003) {
			#if CREPUSCULAR_STRENGTH <= 100
				vec3 sunL = AtmoLightAt(P, r, L);
			#endif
			float direct = exp(-od);
			float diffuse = (1.0 - direct) * 0.2 * exp(-od * 0.13);
			vec3 S = sunL * ((m.scatR * phaseR + m.scatM * phaseM) * (1.0 - direct)
			                - (m.scatR + m.scatM) * (diffuse * 0.25 / atmoPI));
			vec3 add = T * (S - S * sampleT) / max(m.ext, vec3(1e-7));
			if (t < cloudTD.y) front += add; else back += add;
		}
		T *= sampleT;
	}
	#if CREPUSCULAR_STRENGTH > 100
		front = min(front * (float(CREPUSCULAR_STRENGTH) * 0.01), fullFront);
		back = min(back * (float(CREPUSCULAR_STRENGTH) * 0.01), fullBack);
	#else
		front *= float(CREPUSCULAR_STRENGTH) * 0.01;
		back *= float(CREPUSCULAR_STRENGTH) * 0.01;
	#endif
	return (front + back * cloudTD.x) * atmoSunColor * (atmoUnit * lightScale);
}

// Subtracts the shadowed light from a colour without changing its hue when it would exceed
// it (the sky / aerial perspective integrators differ a little from this one)
vec3 CrepuscularApply(vec3 color, vec3 shadowed) {
	vec3 r = color * 0.95 / max(shadowed, vec3(1e-9));
	return color - shadowed * min(1.0, min(r.r, min(r.g, r.b)));
}

#endif
