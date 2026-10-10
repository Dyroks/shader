// =====================================================================================
//  Volumetric clouds - reading the ray march output and the temporal history after
//  composite4_b (composite4_c, composite4, composite). Needs CloudCommon.inc.
//  CloudSurfaceDistance (pack fragment helpers) is in CloudComposite.inc.
// =====================================================================================

#ifndef CLOUD_HISTORY_INC
#define CLOUD_HISTORY_INC

uniform sampler2D cloudRawSampler;
uniform sampler2D cloudHistASampler;
uniform sampler2D cloudHistBSampler;

// History written by composite4_b this frame (latest = true, after composite4_b) or by the
// previous frame (latest = false, for passes that run before composite4).
vec4 CloudHistory(ivec2 px, bool latest) {
	bool readA = ((frameCounter & 1) == 0) == latest;
	vec4 hist = readA ? texelFetch(cloudHistASampler, px, 0) : texelFetch(cloudHistBSampler, px, 0);
	if (any(isnan(hist)) || any(isinf(hist))) hist = vec4(0.0, 0.0, 1.0, 0.0);
	return hist;
}

// Distance of the clouds seen through an internal pixel (blocks)
float CloudDepthAt(ivec2 px) {
	#if CLOUD_RES == 2
		ivec2 rp = px >> 1;
	#else
		ivec2 rp = px;
	#endif
	float depthKm = texelFetch(cloudRawSampler, rp, 0).w;
	if (depthKm < 0.0) {
		// pixel had no cloud in the latest low resolution sample: use the largest neighbour depth
		depthKm = 0.0;
		ivec2 rawMax = textureSize(cloudRawSampler, 0) - 1;
		for (int i = 0; i < 4; i++) {
			ivec2 o = ivec2(i & 1, i >> 1) * 2 - 1;
			depthKm = max(depthKm, texelFetch(cloudRawSampler, clamp(rp + o, ivec2(0), rawMax), 0).w);
		}
		if (depthKm <= 0.0) depthKm = 10.0 * cloudScale;
	}
	return depthKm * 1000.0;
}

// Clouds can only be visible if the view ray enters the cloud layer before the surface.
// Exact per pixel test: removes any temporal leftover of clouds over near geometry.
bool CloudPossible(vec3 worldDir, float surfaceDist) {
	float tStart, tEnd;
	if (!CloudShellSegment(worldDir, cameraPosition.y, cloudLayerBottom, cloudLayerTop, tStart, tEnd)) return false;
	return surfaceDist > tStart;
}

#endif
