#version 430

// Volumetric clouds: cloud shadow map, begin_h. Light space "Beer shadow map", 2 cascades
// (768x512 atlas: near 256^2 +-8 km, far 512^2 +-80 km, scaled), see CloudSky.inc for the layout.
// Read by the sunlight / GI / godrays / crepuscular rays code through CloudSky.inc.

layout(local_size_x = 16, local_size_y = 16) in;

#include "/lib/Settings.inc"

#if defined VOLUMETRIC_CLOUDS && defined CLOUD_SHADOWS
const ivec3 workGroups = ivec3(48, 32, 1);   // near: x < 16 and y < 16 groups, far: x >= 16
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

#define CLOUD_WEATHER_SAMPLING
#include "/lib/clouds/CloudUniforms.inc"
#include "/lib/clouds/CloudCommon.inc"
#include "/lib/clouds/CloudWeather.inc"
#include "/lib/clouds/CloudMarch.inc"
#include "/lib/clouds/CloudSky.inc"

layout(rgba16f) uniform writeonly image2D cloudShadow;

void main() {
	#if defined VOLUMETRIC_CLOUDS && defined CLOUD_SHADOWS
		ivec2 id = ivec2(gl_GlobalInvocationID.xy);
		bool far = id.x >= int(cloudShadowNearSize);
		if (!far && id.y >= int(cloudShadowNearSize)) return;
		// Time sliced: the near cascade refreshes one row in two per frame, the far one one row
		// in four (toroidal addressing, CloudSky.inc: a stale row still holds the right world
		// column, at most 1 or 3 frames old; shadows move slowly)
		if (far ? ((id.y + frameCounter) & 3) != 0 : ((id.y ^ frameCounter) & 1) != 0) return;
		vec3 L = normalize(shadowModelViewInverse[2].xyz);
		vec4 res = vec4(0.0);

		if (L.y > -0.05) {
			CloudCtx ctx = CloudMakeCtx(CloudTime());
			vec3 U, V;
			CloudShadowBasis(L, U, V);
			float texel = far ? cloudShadowTexelFar : cloudShadowTexelNear;
			int size = far ? int(cloudShadowFarSize) : int(cloudShadowNearSize);
			// window texel held by this atlas texel, then its centre relative to the camera
			vec2 cam = CloudShadowCamTexels(U, V, texel);
			ivec2 org = ivec2(floor(cam)) - size / 2;
			ivec2 w = (ivec2(far ? id.x - int(cloudShadowNearSize) : id.x, id.y) - org) & (size - 1);
			vec2 uv = (vec2(w) + 0.5 - float(size / 2) - fract(cam)) * texel;
			vec3 q = U * uv.x + V * uv.y;   // texel centre on the plane through the camera, normal to L
			float camY = cameraPosition.y;

			// Part of the light ray inside the cloud layer (+ margin for the planet curvature)
			float zr = 150.0 * cloudKm;
			float margin = (far ? 1.2 : 0.2) * cloudKm;
			float y0 = camY + q.y;
			float sLo = -zr, sHi = zr;
			if (abs(L.y) > 1e-4) {
				float a = (cloudLayerBottom - margin - y0) / L.y, b = (cloudLayerTop + margin - y0) / L.y;
				sLo = max(sLo, min(a, b));
				sHi = min(sHi, max(a, b));
			} else if (y0 < cloudLayerBottom - margin || y0 > cloudLayerTop + margin) {
				sHi = sLo - 1.0;
			}

			// March from the light side (s decreasing): the first cloud is sMax. Steps grow with
			// the distance from the camera plane: with a low sun, a light ray crosses tens of km
			// of the cloud layer, and distant clouds cast the long sunset shadows.
			float baseStep = (far ? 320.0 : 80.0) * cloudScale;
			float horiz = max(length(L.xz), 1e-4);
			float tau = 0.0, sMax = 0.0, sMin = 0.0;
			bool hit = false;
			float s = sHi;
			for (int i = 0; i < 128; i++) {
				if (s <= sLo || tau > 12.0) break;
				float stepT = max(baseStep, abs(s) * 0.03);
				int lod = (far || abs(s) > 12.0 * cloudKm) ? 1 : 0;
				vec3 p = q + L * s;
				CloudWeather w = CloudSampleWeather(p.xz);
				float alt = CloudAltitude(p, camY);
				float d = 0.0;
				float jump = stepT;
				if (w.cov > 0.0 && w.thick > 0.0) {
					float h = (alt - (cloudAltitude + w.base * cloudKm)) / (w.thick * cloudKm);
					if (h >= 0.0 && h <= cloudTurretMax) {
						d = CloudDensity(p, h, w, 0.0, ctx.baseOrigin, ctx.detailOrigin, lod);
					} else if (L.y > 0.0 && h > cloudTurretMax) {
						// above this cloud, going down: jump to the highest top around
						float topAlt = cloudAltitude + w.maxTop * cloudKm;
						if (alt > topAlt) jump = max(jump, min((alt - topAlt) / L.y, w.skipR * cloudKm / horiz));
					}
				} else {
					// outside footprints: the distance field gives a safe horizontal jump
					jump = max(jump, w.dist * cloudKm / horiz);
				}
				#if CLOUD_MID_LAYER > 0
					if (w.mid > 0.0 && alt > cloudMidBottom && alt < cloudMidTop) {
						float hm, tm;
						d += CloudMidDensity(p, alt, w, ctx, 0.0, lod, hm, tm);
						jump = stepT;
					} else if (alt >= cloudMidBottom && alt <= cloudMidTop) {
						jump = min(jump, max(w.midDist * cloudKm / horiz, stepT));
					}
				#endif
				if (d > 0.0) {
					if (!hit) { sMax = s; hit = true; }
					sMin = s - stepT;
					tau += d * stepT * cloudSigmaT;
					jump = stepT;
				}
				s -= jump;
			}
			if (hit) res.xyz = vec3(sMax / cloudKm, sMin / cloudKm, tau);

			// high clouds (thin, mostly forward scattering: little light lost), above everything
			#if CLOUD_HIGH_LAYER > 0
				if (L.y > 0.03) {
					float sh = (cloudHighAlt - y0) / L.y;
					res.w = min(CloudHighTau((q + L * sh).xz, ctx, 0.0).x / L.y * 0.6, 8.0);
				}
			#endif
		}
		imageStore(cloudShadow, id, res);
	#endif
}
