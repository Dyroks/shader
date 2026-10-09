#version 430

// Physical atmosphere: transmittance LUT (256 x 64), see lib/atmosphere/Atmosphere.inc

layout(local_size_x = 16, local_size_y = 16) in;

#include "/lib/Settings.inc"

#if ATMOSPHERE_MODEL == 1
const ivec3 workGroups = ivec3(16, 4, 1);
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

#include "/lib/clouds/CloudUniforms.inc"
#include "/lib/atmosphere/Atmosphere.inc"

layout(rgba16f) uniform writeonly image2D atmoTransmittance;

void main() {
	#if ATMOSPHERE_MODEL == 1
		ivec2 id = ivec2(gl_GlobalInvocationID.xy);
		float r, mu;
		AtmoTransmittanceParams((vec2(id) + 0.5) / atmoTransmittanceSize, r, mu);
		vec3 ro = vec3(0.0, r, 0.0);
		vec3 rd = vec3(sqrt(max(1.0 - mu * mu, 0.0)), mu, 0.0);
		float t = max(AtmoRaySphere(ro, rd, atmoRt), 0.0);
		float mieScale = AtmoMieDensityScale();

		const int steps = 40;
		vec3 depth = vec3(0.0);
		for (int i = 0; i < steps; i++) {
			// quadratic distribution: short steps in the dense low atmosphere
			float t0 = float(i) / float(steps), t1 = float(i + 1) / float(steps);
			t0 *= t0 * t; t1 *= t1 * t;
			vec3 P = ro + rd * mix(t0, t1, 0.5);
			depth += AtmoSampleMedium(length(P) - atmoRg, mieScale).ext * (t1 - t0);
		}
		imageStore(atmoTransmittance, id, vec4(exp(-depth), 1.0));
	#endif
}
