// =====================================================================================
//  GI module: reservoirs of ReSTIR GI (Ouyang et al. 2021)
//
//  A sample is a point found by a GI ray (or a far point along an escaped ray) with the
//  light it sends back. A reservoir keeps one sample chosen among M candidates with a
//  probability proportional to their weight, and W, the weight that makes
//  radiance x cos / pi x W an unbiased estimate of the light reaching the visible point.
//
//  Target function at a visible point x (normal n): luminance of the sample's light times
//  the cosine toward the sample. Reusing a sample found from another visible point
//  multiplies its weight by the Jacobian of the reconnection (ratio of solid angles).
// =====================================================================================

#ifndef GI_RESERVOIR_INC
#define GI_RESERVOIR_INC

const float giSkyDistance = 10000.0;   // escaped rays: sample placed this far along the ray

struct GiSample {
	vec3 pos;        // camera relative position
	vec3 normal;     // normal at the sample (minus the ray direction for the sky)
	vec3 radiance;   // light sent toward the visible point
};

struct GiReservoir {
	GiSample s;
	float wSum;      // sum of the candidate weights (while combining)
	float M;         // number of candidates behind the reservoir
	float W;         // unbiased contribution weight of s
};

GiReservoir GiReservoirEmpty() {
	GiReservoir r;
	r.s = GiSample(vec3(0.0), vec3(0.0, 1.0, 0.0), vec3(0.0));
	r.wSum = 0.0;
	r.M = 0.0;
	r.W = 0.0;
	return r;
}

float GiTarget(vec3 x, vec3 n, GiSample s) {
	vec3 d = s.pos - x;
	float c = dot(n, d);
	if (c <= 0.0) return 0.0;
	return GiLuminance(s.radiance) * c * inversesqrt(dot(d, d));
}

// Streaming resampling: adds a candidate of weight w standing for M candidates; true when
// it becomes the chosen sample
bool GiReservoirAdd(inout GiReservoir r, GiSample s, float w, float M, float u) {
	r.wSum += w;
	r.M += M;
	if (w > 0.0 && u * r.wSum < w) {
		r.s = s;
		return true;
	}
	return false;
}

void GiReservoirFinish(inout GiReservoir r, float target) {
	r.W = target > 0.0 && r.M > 0.0 ? r.wSum / (r.M * target) : 0.0;
}

// Ratio of the solid angle densities of a sample seen from xTo and from xFrom (the visible
// point that found it); 0 when the sample's surface faces away from xTo
float GiJacobian(vec3 xTo, vec3 xFrom, GiSample s) {
	vec3 dTo = xTo - s.pos;
	vec3 dFrom = xFrom - s.pos;
	float lTo = dot(dTo, dTo);
	float lFrom = dot(dFrom, dFrom);
	float cTo = dot(s.normal, dTo) * inversesqrt(lTo);
	float cFrom = abs(dot(s.normal, dFrom)) * inversesqrt(lFrom);
	if (cTo <= 0.0 || cFrom < 1e-3) return 0.0;
	float j = (cTo / cFrom) * (lFrom / lTo);
	return j > 10.0 ? 0.0 : j;   // very different geometry: not a useful candidate
}

// Storage in two rgba32ui texels:
//  a: xyz = sample position (float bits), w = sample normal (8:8) | surface normal (8:8)
//  b: x = radiance rg (half), y = radiance b, M (half), z = W (float bits),
//     w = distance of the visible point (float bits, < 0: no surface)
void GiReservoirPack(GiReservoir r, vec3 surfNormal, float surfDist, out uvec4 a, out uvec4 b) {
	a = uvec4(floatBitsToUint(r.s.pos), GiPackNormal8(r.s.normal) | (GiPackNormal8(surfNormal) << 16u));
	b = uvec4(packHalf2x16(r.s.radiance.rg), packHalf2x16(vec2(r.s.radiance.b, r.M)), floatBitsToUint(r.W), floatBitsToUint(surfDist));
}

GiReservoir GiReservoirUnpack(uvec4 a, uvec4 b, out vec3 surfNormal, out float surfDist) {
	GiReservoir r;
	r.s.pos = uintBitsToFloat(a.xyz);
	r.s.normal = GiUnpackNormal8(a.w & 65535u);
	surfNormal = GiUnpackNormal8(a.w >> 16u);
	vec2 bm = unpackHalf2x16(b.y);
	r.s.radiance = vec3(unpackHalf2x16(b.x), bm.x);
	r.M = bm.y;
	r.W = uintBitsToFloat(b.z);
	r.wSum = 0.0;
	surfDist = uintBitsToFloat(b.w);
	return r;
}

#endif
