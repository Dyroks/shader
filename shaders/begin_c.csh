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
			CloudCtx ctx = CloudMakeCtx(CloudTime());

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
					tau += CloudDensity(p, h, w, 0.0, ctx.baseOrigin, ctx.detailOrigin, 0) * stepT;
				t += stepT;
			}

			// mid level layer: fixed number of steps across it
			#if CLOUD_MID_LAYER > 0
				if (ctx.R.mid > 0.0) {
					float t0 = (cloudMidBottom - cloudShadowPlane) / L.y;
					float t1 = min((cloudMidTop - cloudShadowPlane) / L.y, 40.0 * cloudKm);
					float dtm = (t1 - t0) / 12.0;
					for (int i = 0; i < 12; i++) {
						vec3 p = q + L * (t0 + (float(i) + 0.5) * dtm);
						CloudWeather w = CloudSampleWeather(p.xz);
						if (w.mid <= 0.0) continue;
						float hm, tm;
						tau += CloudMidDensity(p, CloudAltitude(p, cameraPosition.y), w, ctx, 0.0, 0, hm, tm) * dtm;
					}
				}
			#endif
			tau *= cloudSigmaT;
			// high clouds (thin, mostly forward scattering)
			#if CLOUD_HIGH_LAYER > 0
				tau += CloudHighTau(q.xz + L.xz * ((cloudHighAlt - cloudShadowPlane) / L.y), ctx, 0.0).x / L.y * 0.6;
			#endif

			// direct transmittance + light that diffused through the cloud (thin clouds and
			// cloud edges let some light through, thick cumulus cast dark shadows)
			float direct = exp(-tau);
			transmittance = direct + (1.0 - direct) * 0.2 * exp(-tau * 0.13);
		}
		imageStore(cloudShadow, id, vec4(transmittance));
	#endif
}
