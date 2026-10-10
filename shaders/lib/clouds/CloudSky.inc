// =====================================================================================
//  Volumetric clouds - sky capture and cloud shadow map
//
//  cloudSkyCapture (begin_g.csh): sky + clouds radiance for every direction, octahedral map
//    (512^2, y up). rgb = radiance in SkyShading units, a = cloud transmittance (to hide
//    the sun disc behind clouds). Used by the GI, the sky ambient (SH) and the reflections.
//  cloudShadow (begin_h.csh): light space "Beer shadow map" of the clouds (UE style), 2
//    cascades side by side (768x512): near 256^2 over +-8 km, far 512^2 over +-80 km (scaled).
//    Texels lie on the plane through the camera normal to the light, each one stores along
//    its light ray (s = distance toward the light, scaled km, camera relative):
//      x = sMax: cloud entry on the light side, y = sMin: last cloud on the far side,
//      z = optical depth of the low + mid clouds, w = optical depth of the high layer.
//    The optical depth ahead of a point (toward the light) is z * (sMax - s) / (sMax - sMin),
//    clamped: correct below / behind / above the clouds, linear inside. Works at any altitude
//    and for a light on the horizon (sunset crepuscular rays).
//    Toroidal addressing: a texel always holds the same light space world column (index mod
//    the cascade size), so the rows begin_h does not refresh this frame stay valid while the
//    camera moves (near: one row in two per frame, far: one in four).
//
//  Lookups only need cameraPosition and worldLightVector (or an explicit light vector).
// =====================================================================================

#ifndef CLOUD_SKY_INC
#define CLOUD_SKY_INC

const float cloudSkyCaptureSize = 512.0;
const float cloudShadowNearSize = 256.0;   // near cascade: x 0..255, y 0..255 of the atlas
const float cloudShadowFarSize  = 512.0;   // far cascade: x 256..767, y 0..511
const float cloudShadowTexelNear = 62.5 * CLOUD_SCALE;
const float cloudShadowTexelFar  = 312.5 * CLOUD_SCALE;

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

// Light space basis (L: toward the light). The sun moves in the x-y plane (tilted by the sun
// path rotation): the cross product with z never vanishes.
void CloudShadowBasis(vec3 L, out vec3 U, out vec3 V) {
	U = normalize(cross(L, vec3(0.0, 0.0, 1.0)));
	V = cross(U, L);
}

// Camera position in a cascade's texels (light space u, v): the grid is anchored in the world
// (no shimmering when the camera moves)
vec2 CloudShadowCamTexels(vec3 U, vec3 V, float texel) {
	return vec2(dot(cameraPosition, U), dot(cameraPosition, V)) / texel;
}

// Atlas texel holding the window texel w (0..size-1 around the camera) of a cascade whose
// window starts at the world texel index org (toroidal)
ivec2 CloudShadowAtlasTexel(ivec2 org, ivec2 w, bool far) {
	return far ? ((org + w) & 511) + ivec2(256, 0) : (org + w) & 255;
}

#ifdef CLOUD_SKY_LOOKUPS
uniform sampler2D cloudSkyCaptureSampler;
uniform sampler2D cloudShadowSampler;

// Sky + clouds radiance (SkyShading units) and cloud transmittance toward a direction
vec4 CloudSkyLookup(vec3 dir) {
	return textureLod(cloudSkyCaptureSampler, CloudOctEncode(dir), 0.0);
}

// Optical depth ahead of point s (scaled km along the light) from one texel
float CloudShadowTexelOD(vec4 t, float s, bool belowHigh) {
	float od = t.z * CloudSat((t.x - s) / max(t.x - t.y, 0.02));
	return od + (belowHigh ? t.w : 0.0);
}

// Light space frame of the shadow map for a light direction (computed once, reused for many lookups)
struct CloudShadowFrame {
	vec3 L, U, V;
	vec2 fracNear, fracFar;   // camera position in texels, fractional part
	ivec2 orgNear, orgFar;    // world texel index of the first window texel
};

CloudShadowFrame CloudShadowMakeFrame(vec3 L) {
	CloudShadowFrame f;
	f.L = L;
	CloudShadowBasis(L, f.U, f.V);
	vec2 cn = CloudShadowCamTexels(f.U, f.V, cloudShadowTexelNear);
	vec2 cf = CloudShadowCamTexels(f.U, f.V, cloudShadowTexelFar);
	f.fracNear = fract(cn);
	f.fracFar = fract(cf);
	f.orgNear = ivec2(floor(cn)) - int(cloudShadowNearSize) / 2;
	f.orgFar = ivec2(floor(cf)) - int(cloudShadowFarSize) / 2;
	return f;
}

// Window coordinates of a camera relative position: xy = continuous texel position in the
// cascade window (texel centres at +0.5), z = s (scaled km), w = cascade weight (0 = outside
// every cascade); far: the far cascade
vec4 CloudShadowCoords(CloudShadowFrame f, vec3 relPos, out bool far) {
	vec2 uv = vec2(dot(relPos, f.U), dot(relPos, f.V));
	float s = dot(relPos, f.L) / cloudKm;
	far = false;
	// margin of 3 texels: the newest columns of a moving window may not be computed yet
	vec2 wn = uv / cloudShadowTexelNear + f.fracNear + cloudShadowNearSize * 0.5;
	if (all(greaterThan(wn, vec2(3.0))) && all(lessThan(wn, vec2(cloudShadowNearSize - 3.0))))
		return vec4(wn, s, 1.0);
	far = true;
	vec2 wf = uv / cloudShadowTexelFar + f.fracFar + cloudShadowFarSize * 0.5;
	float edge = min(min(wf.x, wf.y), cloudShadowFarSize - max(wf.x, wf.y));
	return vec4(wf, s, CloudSat(edge / 8.0 - 0.5));
}

// Hardware bilinear fetch of the 4 texels around a window position (one texel when the
// footprint crosses the toroidal seam). Filtering sMax, sMin and the optical depths before
// using them blends the shadows smoothly, without any noise.
vec4 CloudShadowFetch(CloudShadowFrame f, vec2 w, bool far) {
	vec2 p = w - 0.5;
	ivec2 i = ivec2(floor(p));
	ivec2 a = CloudShadowAtlasTexel(far ? f.orgFar : f.orgNear, i, far);
	int last = far ? 511 : 255;
	if ((far ? a.x - 256 : a.x) >= last || a.y >= last) return texelFetch(cloudShadowSampler, CloudShadowAtlasTexel(far ? f.orgFar : f.orgNear, ivec2(floor(w)), far), 0);
	return textureLod(cloudShadowSampler, (vec2(a) + fract(p) + 0.5) / vec2(cloudShadowNearSize + cloudShadowFarSize, cloudShadowFarSize), 0.0);
}

// Optical depth of the clouds between a camera relative position and the light, split into
// (low + mid clouds, high clouds): the crepuscular rays exaggerate only the shadows of the low
// clouds (the shafts), not the uniform veil of the cirrus
vec2 CloudShadowOpticalDepthSplit(CloudShadowFrame f, vec3 relPos) {
	bool far;
	vec4 c = CloudShadowCoords(f, relPos, far);
	if (c.w <= 0.0) return vec2(0.0);
	vec4 t = CloudShadowFetch(f, c.xy, far);
	float high = cameraPosition.y + relPos.y < cloudHighAlt ? t.w : 0.0;
	return vec2(CloudShadowTexelOD(t, c.z, false), high) * c.w;
}

float CloudShadowOpticalDepth(CloudShadowFrame f, vec3 relPos) {
	vec2 od = CloudShadowOpticalDepthSplit(f, relPos);
	return od.x + od.y;
}

// Light that goes through the clouds: direct transmittance + light that diffused through
// them (thin clouds and cloud edges let some light through, thick cumulus cast dark shadows)
float CloudShadowTransmittance(float od) {
	float direct = exp(-od);
	return direct + (1.0 - direct) * 0.2 * exp(-od * 0.13);
}

// Transmittance of the clouds between a camera relative position and the light (terrain, GI
// rays, reflections: one filtered fetch)
float CloudShadowLookup(vec3 relPos, vec3 L) {
	if (L.y < -0.05) return 1.0;
	return CloudShadowTransmittance(CloudShadowOpticalDepth(CloudShadowMakeFrame(L), relPos));
}
#endif

#endif
