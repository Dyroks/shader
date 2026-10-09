// =====================================================================================
//  Volumetric clouds - sky capture and cloud shadow map
//
//  cloudSkyCapture (begin_d.csh): sky + clouds radiance for every direction, octahedral map
//    (512^2, y up). rgb = radiance in SkyShading units, a = cloud transmittance (to hide
//    the sun disc behind clouds). Used by the GI, the sky ambient (SH) and the reflections.
//  cloudShadow (begin_c.csh): transmittance of the clouds along the light, stored on the
//    horizontal plane of the cloud layer bottom, centred on the camera.
//
//  Lookups only need cameraPosition and worldLightVector (or an explicit light vector).
// =====================================================================================

#ifndef CLOUD_SKY_INC
#define CLOUD_SKY_INC

const float cloudSkyCaptureSize = 512.0;
const float cloudShadowSize     = 512.0;
const float cloudShadowTexel    = 64.0 * CLOUD_SCALE;
const float cloudShadowPlane    = float(CLOUD_ALTITUDE) - 0.45 * 1000.0 * CLOUD_SCALE;   // = cloudLayerBottom

// Octahedral mapping of the unit sphere, y up
vec2 CloudOctEncode(vec3 n) {
	n /= abs(n.x) + abs(n.y) + abs(n.z);
	vec2 p = n.xz;
	if (n.y < 0.0) {
		vec2 s = vec2(p.x >= 0.0 ? 1.0 : -1.0, p.y >= 0.0 ? 1.0 : -1.0);
		p = (1.0 - abs(p.yx)) * s;
	}
	return p * 0.5 + 0.5;
}

vec3 CloudOctDecode(vec2 uv) {
	vec2 f = uv * 2.0 - 1.0;
	vec3 n = vec3(f.x, 1.0 - abs(f.x) - abs(f.y), f.y);
	float t = max(-n.y, 0.0);
	n.x += n.x >= 0.0 ? -t : t;
	n.z += n.z >= 0.0 ? -t : t;
	return normalize(n);
}

vec2 CloudShadowOrigin() {
	return floor(cameraPosition.xz / cloudShadowTexel) * cloudShadowTexel;
}

#ifdef CLOUD_SKY_LOOKUPS
uniform sampler2D cloudSkyCaptureSampler;
uniform sampler2D cloudShadowSampler;

// Sky + clouds radiance (SkyShading units) and cloud transmittance toward a direction
vec4 CloudSkyLookup(vec3 dir) {
	return textureLod(cloudSkyCaptureSampler, CloudOctEncode(dir), 0.0);
}

// Transmittance of the clouds between a camera relative position and the light
float CloudShadowLookup(vec3 relPos, vec3 L) {
	if (L.y < 0.03) return 1.0;
	float y = cameraPosition.y + relPos.y;
	vec2 q = relPos.xz + L.xz * ((cloudShadowPlane - y) / L.y);
	vec2 uv = (cameraPosition.xz - CloudShadowOrigin() + q) / (cloudShadowTexel * cloudShadowSize) + 0.5;
	vec2 e = abs(uv - 0.5);
	float fade = CloudSat((0.5 - max(e.x, e.y)) * 20.0) * CloudSat((L.y - 0.03) * 20.0);
	return mix(1.0, textureLod(cloudShadowSampler, uv, 0.0).r, fade);
}
#endif

#endif
