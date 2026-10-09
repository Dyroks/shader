#version 430

// Physical atmosphere: multiple scattering LUT (32 x 32), Hillaire 2020 section 5.5.
// For each altitude and sun angle: second order scattering from 64 directions with an
// isotropic phase function, summed to infinite orders as a geometric series.

layout(local_size_x = 16, local_size_y = 16) in;

#include "/lib/Settings.inc"

#if ATMOSPHERE_MODEL == 1
const ivec3 workGroups = ivec3(2, 2, 1);
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

#define ATMOSPHERE_LUTS
#include "/lib/clouds/CloudUniforms.inc"
#include "/lib/atmosphere/Atmosphere.inc"

layout(rgba16f) uniform writeonly image2D atmoMultiScat;

void main() {
	#if ATMOSPHERE_MODEL == 1
		ivec2 id = ivec2(gl_GlobalInvocationID.xy);
		vec2 uv = ((vec2(id) + 0.5) / atmoMultiScatSize * atmoMultiScatSize - 0.5) / (atmoMultiScatSize - 1.0);
		float mu = uv.x * 2.0 - 1.0;
		float r = atmoRg + uv.y * (atmoRt - atmoRg);
		r = clamp(r, atmoRg + 0.001, atmoRt - 0.001);
		vec3 ro = vec3(0.0, r, 0.0);
		vec3 L = vec3(sqrt(max(1.0 - mu * mu, 0.0)), mu, 0.0);
		float mieScale = AtmoMieDensityScale();
		const float isoPhase = 1.0 / (4.0 * atmoPI);

		vec3 lumSum = vec3(0.0), fSum = vec3(0.0);
		for (int a = 0; a < 8; a++)
		for (int b = 0; b < 8; b++) {
			float theta = 2.0 * atmoPI * (float(a) + 0.5) / 8.0;
			float phi = acos(1.0 - 2.0 * (float(b) + 0.5) / 8.0);
			vec3 rd = vec3(cos(theta) * sin(phi), cos(phi), sin(theta) * sin(phi));
			float tG = AtmoRaySphere(ro, rd, atmoRg);
			float t = tG > 0.0 ? tG : max(AtmoRaySphere(ro, rd, atmoRt), 0.0);

			const int steps = 20;
			vec3 T = vec3(1.0), lum = vec3(0.0), f = vec3(0.0);
			for (int i = 0; i < steps; i++) {
				float t0 = float(i) / float(steps), t1 = float(i + 1) / float(steps);
				t0 *= t0 * t; t1 *= t1 * t;
				float dt = t1 - t0;
				vec3 P = ro + rd * mix(t0, t1, 0.5);
				float rp = length(P);
				AtmoMedium m = AtmoSampleMedium(rp - atmoRg, mieScale);
				vec3 scat = m.scatR + m.scatM;
				vec3 S = AtmoLightAt(P, rp, L) * scat * isoPhase;
				vec3 sampleT = exp(-m.ext * dt);
				vec3 ext = max(m.ext, vec3(1e-7));
				lum += T * (S - S * sampleT) / ext;
				f   += T * (scat - scat * sampleT) / ext;
				T *= sampleT;
			}
			if (tG > 0.0) {
				vec3 Pg = ro + rd * tG;
				float muG = dot(normalize(Pg), L);
				lum += T * AtmoTransmittance(atmoRg, muG) * max(muG, 0.0) * atmoGroundAlbedo / atmoPI;
			}
			lumSum += lum;
			fSum += f;
		}
		// isotropic phase over the sphere: (sum * 4 pi / 64) / (4 pi)
		lumSum /= 64.0;
		fSum /= 64.0;
		vec3 psi = lumSum / max(1.0 - fSum, vec3(1e-3));
		imageStore(atmoMultiScat, id, vec4(psi, 1.0));
	#endif
}
