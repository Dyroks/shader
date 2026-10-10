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

// Offset of the texel grid of a cascade from the camera, in light space (u, v): the grid is
// snapped to whole texels in world space (no shimmering when the camera moves)
vec2 CloudShadowGridOffset(vec3 U, vec3 V, float texel) {
	vec2 cam = vec2(dot(cameraPosition, U), dot(cameraPosition, V));
	return floor(cam / texel) * texel - cam;
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
	vec2 offNear, offFar;
};

CloudShadowFrame CloudShadowMakeFrame(vec3 L) {
	CloudShadowFrame f;
	f.L = L;
	CloudShadowBasis(L, f.U, f.V);
	f.offNear = CloudShadowGridOffset(f.U, f.V, cloudShadowTexelNear);
	f.offFar = CloudShadowGridOffset(f.U, f.V, cloudShadowTexelFar);
	return f;
}

// Texel coordinates of a camera relative position: xy = continuous texel position in the
// atlas, z = s (scaled km), w = cascade weight (0 = outside every cascade)
vec4 CloudShadowCoords(CloudShadowFrame f, vec3 relPos) {
	vec2 uv = vec2(dot(relPos, f.U), dot(relPos, f.V));
	float s = dot(relPos, f.L) / cloudKm;
	vec2 fn = (uv - f.offNear) / cloudShadowTexelNear + cloudShadowNearSize * 0.5;
	if (all(greaterThan(fn, vec2(1.0))) && all(lessThan(fn, vec2(cloudShadowNearSize - 1.0))))
		return vec4(fn, s, 1.0);
	vec2 ff = (uv - f.offFar) / cloudShadowTexelFar + cloudShadowFarSize * 0.5;
	float edge = min(min(ff.x, ff.y), cloudShadowFarSize - max(ff.x, ff.y));
	return vec4(ff + vec2(cloudShadowNearSize, 0.0), s, CloudSat(edge / 8.0 - 0.25));
}

// Optical depth of the clouds between a camera relative position and the light (direct light
// attenuation). jitter (texels, -0.5..0.5): nearest texel lookup with a stochastic offset
// (filtered by temporal accumulation); without it, bilinear filtering of the result (4 taps).
float CloudShadowOpticalDepth(CloudShadowFrame f, vec3 relPos, vec2 jitter, bool stochastic) {
	vec4 c = CloudShadowCoords(f, relPos);
	if (c.w <= 0.0) return 0.0;
	bool belowHigh = cameraPosition.y + relPos.y < cloudHighAlt;
	float od;
	if (stochastic) {
		od = CloudShadowTexelOD(texelFetch(cloudShadowSampler, ivec2(c.xy + jitter), 0), c.z, belowHigh);
	} else {
		vec2 p = c.xy - 0.5;
		ivec2 i = ivec2(floor(p));
		vec2 f = p - vec2(i);
		float a = CloudShadowTexelOD(texelFetch(cloudShadowSampler, i, 0), c.z, belowHigh);
		float b = CloudShadowTexelOD(texelFetch(cloudShadowSampler, i + ivec2(1, 0), 0), c.z, belowHigh);
		float d = CloudShadowTexelOD(texelFetch(cloudShadowSampler, i + ivec2(0, 1), 0), c.z, belowHigh);
		float e = CloudShadowTexelOD(texelFetch(cloudShadowSampler, i + ivec2(1, 1), 0), c.z, belowHigh);
		// filter the transmittance, not the optical depth (soft shadow edges)
		float T = mix(mix(exp(-a), exp(-b), f.x), mix(exp(-d), exp(-e), f.x), f.y);
		od = -log(max(T, 1e-6));
	}
	return od * c.w;
}

// Stochastic lookup split into (low + mid clouds, high clouds): the crepuscular rays exaggerate
// only the shadows of the low clouds (the shafts), not the uniform veil of the cirrus
vec2 CloudShadowOpticalDepthSplit(CloudShadowFrame f, vec3 relPos, vec2 jitter) {
	vec4 c = CloudShadowCoords(f, relPos);
	if (c.w <= 0.0) return vec2(0.0);
	vec4 t = texelFetch(cloudShadowSampler, ivec2(c.xy + jitter), 0);
	float high = cameraPosition.y + relPos.y < cloudHighAlt ? t.w : 0.0;
	return vec2(CloudShadowTexelOD(t, c.z, false), high) * c.w;
}

// Light that goes through the clouds: direct transmittance + light that diffused through
// them (thin clouds and cloud edges let some light through, thick cumulus cast dark shadows)
float CloudShadowTransmittance(float od) {
	float direct = exp(-od);
	return direct + (1.0 - direct) * 0.2 * exp(-od * 0.13);
}

// Transmittance of the clouds between a camera relative position and the light (terrain, GI)
float CloudShadowLookup(vec3 relPos, vec3 L) {
	if (L.y < -0.05) return 1.0;
	CloudShadowFrame f = CloudShadowMakeFrame(L);
	// below every cloud (terrain, GI rays): all the clouds of the texel lie toward the light,
	// one hardware filtered fetch (this runs for every GI hit)
	if (cameraPosition.y + relPos.y < cloudLayerBottom) {
		vec4 c = CloudShadowCoords(f, relPos);
		if (c.w <= 0.0) return 1.0;
		vec2 t = textureLod(cloudShadowSampler, c.xy / vec2(cloudShadowNearSize + cloudShadowFarSize, cloudShadowFarSize), 0.0).zw;
		return CloudShadowTransmittance((t.x + t.y) * c.w);
	}
	return CloudShadowTransmittance(CloudShadowOpticalDepth(f, relPos, vec2(0.0), false));
}
#endif

#endif
