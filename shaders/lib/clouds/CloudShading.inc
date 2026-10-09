// =====================================================================================
//  Volumetric clouds - colour of the clouds from the ray march output
//
//  Shared by the composition (composite4.fsh) and the sky capture (begin_d.csh).
//  Needs CloudCommon.inc, lib/atmosphere/SkySEUS.inc, and the uniforms wetness,
//  nightBrightness (SkySEUS).
// =====================================================================================

#ifndef CLOUD_SHADING_INC
#define CLOUD_SHADING_INC

// data   : x = sun scattering, y = sky scattering, z = transmittance (ray march / history)
// depth  : transmittance weighted distance of the clouds (blocks)
// dir    : world view direction, camY: camera altitude
// sunVec : sun direction, moonColor: colour of the moon light (the pack's colorSunlight at night)
// skyAmbient: average sky radiance
// Returns the radiance added in front of the background (background * T + result), in the
// sky units of deferred12 (SkyShading).
vec3 CloudShade(vec3 data, float depth, vec3 dir, float camY, vec3 sunVec, vec3 moonColor, vec3 skyAmbient) {
	float T = CloudSat(data.z);

	// Light used by the ray march: sun (colour at the cloud altitude) or moon
	vec3 lightColor;
	if (sunVec.y > cloudSunModeLimit) {
		float alt = camY + dir.y * depth + depth * depth / (2.0 * cloudPlanetR);
		lightColor = CloudSunColorAtAltitude(sunVec.y, alt, wetness);
	} else {
		lightColor = moonColor;
	}
	// 24 * colour = radiance of a white surface facing the light in this pack -> irradiance 24 pi
	vec3 light = lightColor * (24.0 * cloudPI * SUNLIGHT_BRIGHTNESS * CLOUD_SUNLIGHT) * max(data.x, 0.0)
	           + skyAmbient * (max(data.y, 0.0) * CLOUD_AMBIENT);

	#ifdef CLOUD_AERIAL_PERSPECTIVE
		// The SEUS atmosphere assumes a camera on the ground and gets very dense for downward
		// rays: use the mirrored upward direction until the atmosphere is replaced (phase 4).
		vec3 apDir = dir;
		apDir.y = max(abs(apDir.y), 0.01);
		float apDepth = min(depth / cloudScale * 0.0012, AtmosphereExtent * 0.95);
		float LdotV = dot(apDir, sunVec);
		float LdotV2 = LdotV * LdotV + 1.0;
		vec3 absorb = AtmosphereAbsorption(apDir, apDepth);
		vec3 haze = Atmosphere(apDir, sunVec, 0.25, apDepth, LdotV, LdotV2);
		haze += Atmosphere(apDir, -sunVec, 0.25, apDepth, -LdotV, LdotV2) * nightBrightness;
		return light * absorb + haze * (1.0 - T);
	#else
		return light;
	#endif
}

// Average sky radiance over the upper hemisphere (lights the clouds). Meant for vertex
// shaders: 17 SkyShading evaluations.
vec3 CloudAverageSkyRadiance(vec3 sunVec) {
	vec3 a = SkyShading(vec3(0.0, 1.0, 0.0), sunVec);
	for (int i = 0; i < 8; i++) {
		float an = float(i) * 0.785398;
		a += SkyShading(normalize(vec3(cos(an), 0.25, sin(an))), sunVec);
		a += SkyShading(normalize(vec3(cos(an + 0.39), 1.0, sin(an + 0.39))), sunVec);
	}
	return a / 17.0;
}

#endif
