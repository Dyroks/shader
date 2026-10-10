// =====================================================================================
//  GI method 1: ReSTIR GI (Ouyang et al. 2021, "ReSTIR GI: Path Resampling for Real-Time
//  Path Tracing")
//
//  Every frame, at the internal resolution:
//   1. temporal pass (GiRestirTemporal, deferred_a):
//       - GI_RAY_COUNT new candidates per pixel: cosine weighted rays through the voxels,
//       - merged with the reservoir of the same surface last frame (reprojected onto the
//         same plane, history capped to GI_RESTIR_HISTORY frames),
//       - one pixel in four per frame re-traces its previous sample: its light is refreshed
//         (a torch put out, the sun moving) and it is dropped when something now blocks it,
//       - the result is kept for the next frame;
//   2. spatial pass (GiRestirSpatial, deferred_b):
//       - merged with the reservoirs of GI_RESTIR_SPATIAL_SAMPLES neighbours on the same
//         plane (Jacobian of the reconnection); the sample of a neighbour must be visible
//         from the pixel (one ray through the voxels per neighbour that can contribute),
//       - W normalised by the candidates that could have produced the chosen sample (no
//         darkening where the neighbours' samples do not apply, e.g. near inner corners),
//       - shading: radiance x cos / pi x W, plus the light of a torch holding the ray origin.
//  The visible point of a pixel is the origin of its rays (GiRayOrigin): one candidate gives
//  exactly the radiance it found.
//  GI_RESTIR_REUSE: 0 = new candidates only, 1 = + temporal reuse, 2 = + spatial reuse.
//
//  Output: the GI area of colortex7 (colorimg7, upper left quarter of the screen buffers, the
//  place deferred.fsh used to write it): rgb = light reaching the surface (deferred12 scale),
//  a = distance to the sample / 10. Reservoirs: shader storage buffer 0, two per pixel,
//  swapped every frame (Iris keeps only 16 custom images: storage buffers do not count).
//
//  Needs GiComputeHeader.glsl.
// =====================================================================================

#ifndef GI_RESTIR_INC
#define GI_RESTIR_INC

struct GiPixelData {
	uvec4 a0, b0;    // reservoir written on even frames
	uvec4 a1, b1;    // reservoir written on odd frames
	vec4 originLight;   // light of a torch holding the ray origin (temporal pass -> spatial pass)
};
layout(std430, binding = 0) buffer GiRestirBuffer {
	GiPixelData giPixels[];   // internal resolution, row by row
};
layout(rgba16f) uniform writeonly image2D colorimg7;

const float giRestirSpatialRadius = 24.0;   // pixels (internal resolution)

// Reservoir buffer written this frame: 0 on even frames
bool GiCurrentIsFirst() {
	return (frameCounter & 1) == 0;
}

int GiPixelIndex(ivec2 p) {
	return p.y * GiInternalSize().x + p.x;
}

void GiStoreReservoir(bool first, ivec2 p, GiReservoir r, vec3 surfNormal, float surfPlane) {
	uvec4 a, b;
	GiReservoirPack(r, surfNormal, surfPlane, a, b);
	int i = GiPixelIndex(p);
	if (first) {
		giPixels[i].a0 = a;
		giPixels[i].b0 = b;
	} else {
		giPixels[i].a1 = a;
		giPixels[i].b1 = b;
	}
}

GiReservoir GiLoadReservoir(bool first, ivec2 p, out vec3 surfNormal, out float surfPlane) {
	int i = GiPixelIndex(p);
	uvec4 a = first ? giPixels[i].a0 : giPixels[i].a1;
	uvec4 b = first ? giPixels[i].b0 : giPixels[i].b1;
	return GiReservoirUnpack(a, b, surfNormal, surfPlane);
}

// Result into the GI area of colortex7 (same pixel mapping as deferred.fsh: one row up)
void GiStoreResult(ivec2 p, vec4 v) {
	imageStore(colorimg7, ivec2(p.x, p.y + int(floor(viewHeight * 0.5)) + 1), v);
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
	dir = len > 1e-4 ? d / len : vec3(0.0, 1.0, 0.0);
	hit = GiTraceRay(origin, dir, DIFFUSE_TRACE_LENGTH);
	if (len > giSkyDistance * 0.5) return hit.escaped;
	return !hit.escaped && abs(hit.dist - len) < 0.3 + 0.01 * len;
}

// Same surface: normals within 25 degrees, and the other point on the plane of this one
bool GiSamePlane(vec3 n, float plane, vec3 otherNormal, vec3 otherRel, float dist) {
	return dot(n, otherNormal) > 0.9 && abs(dot(n, otherRel) - plane) < 0.02 * dist + 0.05;
}

// Reservoir of the same surface last frame, moved to the current camera; false when the
// surface was not visible there
bool GiLoadPrevious(GiSurface surf, out GiReservoir prev) {
	if (frameCounter == 0) return false;   // the previous buffer holds nothing yet
	vec3 prevRel = surf.rel + cameraPositionDiff;
	vec4 c = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(prevRel, 1.0));
	if (!(c.w > 0.0)) return false;
	ivec2 p = ivec2(floor(((c.xy / c.w) * 0.25 + 0.25) * vec2(viewWidth, viewHeight)));
	if (any(lessThan(p, ivec2(0))) || any(greaterThanEqual(p, GiInternalSize()))) return false;
	vec3 n;
	float plane;
	prev = GiLoadReservoir(!GiCurrentIsFirst(), p, n, plane);
	if (!GiReservoirValid(prev) || !GiSamePlane(n, plane, surf.normal, prevRel, surf.dist)) return false;
	prev.s.pos -= cameraPositionDiff;
	return true;
}

void GiRestirTemporal(ivec2 px) {
	if (any(greaterThanEqual(px, GiInternalSize()))) return;
	bool first = GiCurrentIsFirst();
	GiSurface surf = GiReadSurface(px);
	if (!surf.valid) {
		GiStoreReservoir(first, px, GiReservoirEmpty(), vec3(0.0, 1.0, 0.0), 0.0);
		return;
	}
	float skyLightFix, sunLightFix;
	GiLeakFixes(surf, skyLightFix, sunLightFix);
	vec3 origin = GiRayOrigin(surf);
	vec3 x0 = GiRelPos(origin);   // visible point
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
		GiReservoirAdd(r, cand, GiTarget(x0, surf.normal, cand) / sourcePdf, 1.0, GiRandom(rng));
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
			float target = GiTarget(x0, surf.normal, prev.s);
			if (keep && target > 0.0) {
				float M = min(prev.M, GI_RESTIR_HISTORY * float(GI_RAY_COUNT));
				GiReservoirAdd(r, prev.s, target * prev.W * M, M, GiRandom(rng));
			}
		}
	#endif

	GiReservoirFinish(r, GiTarget(x0, surf.normal, r.s));
	GiStoreReservoir(first, px, r, surf.normal, dot(surf.normal, surf.rel));
	giPixels[GiPixelIndex(px)].originLight = vec4(originLight, 0.0);
}

void GiRestirSpatial(ivec2 px) {
	if (any(greaterThanEqual(px, GiInternalSize()))) return;
	GiSurface surf = GiReadSurface(px);
	if (!surf.valid) return;
	bool first = GiCurrentIsFirst();
	vec3 origin = GiRayOrigin(surf);
	vec3 x0 = GiRelPos(origin);
	vec3 n;
	float plane;
	GiReservoir r = GiLoadReservoir(first, px, n, plane);
	if (!GiReservoirValid(r)) r = GiReservoirEmpty();

	#if GI_RESTIR_REUSE >= 2
		GiRng rng = GiRngInit(px, frameCounter, 1u);
		r.wSum = GiTarget(x0, surf.normal, r.s) * r.W * r.M;
		float ownM = r.M;
		// neighbours merged: visible point, normal and M, to normalise by the ones that
		// could have found the chosen sample
		vec3 nbPoint[GI_RESTIR_SPATIAL_SAMPLES];
		vec3 nbNormal[GI_RESTIR_SPATIAL_SAMPLES];
		float nbM[GI_RESTIR_SPATIAL_SAMPLES];
		int count = 0;
		float surfPlane = dot(surf.normal, surf.rel);
		float angle = GiRandom(rng) * 2.0 * giPi;
		for (int k = 0; k < GI_RESTIR_SPATIAL_SAMPLES; k++) {
			angle += 2.39996323;   // golden angle: neighbours spread around the pixel
			float radius = giRestirSpatialRadius * sqrt(GiRandom(rng)) + 1.0;
			ivec2 q = px + ivec2(round(radius * vec2(cos(angle), sin(angle))));
			if (any(lessThan(q, ivec2(0))) || any(greaterThanEqual(q, GiInternalSize()))) continue;
			vec3 qn;
			float qPlane;
			GiReservoir nb = GiLoadReservoir(first, q, qn, qPlane);
			if (!GiReservoirValid(nb)) continue;
			GiSurface qs = GiReadSurface(q);
			if (!qs.valid || !GiSamePlane(surf.normal, surfPlane, qs.normal, qs.rel, surf.dist)) continue;
			vec3 q0 = GiRelPos(GiRayOrigin(qs));
			nbPoint[count] = q0;
			nbNormal[count] = qs.normal;
			nbM[count] = nb.M;
			count++;
			float w = GiTarget(x0, surf.normal, nb.s) * GiJacobian(x0, q0, nb.s) * nb.W * nb.M;
			if (w > 0.0) {
				GiHit hit;
				vec3 dir;
				if (!GiTraceToSample(origin, nb.s, hit, dir)) w = 0.0;   // hidden from this pixel
			}
			GiReservoirAdd(r, nb.s, w, nb.M, GiRandom(rng));
		}
		// Z: candidates whose visible point could have produced the chosen sample
		float Z = ownM;
		for (int k = 0; k < count; k++) {
			vec3 d = r.s.pos - nbPoint[k];
			if (dot(nbNormal[k], d) > 0.0 && dot(r.s.normal, -d) > 0.0) Z += nbM[k];
		}
		GiReservoirFinishZ(r, GiTarget(x0, surf.normal, r.s), Z);
	#endif

	vec3 toSample = r.s.pos - x0;
	float len = length(toSample);
	float cosTheta = max(dot(surf.normal, toSample / max(len, 1e-6)), 0.0);
	vec3 gi = r.s.radiance * (cosTheta / giPi) * r.W;
	gi = all(lessThan(gi, vec3(6e4))) && all(greaterThanEqual(gi, vec3(0.0))) ? gi : vec3(0.0);   // NaN or overflow
	GiStoreResult(px, vec4(giPixels[GiPixelIndex(px)].originLight.rgb + gi, giSat(len * 0.1)));
}

#endif
