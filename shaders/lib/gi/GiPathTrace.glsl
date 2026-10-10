// =====================================================================================
//  GI module: one bounce of diffuse light per pixel (GI_RAY_COUNT rays)
//
//  The base of the ReSTIR GI method (GI_METHOD 1): each ray leaves the surface in a
//  cosine weighted direction, so a diffuse surface averages the light of its hits with
//  equal weights. Spatiotemporal reuse of these samples comes next (plan step E2).
//
//  Output: rgb = light reaching the surface (scale of the original GI of the pack),
//          a = mean hit distance / 10, saturated.
// =====================================================================================

#ifndef GI_PATH_TRACE_INC
#define GI_PATH_TRACE_INC

#include "/lib/gi/GiVolume.glsl"
#include "/lib/gi/GiSampling.glsl"
#include "/lib/gi/GiTrace.glsl"
#include "/lib/gi/GiLighting.glsl"

// rel: camera relative position of the pixel; normal, geoNormal: world normals (with and
// without the normal map); viewDir: from the camera to the pixel; skyLight: sky light map
// of the pixel; parallaxOffset: depth of the parallax displacement
vec4 GiPathTracePixel(vec3 rel, vec3 normal, vec3 geoNormal, vec3 viewDir, float skyLight, float parallaxOffset, ivec2 pixel) {
	// light leak fixes: underground surfaces (no sky light) get no sunlight and no sky light
	// from the GI, so light cannot leak through the edge of the volume or thin walls
	float sunLightFix = 1.0, skyLightFix = 1.0;
	if (isEyeInWater < 1) {
		#ifdef SUNLIGHT_LEAK_FIX
			sunLightFix = saturate(skyLight * 100.0);
		#endif
		#ifdef CAVE_GI_LEAK_FIX
			skyLightFix = saturate(skyLight * 10.0);
		#endif
	}
	sunLightFix *= skyLightFix;

	// ray origin: off the surface, and back toward the camera on parallax surfaces
	vec3 start = rel + normal * (0.0001 * length(rel))
	           - viewDir * (parallaxOffset * 0.4 / (saturate(dot(geoNormal, -viewDir)) + 1e-6) + 0.0008);
	vec3 origin = clamp(GiVolumePos(start), vec3(-1.0), vec3(RAY_TRACING_DIAMETER - 1.0));

	vec3 noise = GiBlueNoise(pixel);
	vec4 sum = vec4(0.0);
	for (int k = 0; k < GI_RAY_COUNT; k++) {
		vec3 dir = GiCosineDirection(normal, GiSampleOffset(noise.xy, k));
		if (dot(dir, geoNormal) < 0.0) dir = reflect(dir, geoNormal);   // normal maps: stay above the surface
		GiHit hit = GiTraceRay(origin, dir, DIFFUSE_TRACE_LENGTH);
		sum += vec4(hit.originLight + GiHitRadiance(hit, origin, dir, skyLightFix, sunLightFix), hit.dist);
	}
	sum /= float(GI_RAY_COUNT);
	sum.a = saturate(sum.a * 0.1);
	return sum;
}

#endif
