// =====================================================================================
//  GI method 1: ReSTIR GI (Ouyang et al. 2021, "ReSTIR GI: Path Resampling for Real-Time
//  Path Tracing")
//
//  Every frame, at the internal resolution:
//   1. temporal pass (GiRestirTemporal, deferred_a):
//       - GI_RAY_COUNT new candidates per pixel: cosine weighted rays through the voxels,
//       - merged with the reservoir of the same surface last frame (reprojected, history
//         capped to GI_RESTIR_HISTORY candidates),
//       - one pixel in four per frame re-traces its previous sample: its light is refreshed
//         (a torch put out, the sun moving) and it is dropped when something now blocks it,
//       - the result is kept for the next frame;
//   2. spatial pass (GiRestirSpatial, deferred_b):
//       - merged with the reservoirs of GI_RESTIR_SPATIAL_SAMPLES neighbours on a similar
//         surface (Jacobian of the reconnection),
//       - a sample taken from a neighbour must be visible from the pixel (one ray through
//         the voxels), otherwise the pixel keeps its own reservoir,
//       - shading: radiance x cos / pi x W, plus the light of a torch holding the ray origin.
//  GI_RESTIR_REUSE: 0 = new candidates only, 1 = + temporal reuse, 2 = + spatial reuse.
//
//  Output giRestirOut: rgb = light reaching the surface (deferred12 scale), a = distance to
//  the sample / 10. Reservoirs: two pairs of rgba32ui images, swapped every frame.
//
//  Needs GiComputeHeader.glsl.
// =====================================================================================

#ifndef GI_RESTIR_INC
#define GI_RESTIR_INC

layout(rgba32ui) uniform uimage2D giResA0;
layout(rgba32ui) uniform uimage2D giResB0;
layout(rgba32ui) uniform uimage2D giResA1;
layout(rgba32ui) uniform uimage2D giResB1;
layout(rgba16f) uniform image2D giRestirOut;

const float giRestirSpatialRadius = 24.0;   // pixels (internal resolution)

// Reservoir buffer written this frame: 0 on even frames
bool GiCurrentIsFirst() {
	return (frameCounter & 1) == 0;
}

void GiStoreReservoir(bool first, ivec2 p, GiReservoir r, vec3 surfNormal, float surfDist) {
	uvec4 a, b;
	GiReservoirPack(r, surfNormal, surfDist, a, b);
	if (first) {
		imageStore(giResA0, p, a);
		imageStore(giResB0, p, b);
	} else {
		imageStore(giResA1, p, a);
		imageStore(giResB1, p, b);
	}
}

GiReservoir GiLoadReservoir(bool first, ivec2 p, out vec3 surfNormal, out float surfDist) {
	uvec4 a = first ? imageLoad(giResA0, p) : imageLoad(giResA1, p);
	uvec4 b = first ? imageLoad(giResB0, p) : imageLoad(giResB1, p);
	return GiReservoirUnpack(a, b, surfNormal, surfDist);
}

GiSample GiSampleFromHit(GiHit hit, vec3 origin, vec3 dir, float skyLightFix, float sunLightFix) {
	GiSample s;
	s.pos = GiRelPos(origin) + dir * (hit.escaped ? giSkyDistance : hit.dist);
	s.normal = hit.escaped ? -dir : hit.normal;
	s.radiance = GiHitRadiance(hit, origin, dir, skyLightFix, sunLightFix);
	return s;
}

// True when the sample is the first thing a ray from origin toward it meets; hit receives
// that ray's hit
bool GiTraceToSample(vec3 origin, GiSample s, out GiHit hit, out vec3 dir) {
	vec3 d = s.pos - GiRelPos(origin);
	float len = length(d);
	dir = d / len;
	hit = GiTraceRay(origin, dir, DIFFUSE_TRACE_LENGTH);
	if (len > giSkyDistance * 0.5) return hit.escaped;
	return !hit.escaped && abs(hit.dist - len) < 0.5 + 0.02 * len;
}

// Reservoir of the same surface last frame, moved to the current camera; false when the
// surface was not visible there
bool GiLoadPrevious(GiSurface surf, out GiReservoir prev) {
	vec3 prevRel = surf.rel + cameraPositionDiff;
	vec4 c = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(prevRel, 1.0));
	if (c.w <= 0.0) return false;
	ivec2 p = ivec2(floor(((c.xy / c.w) * 0.25 + 0.25) * vec2(viewWidth, viewHeight)));
	if (any(lessThan(p, ivec2(0))) || any(greaterThanEqual(p, GiInternalSize()))) return false;
	vec3 n;
	float d;
	prev = GiLoadReservoir(!GiCurrentIsFirst(), p, n, d);
	float expected = length(prevRel);
	if (d < 0.0 || prev.M <= 0.0 || abs(d - expected) > 0.1 * expected + 0.1 || dot(n, surf.normal) < 0.9)
		return false;
	prev.s.pos -= cameraPositionDiff;
	return true;
}

void GiRestirTemporal(ivec2 px) {
	if (any(greaterThanEqual(px, GiInternalSize()))) return;
	bool first = GiCurrentIsFirst();
	GiSurface surf = GiReadSurface(px);
	if (!surf.valid) {
		GiStoreReservoir(first, px, GiReservoirEmpty(), vec3(0.0, 1.0, 0.0), -1.0);
		imageStore(giRestirOut, px, vec4(0.0));
		return;
	}
	float skyLightFix, sunLightFix;
	GiLeakFixes(surf, skyLightFix, sunLightFix);
	vec3 origin = GiRayOrigin(surf);
	GiRng rng = GiRngInit(px, frameCounter, 0u);
	vec3 noise = GiBlueNoise(px);

	// new candidates
	GiReservoir r = GiReservoirEmpty();
	vec3 originLight = vec3(0.0);
	for (int k = 0; k < GI_RAY_COUNT; k++) {
		vec3 dir = GiCosineDirection(surf.normal, GiSampleOffset(noise.xy, k));
		if (dot(dir, surf.geoNormal) < 0.0) dir = reflect(dir, surf.geoNormal);   // normal maps: stay above the surface
		GiHit hit = GiTraceRay(origin, dir, DIFFUSE_TRACE_LENGTH);
		if (k == 0) originLight = hit.originLight;
		GiSample cand = GiSampleFromHit(hit, origin, dir, skyLightFix, sunLightFix);
		if (k == 0) r.s = cand;
		float sourcePdf = max(dot(surf.normal, dir), 1e-4) / giPi;
		GiReservoirAdd(r, cand, GiTarget(surf.rel, surf.normal, cand) / sourcePdf, 1.0, GiRandom(rng));
	}

	#if GI_RESTIR_REUSE >= 1
		// the same surface last frame
		GiReservoir prev;
		if (GiLoadPrevious(surf, prev)) {
			bool keep = true;
			if (((px.x + 2 * px.y + frameCounter) & 3) == 0) {
				GiHit hit;
				vec3 dir;
				keep = GiTraceToSample(origin, prev.s, hit, dir);
				if (keep) prev.s.radiance = GiHitRadiance(hit, origin, dir, skyLightFix, sunLightFix);
			}
			float target = GiTarget(surf.rel, surf.normal, prev.s);
			if (keep && target > 0.0) {
				float M = min(prev.M, GI_RESTIR_HISTORY);
				GiReservoirAdd(r, prev.s, target * prev.W * M, M, GiRandom(rng));
			}
		}
	#endif

	GiReservoirFinish(r, GiTarget(surf.rel, surf.normal, r.s));
	GiStoreReservoir(first, px, r, surf.normal, surf.dist);
	imageStore(giRestirOut, px, vec4(originLight, 0.0));
}

void GiRestirSpatial(ivec2 px) {
	if (any(greaterThanEqual(px, GiInternalSize()))) return;
	GiSurface surf = GiReadSurface(px);
	if (!surf.valid) return;
	bool first = GiCurrentIsFirst();
	vec3 n;
	float d;
	GiReservoir own = GiLoadReservoir(first, px, n, d);
	GiReservoir r = own;

	#if GI_RESTIR_REUSE >= 2
		GiRng rng = GiRngInit(px, frameCounter, 1u);
		r.wSum = GiTarget(surf.rel, surf.normal, own.s) * own.W * own.M;
		bool fromNeighbour = false;
		float angle = GiRandom(rng) * 2.0 * giPi;
		for (int k = 0; k < GI_RESTIR_SPATIAL_SAMPLES; k++) {
			angle += 2.39996323;   // golden angle: neighbours spread around the pixel
			float radius = giRestirSpatialRadius * sqrt(GiRandom(rng)) + 1.0;
			ivec2 q = px + ivec2(round(radius * vec2(cos(angle), sin(angle))));
			if (any(lessThan(q, ivec2(0))) || any(greaterThanEqual(q, GiInternalSize()))) continue;
			vec3 qn;
			float qd;
			GiReservoir nb = GiLoadReservoir(first, q, qn, qd);
			if (qd < 0.0 || nb.M <= 0.0 || nb.W <= 0.0) continue;
			if (dot(qn, surf.normal) < 0.9 || abs(qd - surf.dist) > 0.1 * surf.dist) continue;
			GiSurface qs = GiReadSurface(q);
			if (!qs.valid) continue;
			float w = GiTarget(surf.rel, surf.normal, nb.s) * GiJacobian(surf.rel, qs.rel, nb.s) * nb.W * nb.M;
			if (GiReservoirAdd(r, nb.s, w, nb.M, GiRandom(rng))) fromNeighbour = true;
		}
		GiReservoirFinish(r, GiTarget(surf.rel, surf.normal, r.s));
		if (fromNeighbour) {
			GiHit hit;
			vec3 dir;
			if (!GiTraceToSample(GiRayOrigin(surf), r.s, hit, dir)) r = own;
		}
	#endif

	vec3 toSample = r.s.pos - surf.rel;
	float len = length(toSample);
	float cosTheta = max(dot(surf.normal, toSample / max(len, 1e-6)), 0.0);
	vec3 gi = r.s.radiance * (cosTheta / giPi) * r.W;
	vec4 outData = imageLoad(giRestirOut, px);
	imageStore(giRestirOut, px, vec4(outData.rgb + gi, giSat(len * 0.1)));
}

#endif
