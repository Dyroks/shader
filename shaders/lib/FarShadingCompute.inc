// Uniforms and screen helpers of the distant terrain shading compute passes (deferred12_b/c)
uniform sampler2D depthtex1;
uniform sampler2D colortex1;
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
uniform vec3 cameraPosition;
uniform vec3 worldLightVector;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform int frameCounter;

vec2 screen;
vec2 jitter;
ivec2 internalSize;

// Sets the globals above and returns the internal pixel handled by this thread (quarter
// resolution, one pixel of each 2x2 block, a different one every frame), or (-1) when none
ivec2 FarShadeSetup(ivec2 rp) {
	screen = vec2(viewWidth, viewHeight);
	internalSize = ivec2(ceil(screen * 0.5));
	ivec2 rsz = (internalSize + 1) / 2;
	if (any(greaterThanEqual(rp, rsz))) return ivec2(-1);
	float f = float(frameCounter & 15);
	jitter = (fract(f * vec2(12664745.0, 9560333.0) / 16777216.0) * 2.0 - 1.0) / screen;
	int i4 = frameCounter & 3;
	return min(rp * 2 + ivec2(i4 == 1 || i4 == 2 ? 1 : 0, i4 == 1 || i4 == 3 ? 1 : 0), internalSize - 1);
}

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

// Gbuffer material id of a pixel (Materials.inc ids)
int GbufferMaterial(ivec2 px) {
	return int(floor(texelFetch(colortex1, px, 0).z * 65535.0 / 256.0 + 0.001));
}
