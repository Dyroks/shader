// =====================================================================================
//  GI module: random numbers and directions
//
//  Uniforms: noisetex (64 x 64 blue noise), frameCounter.
// =====================================================================================

#ifndef GI_SAMPLING_INC
#define GI_SAMPLING_INC

// Blue noise of a pixel, moved along an irrational sequence every frame (64 frame cycle):
// well spread in space and in time
vec3 GiBlueNoise(ivec2 pixel) {
	const vec3 irrationals = vec3(0.447213595, 1.41421356, 1.61803398);
	vec3 n = texelFetch(noisetex, pixel & 63, 0).rgb;
	return fract(n + irrationals * float(frameCounter % 64));
}

// k-th point of the R2 sequence added to a base point: several well spread samples per pixel
vec2 GiSampleOffset(vec2 base, int k) {
	return fract(base + float(k) * vec2(0.7548776662, 0.5698402910));
}

// Orthonormal basis around a unit vector (Duff et al. 2017)
void GiBasis(vec3 n, out vec3 t, out vec3 b) {
	float s = n.z >= 0.0 ? 1.0 : -1.0;
	float a = -1.0 / (s + n.z);
	float c = n.x * n.y * a;
	t = vec3(1.0 + s * n.x * n.x * a, s * c, -s * n.x);
	b = vec3(c, s + n.y * n.y * a, -n.y);
}

// Direction around n with a density proportional to the cosine (pdf = cos / pi): every sample
// carries the same weight for a diffuse surface
vec3 GiCosineDirection(vec3 n, vec2 u) {
	vec3 t, b;
	GiBasis(n, t, b);
	float r = sqrt(u.x);
	float phi = 2.0 * giPi * u.y;
	return normalize(t * (r * cos(phi)) + b * (r * sin(phi)) + n * sqrt(max(0.0, 1.0 - u.x)));
}

#endif
