// =====================================================================================
//  Volumetric clouds - screen space helpers for the compute programs
//
//  This pack renders the scene at half resolution in the bottom-left quadrant of the
//  screen ("HRR") and reconstructs full resolution with its TAA. Cloud buffers are laid
//  out on that internal grid: internal pixel (x, y) == framebuffer pixel (x, y), its
//  texture coordinate is (x + 0.5) / screenSize and lies in [0, 0.5].
// =====================================================================================

#ifndef CLOUD_VIEW_INC
#define CLOUD_VIEW_INC

ivec2 CloudInternalSize() {
	return ivec2(ceil(vec2(viewWidth, viewHeight) * 0.5));
}

// TAA jitter of a given frame (same sequence as JitterSampleOffset in shaders.properties)
vec2 CloudJitter(int frame) {
	float f = float(frame & 15);  // & instead of %: frame - 1 can be negative
	vec2 j = fract(f * vec2(12664745.0, 9560333.0) / 16777216.0);
	return (j * 2.0 - 1.0) / vec2(viewWidth, viewHeight);
}

// View space position from an internal texture coordinate (mirrors GetViewPosition)
vec3 CloudViewPos(vec2 tc, float depth, vec2 jitter, mat4 projInv) {
	tc -= jitter * 0.5;
	vec4 p = projInv * vec4(tc * 4.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	return p.xyz / p.w;
}

vec3 CloudWorldDir(vec2 tc, vec2 jitter) {
	return normalize(mat3(gbufferModelViewInverse) * CloudViewPos(tc, 1.0, jitter, gbufferProjectionInverse));
}

// Distance along the view ray to the first surface (terrain, water, LOD terrain). 1e9 = sky.
float CloudSceneDistance(ivec2 px, vec2 tc, vec2 jitter) {
	float dist = 1e9;
	float d = texelFetch(depthtex0, px, 0).x;
	if (d < 1.0) dist = length(CloudViewPos(tc, d, jitter, gbufferProjectionInverse));

	#if defined VOXY
		float ld = min(textureLod(vxDepthTexOpaque, tc * 2.0, 0.0).x, textureLod(vxDepthTexTrans, tc * 2.0, 0.0).x);
		if (ld < 1.0) dist = min(dist, length(CloudViewPos(tc, ld, jitter, vxProjInv)));
	#elif defined DISTANT_HORIZONS
		float ld = textureLod(dhDepthTex0, tc, 0.0).x;
		if (ld < 1.0) dist = min(dist, length(CloudViewPos(tc, ld, jitter, dhProjectionInverse)));
	#endif

	return dist;
}

// Internal texture coordinate of a camera relative position in the previous frame
vec2 CloudReproject(vec3 relPos, vec2 prevJitter) {
	vec3 prevRel = relPos + (cameraPosition - previousCameraPosition);
	vec4 pv = gbufferPreviousModelView * vec4(prevRel, 1.0);
	vec4 pc = gbufferPreviousProjection * pv;
	vec2 ndc = pc.xy / pc.w;
	return (ndc + 1.0) * 0.25 + prevJitter * 0.5;
}

// Which pixel of each 2x2 block is ray marched this frame
ivec2 CloudCheckerOffset(int frame) {
	int i = frame & 3;
	return ivec2(i == 1 || i == 2 ? 1 : 0, i == 1 || i == 3 ? 1 : 0);
}

vec3 CloudLightDirection() {
	return normalize(shadowModelViewInverse[2].xyz);
}

#endif
