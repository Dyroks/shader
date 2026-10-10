// =====================================================================================
//  GI module: small shared helpers (no dependency on the rest of the pack)
// =====================================================================================

#ifndef GI_COMMON_INC
#define GI_COMMON_INC

const float giPi = 3.14159265359;

float giSat(float x) { return clamp(x, 0.0, 1.0); }
vec3 giSat(vec3 x) { return clamp(x, 0.0, 1.0); }

float GiLuminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Ray with its inverse direction (the layout the block shape test expects)
struct Ray {
	vec3 origin;
	vec3 direction;
	vec3 inv_direction;
};

Ray MakeRay(vec3 origin, vec3 direction) {
	return Ray(origin, direction, vec3(1.0) / direction);
}

// Unit vector <-> 2 x 8 bits (octahedral mapping, about 1 degree of error)
uint GiPackNormal8(vec3 n) {
	n /= abs(n.x) + abs(n.y) + abs(n.z);
	vec2 e = n.z >= 0.0 ? n.xy : (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
	uvec2 q = uvec2(clamp(e * 0.5 + 0.5, 0.0, 1.0) * 255.0 + 0.5);
	return q.x | (q.y << 8u);
}

vec3 GiUnpackNormal8(uint v) {
	vec2 e = vec2(float(v & 255u), float((v >> 8u) & 255u)) / 255.0 * 2.0 - 1.0;
	vec3 n = vec3(e, 1.0 - abs(e.x) - abs(e.y));
	if (n.z < 0.0) n.xy = (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
	return normalize(n);
}

// Hash of a pixel and a frame -> uniform random numbers in [0, 1) (PCG)
uint GiHash(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

struct GiRng { uint state; };

GiRng GiRngInit(ivec2 pixel, int frame, uint stream) {
	return GiRng(GiHash(uint(pixel.x) + GiHash(uint(pixel.y) + GiHash(uint(frame) * 4u + stream))));
}

float GiRandom(inout GiRng rng) {
	rng.state = GiHash(rng.state);
	return float(rng.state >> 8u) / 16777216.0;
}

#endif
