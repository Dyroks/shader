#version 430

// Physical atmosphere: sky-view LUT (192 x 108 for the sun, then 192 x 108 for the moon),
// sky luminance around the camera at its current altitude (Hillaire 2020 section 5.3).

layout(local_size_x = 16, local_size_y = 16) in;

#include "/lib/Settings.inc"

#if ATMOSPHERE_MODEL == 1
const ivec3 workGroups = ivec3(12, 14, 1);
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

#define ATMOSPHERE_LUTS
#include "/lib/clouds/CloudUniforms.inc"
#include "/lib/atmosphere/Atmosphere.inc"

layout(rgba16f) uniform writeonly image2D atmoSkyView;

void main() {
	#if ATMOSPHERE_MODEL == 1
		ivec2 id = ivec2(gl_GlobalInvocationID.xy);
		if (id.x >= int(atmoSkyViewSize.x) || id.y >= 2 * int(atmoSkyViewSize.y)) return;
		bool moonHalf = id.y >= int(atmoSkyViewSize.y);
		ivec2 lid = ivec2(id.x, id.y - (moonHalf ? int(atmoSkyViewSize.y) : 0));

		float r = AtmoCameraRadius();
		float viewZenithCos, lightViewCos;
		AtmoSkyViewParams((vec2(lid) + 0.5) / atmoSkyViewSize, r, viewZenithCos, lightViewCos);

		// the pack's light vector is the sun by day and the moon by night
		vec3 Lpack = normalize(shadowModelViewInverse[2].xyz);
		vec3 sunVec = sunAngle < 0.5 ? Lpack : -Lpack;
		float ly = moonHalf ? -sunVec.y : sunVec.y;
		vec3 L = vec3(sqrt(max(1.0 - ly * ly, 0.0)), ly, 0.0);

		float s = sqrt(max(1.0 - viewZenithCos * viewZenithCos, 0.0));
		vec3 rd = vec3(s * lightViewCos, viewZenithCos, s * sqrt(max(1.0 - lightViewCos * lightViewCos, 0.0)));
		vec3 ro = vec3(0.0, r, 0.0);
		float tG = AtmoRaySphere(ro, rd, atmoRg);
		float t = tG > 0.0 ? tG : max(AtmoRaySphere(ro, rd, atmoRt), 0.0);

		vec3 T;
		vec3 lum = AtmoIntegrate(ro, rd, t, L, 32, 0.3, AtmoMieDensityScale(), T);
		if (tG > 0.0) {
			// ground below the horizon (seen when flying or in reflections)
			vec3 Pg = ro + rd * tG;
			float muG = dot(normalize(Pg), L);
			lum += T * atmoGroundAlbedo / atmoPI * AtmoTransmittance(atmoRg, muG) * max(muG, 0.0);
		}
		imageStore(atmoSkyView, id, vec4(lum, 1.0));
	#endif
}
