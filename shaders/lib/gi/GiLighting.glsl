// =====================================================================================
//  GI module: light leaving the point a GI ray hits
//
//  GiHitRadiance = light sent back along the ray by the surface hit:
//   - escaped ray: sky light in its direction (clouds included),
//   - emission of the surface (light blocks, torches, specular emissive maps),
//   - sunlight on the surface (sun shadow map, stained glass tint, water, cloud shadows),
//   - light reaching the surface from everywhere else (light cache of the pack: further
//     bounces), all times the surface colour,
//  times the stained glass crossed by the ray.
//
//  Brightness scale: the constants match the original GI of the pack (deferred12 multiplies
//  the GI by 10 and by the albedo of the pixel).
//
//  Needs GiVolume.glsl, GiTrace.glsl, SkyShading or CloudSkyLookup, TintUnderwaterDepth,
//  UnpackTwo16BitFrom32Bit, SHADOW_MAP_BIAS. Uniforms: shadowtex0, shadowcolor,
//  shadowcolor1, shadowModelView, shadowProjection, colortex5 (light cache), colorSunlight,
//  worldLightVector, worldSunVector, wetness, isEyeInWater, cameraPosition,
//  cameraPosCenterDiff, altRTDiameter, viewWidth.
// =====================================================================================

#ifndef GI_LIGHTING_INC
#define GI_LIGHTING_INC

// Sun shadow map coordinates of a camera relative position
vec3 GiShadowCoord(vec3 rel) {
	vec4 p = shadowProjection * (shadowModelView * vec4(rel, 1.0));
	p.xyz /= p.w;
	float distortFactor = (1.0 - SHADOW_MAP_BIAS) + length(p.xy) * SHADOW_MAP_BIAS;
	p.xy *= 0.95 / distortFactor;
	p.z = mix(p.z, 0.5, 0.8);
	p.xyz = p.xyz * 0.5 + 0.5;
	p.xy = p.xy * (2048.0 / SHADOW_MAP_RESOLUTION) + (SHADOW_MAP_RESOLUTION - 2048.0) / SHADOW_MAP_RESOLUTION;
	return p.xyz;
}

// Sunlight reaching a surface (camera relative position, normal), before its brightness
vec3 GiSunAtHit(vec3 rel, vec3 normal) {
	if (wetness > 0.99) return vec3(0.0);
	vec3 sc = GiShadowCoord(rel);
	sc.z -= pow(dot(rel, rel), 0.35) * 1e-5 + 4e-5;
	float visibility = textureLod(shadowtex0, sc, 0.0);
	vec3 sun = TintUnderwaterDepth(vec3(visibility * saturate(dot(worldLightVector, normal))));
	if (visibility < 0.1) return sun * (1.0 - wetness);
	#ifdef GI_SUNLIGHT_STAINED_GLASS_TINT
		float glass = textureLod(shadowtex0, vec3(sc.xy - vec2(0.5, 0.0), sc.z), 0.0);
		if (glass < 0.9) {
			vec3 tint = textureLod(shadowcolor, sc.xy - vec2(0.5, 0.0), 3.0).rgb;
			sun = mix(sun * tint * tint, sun, glass);
		}
	#endif
	float water = textureLod(shadowtex0, vec3(sc.xy - vec2(0.0, 0.5), sc.z), 3.0);
	if (water < 0.9) {
		float waterDepth = textureLod(shadowcolor1, sc.xy - vec2(0.0, 0.5), 3.0).x * 256.0 - (rel.y + cameraPosition.y);
		sun /= sqrt(max(waterDepth, 0.0)) + 1.0;
	}
	#if defined VOLUMETRIC_CLOUDS && defined CLOUD_SHADOWS
		sun *= CloudShadowLookup(rel, worldLightVector);
	#endif
	return sun * (1.0 - wetness);
}

// Sky light coming from a direction
vec3 GiSkyRadiance(vec3 dir) {
	if (isEyeInWater == 1) {
		vec3 refracted = refract(dir, vec3(0.0, -1.0, 0.0), 1.3333);
		if (dot(refracted, refracted) < 0.5) return vec3(0.0);   // total internal reflection at the surface
		dir = refracted;
	}
	#if defined VOLUMETRIC_CLOUDS && defined CLOUD_SKY_LIGHTING
		vec3 sky = CloudSkyLookup(dir).rgb;
	#else
		vec3 sky = SkyShading(dir, worldSunVector);
	#endif
	sky *= saturate(dir.y * 10.0 + 1.0);
	sky = TintUnderwaterDepth(sky);
	return sky * (saturate(dir.y * 5.0) * 0.1);
}

// Light reaching a voxel face from everywhere (light cache of the pack, colortex5: one cell
// per block in a cube of altRTDiameter blocks around the camera, one cell per pixel)
vec3 GiCacheIrradiance(ivec3 voxel, vec3 normal) {
	float size = float(altRTDiameter);
	vec3 p = vec3(voxel) - giVolumeOffset + normal + cameraPosCenterDiff + 0.5 * size;
	vec3 cell = floor(clamp(p, vec3(0.0), vec3(size - 1.0)).xzy + 1e-5);
	float run = cell.x + cell.z * size;
	ivec2 texel = ivec2(mod(run, viewWidth), cell.y + floor(run / viewWidth) * size);
	vec4 packed = texelFetch(colortex5, texel, 0);
	vec3 irradiance = vec3(UnpackTwo16BitFrom32Bit(packed.y).x, UnpackTwo16BitFrom32Bit(packed.z).x, UnpackTwo16BitFrom32Bit(packed.w).x);
	return pow(irradiance, vec3(8.0));
}

// Glossy surfaces (specular maps) send more sunlight toward the mirror direction
float GiSunSpecularFactor(vec3 specular, vec3 dir, vec3 normal) {
	#ifdef FULL_RT_REFLECTIONS
		float x = clamp(pow(specular.x, 0.125) + specular.y, 0.0, 1.0);
	#else
		float x = clamp(specular.x * 10.0 - 7.0, 0.0, 1.0);
	#endif
	float mirror = max((dot(worldLightVector, reflect(dir, normal)) - x * 0.9) * 10.0, 0.0);
	return 1.0 + (-x + 25.0 * x * mirror) * (specular.y * 0.98 + 0.02);
}

// Light sent back along a GI ray by what it hit.
// skyLightFix, sunLightFix: leak fixes of the pixel (0 in caves, from the sky light map)
vec3 GiHitRadiance(GiHit hit, vec3 origin, vec3 dir, float skyLightFix, float sunLightFix) {
	if (hit.escaped)
		return GiSkyRadiance(dir) * skyLightFix * hit.transmittance;
	vec3 radiance = hit.emission;
	if (hit.id != giIdSmallLight) {
		radiance += GiCacheIrradiance(hit.voxel, hit.normal) * hit.albedo * 2.4;
		if (sunLightFix > 0.01) {
			vec3 rel = GiRelPos(origin + dir * hit.dist);
			vec3 sun = GiSunAtHit(rel, hit.normal) * (SUNLIGHT_BRIGHTNESS * 2.4 * sunLightFix);
			radiance += sun * hit.albedo * colorSunlight * GiSunSpecularFactor(hit.specular, dir, hit.normal);
		}
	}
	return radiance * hit.transmittance;
}

#endif
