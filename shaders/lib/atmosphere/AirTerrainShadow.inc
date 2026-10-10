// =====================================================================================
//  Terrain shadow of the lower air and near mist (replaces the old godrays of the pack)
//
//  The air light integration (Crepuscular.inc) samples the first blocks of every view ray
//  in a segment of its own, with the shadow of the terrain from the sun shadow map (stained
//  glass tints the light). In that segment:
//   - the air and the valley haze in the shadow of the terrain no longer scatter sunlight
//     (valleys in the shade of a ridge stay dark),
//   - a thin near mist (strength VOLUMETRIC_LIGHT_STRENGTH) scatters the sunlight: shafts
//     through the leaves, windows and ridges, coloured by stained glass. Real air is far too
//     clear for visible shafts over a hundred blocks: the mist stands for the local dust and
//     humidity that make them visible.
//
//  Needs SHADOW_MAP_RESOLUTION, SHADOW_MAP_BIAS and the uniforms shadowModelView,
//  shadowProjection, shadowtex0 (sampler2DShadow), shadowcolor. Include before Crepuscular.inc.
// =====================================================================================

#if defined GODRAYS && defined AB_AIR_SHAFTS && !defined AIR_TERRAIN_SHADOW_INC
#define AIR_TERRAIN_SHADOW_INC
#define AIR_TERRAIN_SHADOW

const int airNearSteps = 8;   // samples of the near segment (stratified, filtered in time)
const float airMistSigma = 0.00025 * VOLUMETRIC_LIGHT_STRENGTH;   // near mist extinction, per block (fully lit: +5 % at noon, +14 % at sunset)

#ifdef CLOUD_PREVIEW
// offline preview: flat ground, no shadow map
const float shadowDistance = 240.0;
vec3 AirTerrainVisibility(vec3 rel) { return vec3(1.0); }
#else
const float shadowDistance = 240.0; // Shadow distance. Set lower if you prefer nicer close shadows. Set higher if you prefer nicer distant shadows. [80.0 120.0 160.0 200.0 240.0 280.0 320.0 360.0 400.0 440.0 480.0 520.0 560.0 600.0 640.0]

// Sunlight reaching a camera relative position past the terrain (and through stained glass),
// 1 outside the shadow map
vec3 AirTerrainVisibility(vec3 rel) {
	vec4 sp = shadowProjection * (shadowModelView * vec4(rel, 1.0));
	sp.xyz /= sp.w;
	if (any(greaterThan(abs(sp.xyz), vec3(1.0)))) return vec3(1.0);
	float distortFactor = (1.0 - SHADOW_MAP_BIAS) + length(sp.xy) * SHADOW_MAP_BIAS;
	sp.xy *= 0.95 / distortFactor;
	sp.z = mix(sp.z, 0.5, 0.8);
	sp.xyz = sp.xyz * 0.5 + 0.5;
	sp.xy = sp.xy * (2048.0 / SHADOW_MAP_RESOLUTION) + (SHADOW_MAP_RESOLUTION - 2048.0) / SHADOW_MAP_RESOLUTION;
	float s = textureLod(shadowtex0, vec3(sp.xy, sp.z + 1e-6), 0.0);
	if (s < 0.01) return vec3(0.0);
	vec3 vis = vec3(s);
	#ifdef GODRAYS_STAINED_GLASS_TINT
		vec2 glassPos = sp.xy - vec2(0.5, 0.0);
		float g = textureLod(shadowtex0, vec3(glassPos, sp.z + 1e-6), 0.0);
		if (g < 0.9) {
			vec3 tint = textureLod(shadowcolor, glassPos, 0.0).rgb;
			vis = mix(vis * tint * tint, vis, g);
		}
	#endif
	return vis;
}
#endif

// Phase function of the mist: forward peak and an isotropic part
float AirMistPhase(float c) {
	const float g = 0.6;
	float d = 1.0 + g * g - 2.0 * g * c;
	return 0.5 * (1.0 - g * g) / (4.0 * 3.14159265 * d * sqrt(d)) + 0.5 / (4.0 * 3.14159265);
}

#endif
