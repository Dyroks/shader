// =====================================================================================
//  GI module: the surface seen through a pixel (G-buffer of the pack)
//
//  GI pixels: the internal resolution of the pack (HRR: the G-buffer fills the lower left
//  quarter of the screen buffers), ceil(screen / 2) pixels.
//  G-buffer: depthtex1 (depth of the solid surfaces), colortex1 (x = block / sky light map,
//  w = parallax depth, two 8 bit values per channel), colortex2 (view space normal and
//  geometry normal, spheremap encoded); Voxy or Distant Horizons depth beyond the chunks.
//
//  Uniforms: depthtex1, colortex1, colortex2, gbufferProjectionInverse,
//  gbufferModelViewInverse, viewWidth, viewHeight, JitterSampleOffset (+ LOD depth).
// =====================================================================================

#ifndef GI_SURFACE_INC
#define GI_SURFACE_INC

struct GiSurface {
	bool  valid;      // solid surface inside the voxel volume
	vec3  rel;        // camera relative position
	float dist;       // length(rel)
	vec3  normal;     // world normal (with the normal map)
	vec3  geoNormal;  // world normal of the geometry
	vec3  viewDir;    // from the camera to the surface, unit
	float skyLight;   // sky light map, curved as the pack does
	float parallax;   // depth of the parallax displacement
};

ivec2 GiInternalSize() {
	return ivec2(ceil(vec2(viewWidth, viewHeight) * 0.5));
}

vec2 GiUnpack8(float v) {
	v *= 65535.0;
	return vec2(floor(v / 256.0), mod(v, 256.0)) / 255.0;
}

vec3 GiDecodeNormal(vec2 enc) {
	vec2 f = enc * 4.0 - 2.0;
	float l = dot(f, f);
	return vec3(f * sqrt(1.0 - l / 4.0), 1.0 - l / 2.0);
}

GiSurface GiReadSurface(ivec2 px) {
	GiSurface s;
	s.valid = false;
	vec2 screen = vec2(viewWidth, viewHeight);
	vec2 tc = (vec2(px) + 0.5) / screen;
	vec2 tcJ = tc;
	#ifndef SKIP_AA
		tcJ -= JitterSampleOffset * 0.5;
	#endif
	float depth = texelFetch(depthtex1, px, 0).x;
	vec4 vp;
	if (depth < 1.0) {
		vp = gbufferProjectionInverse * vec4(tcJ * 4.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	} else {
		#if defined VOXY
			float lodDepth = textureLod(vxDepthTexOpaque, tc * 2.0, 0.0).x;
			if (lodDepth >= 1.0) return s;
			vp = vxProjInv * vec4(tcJ * 4.0 - 1.0, lodDepth * 2.0 - 1.0, 1.0);
		#elif defined DISTANT_HORIZONS
			float lodDepth = textureLod(dhDepthTex0, tc, 0.0).x;
			if (lodDepth >= 1.0) return s;
			vp = dhProjectionInverse * vec4(tcJ * 4.0 - 1.0, lodDepth * 2.0 - 1.0, 1.0);
		#else
			return s;
		#endif
	}
	vp.xyz /= vp.w;
	s.rel = mat3(gbufferModelViewInverse) * vp.xyz + gbufferModelViewInverse[3].xyz;
	if (max(max(abs(s.rel.x), abs(s.rel.y)), abs(s.rel.z)) > RAY_TRACING_RADIUS) return s;   // beyond the voxels
	s.dist = length(s.rel);
	s.viewDir = s.rel / max(s.dist, 1e-6);
	vec4 normals = texelFetch(colortex2, px, 0);
	s.normal = normalize(mat3(gbufferModelViewInverse) * GiDecodeNormal(normals.xy));
	s.geoNormal = normalize(mat3(gbufferModelViewInverse) * GiDecodeNormal(normals.zw));
	vec4 data = texelFetch(colortex1, px, 0);
	float sky = GiUnpack8(data.x).y;
	sky = 1.0 - pow(1.0 - sky, 0.45);
	s.skyLight = sky * sky * sky;
	s.parallax = GiUnpack8(data.w).y;
	s.valid = true;
	return s;
}

// Light leak fixes: underground surfaces (no sky light) get no sunlight and no sky light from
// the GI, so light cannot leak through the edge of the volume or through thin walls
void GiLeakFixes(GiSurface s, out float skyLightFix, out float sunLightFix) {
	skyLightFix = 1.0;
	sunLightFix = 1.0;
	if (isEyeInWater < 1) {
		#ifdef SUNLIGHT_LEAK_FIX
			sunLightFix = giSat(s.skyLight * 100.0);
		#endif
		#ifdef CAVE_GI_LEAK_FIX
			skyLightFix = giSat(s.skyLight * 10.0);
		#endif
	}
	sunLightFix *= skyLightFix;
}

// Origin of the GI rays (volume coordinates): off the surface, and back toward the camera
// on parallax surfaces
vec3 GiRayOrigin(GiSurface s) {
	vec3 start = s.rel + s.normal * (0.0001 * s.dist)
	           - s.viewDir * (s.parallax * 0.4 / (giSat(dot(s.geoNormal, -s.viewDir)) + 1e-6) + 0.0008);
	return clamp(GiVolumePos(start), vec3(-1.0), vec3(RAY_TRACING_DIAMETER - 1.0));
}

#endif
