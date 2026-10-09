// =====================================================================================
//  Sky / atmosphere entry points used by the pack. ATMOSPHERE_MODEL selects the original
//  SEUS sky (0) or the physical atmosphere (1, lib/atmosphere/Atmosphere.inc).
//  Needs: cameraPosition, wetness, nightBrightness.
// =====================================================================================

#ifndef SKY_INC
#define SKY_INC

#include "/lib/atmosphere/SkySEUS.inc"   // also PhaseMie, used by other effects

#if ATMOSPHERE_MODEL == 1
	#define ATMOSPHERE_LUTS
	#include "/lib/atmosphere/Atmosphere.inc"
#endif

// Sky radiance seen from the camera toward dir (deferred12 sky units)
vec3 SkyShading(vec3 worldViewVector, vec3 worldSunVector) {
	#if ATMOSPHERE_MODEL == 1
		return AtmoSkyRadiance(worldViewVector, worldSunVector, nightBrightness);
	#else
		return SkyShadingSEUS(worldViewVector, worldSunVector);
	#endif
}

// Transmittance of the atmosphere from the camera to space (sun disc)
vec3 SkyTransmittance(vec3 dir) {
	#if ATMOSPHERE_MODEL == 1
		return AtmoViewTransmittance(dir);
	#else
		return AtmosphereAbsorption(dir, AtmosphereExtent);
	#endif
}

#endif
