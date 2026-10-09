#version 430

// Volumetric clouds: cloud shadow map (512^2). For each point of the horizontal plane at the
// bottom of the cloud layer, transmittance of the clouds along the light direction.
// Read by the sunlight / GI / godrays shadow code through CloudShadowLookup (CloudSky.inc).

layout(local_size_x = 16, local_size_y = 16) in;

#include "/lib/Settings.inc"

#if defined VOLUMETRIC_CLOUDS && defined CLOUD_SHADOWS
const ivec3 workGroups = ivec3(32, 32, 1);
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

#define CLOUD_WEATHER_SAMPLING
#include "/lib/clouds/CloudUniforms.inc"
#include "/lib/clouds/CloudCommon.inc"
#include "/lib/clouds/CloudWeather.inc"
#include "/lib/clouds/CloudMarch.inc"
#include "/lib/clouds/CloudSky.inc"

layout(r16f) uniform writeonly image2D cloudShadow;

void main() {
	#if defined VOLUMETRIC_CLOUDS && defined CLOUD_SHADOWS
		ivec2 id = ivec2(gl_GlobalInvocationID.xy);
		vec3 L = normalize(shadowModelViewInverse[2].xyz);
		float transmittance = 1.0;

		if (L.y > 0.03) {
			float time = CloudTime();
			vec3 baseOrigin   = mod(cameraPosition - CloudBaseNoiseOffset(time), vec3(cloudBasePeriod));
			vec3 detailOrigin = mod(cameraPosition - CloudDetailNoiseOffset(time), vec3(cloudDetailPeriod));

			vec2 xz = CloudShadowOrigin() + (vec2(id) + 0.5 - cloudShadowSize * 0.5) * cloudShadowTexel;
			vec3 q = vec3(xz.x - cameraPosition.x, cloudShadowPlane - cameraPosition.y, xz.y - cameraPosition.z);
			float tEnd = min((cloudLayerTop - cloudShadowPlane) / L.y, 40.0 * cloudKm);
			float horiz = max(length(L.xz), 1e-4);

			// March toward the light with the same empty space skipping as the view rays
			float tau = 0.0, t = 0.0;
			for (int i = 0; i < 64; i++) {
				if (t >= tEnd) break;
				vec3 p = q + L * t;
				float stepT = 80.0 * cloudScale;
				CloudWeather w = CloudSampleWeather(p.xz);
				float alt = CloudAltitude(p, cameraPosition.y);
				float topAlt = cloudAltitude + w.maxTop * cloudKm;
				if (alt > topAlt) break;   // above every cloud of the neighbourhood and going up
				if (w.cov <= 0.0 || w.thick <= 0.0) {
					t += max(w.dist * cloudKm / horiz, stepT);
					continue;
				}
				float h = (alt - (cloudAltitude + w.base * cloudKm)) / (w.thick * cloudKm);
				if (h >= 0.0 && h <= cloudTurretMax)
					tau += CloudDensity(p, h, w, 0.0, baseOrigin, detailOrigin, 0) * stepT;
				t += stepT;
			}
			tau *= cloudSigmaT;

			// direct transmittance + light that diffused through the cloud (thin clouds and
			// cloud edges let some light through, thick cumulus cast dark shadows)
			float direct = exp(-tau);
			transmittance = direct + (1.0 - direct) * 0.2 * exp(-tau * 0.13);
		}
		imageStore(cloudShadow, id, vec4(transmittance));
	#endif
}
