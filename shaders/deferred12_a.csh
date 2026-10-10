#version 430
// Distant terrain shading (lib/FarShading.inc), before deferred12, at a quarter of the internal
// resolution (one pixel of each 2x2 block, a different one every frame, like composite4_c):
//  - sun shadows by a march toward the sun through the depth buffer (Voxy included): the
//    shadow map covers shadowDistance and holds no Voxy terrain, so distant mountains cast no
//    shadow otherwise. Pixels near the camera only count LOD terrain as occluders (the
//    shadow map handles the rest). Limit: the occluder must be on screen.
//  - ambient occlusion where deferred12 replaces the GI with the flat sky ambient (beyond the
//    voxel volume): hemisphere samples through the depth buffer.
// Output farShade: x = ambient occlusion, y = sun visibility, z = distance (km), w = 1.
layout(local_size_x = 8, local_size_y = 8) in;
#include "/lib/Settings.inc"
#ifdef AB_FAR_SHADING
const vec2 workGroupsRender = vec2(0.25, 0.25);
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif

#ifdef AB_FAR_SHADING
uniform sampler2D depthtex1;
uniform sampler2D colortex2;
uniform sampler2D noisetex;
#ifdef VOXY
uniform sampler2D vxDepthTexOpaque;
uniform mat4 vxProjInv;
#endif
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 worldLightVector;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform int frameCounter;
layout(rgba16f) uniform writeonly image2D farShade;

const int shadowMapResolution = 8192; // Higher value impacts performance costs, but can get better shadow, and increase path tracing distance. Please increase the shadow distance at the same time. 4096 - 80 blocks path tracing. 8192 - 160 blocks path tracing. 16384 - 300 blocks path tracing, requires at least 6GB VRAM. 34768 - 530 blocks of path tracing, requires at least 20GB VRAM. [4096 8192 16384 32768]
#ifndef MC_SHADOW_QUALITY
	#define MC_SHADOW_QUALITY 1.0
#endif
const float SHADOW_MAP_RESOLUTION = shadowMapResolution * MC_SHADOW_QUALITY;
const float RAY_TRACING_RESOLUTION = SHADOW_MAP_RESOLUTION - 2048.0;
const float RAY_TRACING_DIAMETER_TEMP = floor(pow(RAY_TRACING_RESOLUTION, 2.0 / 3.0));
const float RAY_TRACING_DIAMETER = RAY_TRACING_DIAMETER_TEMP - mod(RAY_TRACING_DIAMETER_TEMP - 1.0, 2.0);
const float RAY_TRACING_RADIUS = RAY_TRACING_DIAMETER / 2.0;

#include "/lib/FarShading.inc"

vec2 screen;
vec2 jitter;
ivec2 internalSize;

vec3 DecodeNormal(vec2 enc) {
	vec2 fenc = enc * 4.0 - 2.0;
	float f = dot(fenc, fenc);
	return vec3(fenc * sqrt(1.0 - f / 4.0), 1.0 - f / 2.0);
}

// View space position of the solid surface (vanilla or LOD) seen through internal pixel px;
// w = 0 for the sky, 1 for vanilla terrain, 2 for LOD terrain
vec4 SceneViewPos(ivec2 px) {
	vec2 tc = (vec2(px) + 0.5) / screen - jitter * 0.5;
	float d = texelFetch(depthtex1, px, 0).x;
	if (d < 1.0) {
		vec4 p = gbufferProjectionInverse * vec4(tc * 4.0 - 1.0, d * 2.0 - 1.0, 1.0);
		return vec4(p.xyz / p.w, 1.0);
	}
	#ifdef VOXY
		float ld = textureLod(vxDepthTexOpaque, (vec2(px) + 0.5) / screen * 2.0, 0.0).x;
		if (ld < 1.0) {
			vec4 p = vxProjInv * vec4(tc * 4.0 - 1.0, ld * 2.0 - 1.0, 1.0);
			return vec4(p.xyz / p.w, 2.0);
		}
	#endif
	return vec4(0.0);
}

// Internal pixel of a view space position (false: off screen or behind the camera)
bool ProjectToPixel(vec3 q, out ivec2 px) {
	if (q.z > -0.05) return false;
	vec4 c = gbufferProjection * vec4(q, 1.0);
	vec2 tc = (c.xy / c.w + 1.0) * 0.25 + jitter * 0.5;
	px = ivec2(floor(tc * screen));
	return all(greaterThanEqual(px, ivec2(0))) && all(lessThan(px, internalSize));
}
#endif

void main() {
	#ifdef AB_FAR_SHADING
		screen = vec2(viewWidth, viewHeight);
		internalSize = ivec2(ceil(screen * 0.5));
		ivec2 rp = ivec2(gl_GlobalInvocationID.xy);
		ivec2 rsz = (internalSize + 1) / 2;
		if (any(greaterThanEqual(rp, rsz))) return;
		int i4 = frameCounter & 3;
		ivec2 px = min(rp * 2 + ivec2(i4 == 1 || i4 == 2 ? 1 : 0, i4 == 1 || i4 == 3 ? 1 : 0), internalSize - 1);
		float f = float(frameCounter & 15);
		jitter = (fract(f * vec2(12664745.0, 9560333.0) / 16777216.0) * 2.0 - 1.0) / screen;

		vec4 P = SceneViewPos(px);
		if (P.w == 0.0) {
			imageStore(farShade, rp, vec4(1.0, 1.0, 1e4, 1.0));
			return;
		}
		float dist = length(P.xyz);
		vec3 rel = mat3(gbufferModelViewInverse) * P.xyz + gbufferModelViewInverse[3].xyz;
		float cheb = max(max(abs(rel.x), abs(rel.y)), abs(rel.z));
		vec3 n = normalize(DecodeNormal(texelFetch(colortex2, px, 0).zw));
		vec3 noise = texelFetch(noisetex, rp & 63, 0).rgb;
		noise = fract(noise + vec3(0.447213595, 1.41421356, 1.61803398) * float(frameCounter % 64));
		vec3 start = P.xyz + n * (0.5 + 0.004 * dist);

		// Sun: march toward the light, steps growing geometrically up to farShadowReach
		float sun = 1.0;
		vec3 L = normalize(mat3(gbufferModelView) * worldLightVector);
		bool countVanilla = dist > 0.75 * far;   // closer: the shadow map has the vanilla occluders
		if (dot(n, L) > 0.0) {
			float s0 = max(1.0, 0.005 * dist);
			float k = pow(farShadowReach / s0, 1.0 / float(farShadowSteps));
			float s = s0 * pow(k, noise.x);
			for (int i = 0; i < farShadowSteps; i++, s *= k) {
				vec3 q = start + L * s;
				ivec2 qp;
				if (!ProjectToPixel(q, qp)) break;
				vec4 o = SceneViewPos(qp);
				if (o.w == 0.0 || (o.w == 1.0 && !countVanilla)) continue;
				// q is behind the visible surface, and that surface lies at a comparable depth (a ridge
				// between the point and the sun): a much closer object (wall, entity) only hides q on
				// screen and says nothing about the light reaching it
				float qd = -q.z, od = -o.z;
				float behind = od < qd ? qd - od : 0.0;
				float eps = 0.002 * qd + 0.5;
				float occ = smoothstep(eps, 4.0 * eps, behind) * smoothstep(0.7, 0.8, od / qd) * step(behind, s + 32.0);
				sun = min(sun, 1.0 - occ);
				if (sun < 0.01) break;
			}
		}

		// Ambient occlusion where the GI is replaced by the flat sky ambient
		float ao = 1.0;
		if (cheb > RAY_TRACING_RADIUS - 6.0) {
			float R = clamp(0.04 * dist, 8.0, 64.0);
			vec3 t = normalize(cross(n, abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
			vec3 b = cross(n, t);
			float occ = 0.0;
			for (int i = 0; i < farAOSamples; i++) {
				// cosine weighted hemisphere, sample lengths spread over the radius
				vec2 h = fract(vec2(float(i) * 0.618034 + noise.y, float(i) * 0.7548777 + noise.z));
				float phi = 6.2831853 * h.x, sr = sqrt(h.y);
				vec3 dir = t * (cos(phi) * sr) + b * (sin(phi) * sr) + n * sqrt(1.0 - h.y);
				float len = R * mix(0.15, 1.0, fract(float(i) * 0.38196601 + noise.x));
				vec3 q = start + dir * len;
				ivec2 qp;
				if (!ProjectToPixel(q, qp)) continue;
				vec4 o = SceneViewPos(qp);
				if (o.w == 0.0) continue;
				float behind = o.z - q.z;
				if (behind > 0.002 * -q.z + 0.25) occ += clamp(1.0 - (behind - R) / R, 0.0, 1.0);
			}
			ao = 1.0 - farAOStrength * occ / float(farAOSamples);
		}
		imageStore(farShade, rp, vec4(ao, sun, dist * 0.001, 1.0));
	#endif
}
