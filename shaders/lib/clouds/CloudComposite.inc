// =====================================================================================
//  Volumetric clouds - composition into the lit scene (composite4.fsh) and into the
//  screen space sky reflections (composite.fsh)
//
//  Included after the pack's Settings/Uniforms/Common, so the SEUS atmosphere functions
//  and the LOD helpers are available.
// =====================================================================================

#ifndef CLOUD_COMPOSITE_INC
#define CLOUD_COMPOSITE_INC

#ifndef CLOUD_WORLDDAY_DECLARED
#define CLOUD_WORLDDAY_DECLARED
uniform int worldDay;
#endif
uniform float thunderStrength;
uniform vec4 lightningBoltPosition;   // camera relative, w = 1 while a bolt exists

#include "/lib/clouds/CloudCommon.inc"
#include "/lib/clouds/CloudShading.inc"

#include "/lib/clouds/CloudHistory.inc"
#if CLOUD_DEBUG_VIEW == 2
uniform sampler3D cloudWeatherNearSampler;
#endif

// Scene radiance units: composite4 works with (deferred12 radiance) * 0.001 * 120
const float cloudToComposite = 0.12;

vec3 CloudHeatColor(float x) {
	x = CloudSat(x);
	return CloudSat(vec3(x * 3.0 - 1.0, x < 0.5 ? x * 2.0 : 2.0 - x * 2.0, 1.0 - x * 3.0)) + vec3(0.02);
}

// Light of lightning flashes scattered by the clouds (deferred12 units). Applied here rather
// than in the ray march so flashes are instant (no temporal accumulation).
// cloudPos: camera relative position of the clouds seen by the pixel, T: their transmittance
vec3 CloudLightning(vec3 cloudPos, float T) {
	if (CLOUD_LIGHTNING <= 0.0 || (thunderStrength <= 0.0 && lightningBoltPosition.w < 0.5)) return vec3(0.0);
	float flash = 0.0;

	// the vanilla bolt: its channel lights the cloud base and the inside of the cloud above it
	if (lightningBoltPosition.w > 0.5) {
		vec3 b = lightningBoltPosition.xyz;
		float top = cloudAltitude + 3.0 * cloudKm - cameraPosition.y;
		vec3 d = cloudPos - vec3(b.x, clamp(cloudPos.y, b.y, top), b.z);
		float flicker = 0.55 + 0.45 * CloudHash(ivec2(int(frameTimeCounter * 24.0), 7), 31).x;
		flash += 1.5 * flicker * exp(-length(d) / (2.5 * cloudKm));
	}

	// flashes inside the storm clouds, at random places around the camera
	const float slotLen = 0.8;   // seconds
	float slot = floor(frameTimeCounter / slotLen);
	vec4 h = CloudHash(ivec2(int(slot), 11), 4242);
	if (h.x < thunderStrength * 0.12) {   // about one flash every 7 s
		float tIn = frameTimeCounter - (slot + h.y * 0.5) * slotLen;
		float dur = 0.12 + 0.25 * h.z;
		if (tIn > 0.0 && tIn < dur) {
			float strobe = CloudHash(ivec2(int(frameTimeCounter * 20.0), 13), 4243).x;
			float az = h.w * 6.2831853;
			float dist = mix(2.0, 20.0, fract(h.z * 7.31)) * cloudKm;
			vec3 fp = vec3(cos(az) * dist, cloudAltitude + mix(1.0, 5.0, fract(h.y * 5.17)) * cloudKm - cameraPosition.y, sin(az) * dist);
			flash += (0.35 + 0.65 * strobe) * exp(-length(cloudPos - fp) / (3.0 * cloudKm));
		}
	}
	return vec3(0.72, 0.8, 1.0) * (6.0 * CLOUD_LIGHTNING * flash * (1.0 - T));
}

// Distance to the first surface (terrain, water, LOD terrain) through an internal texture
// coordinate, 1e9 for the sky
float CloudSurfaceDistance(vec2 tc) {
	float dist = 1e9;
	float d = textureLod(depthtex0, tc, 0.0).x;
	if (d < 1.0) dist = length(GetViewPosition(tc, d).xyz);
	#ifdef LOD
		float ld = min(getLodDepthSolid(tc), getLodDepthWater(tc));
		if (ld < 1.0) dist = min(dist, length(GetViewPositionLod(tc, ld).xyz));
	#endif
	return dist;
}

// color   : scene colour in composite4 units (modified in place)
// worldDir: normalised camera to pixel direction
// tc      : internal texture coordinate (0..0.5)
// skyAmbient: average sky radiance (deferred12 units)
// cloudTD : x = transmittance of the clouds, y = their distance (blocks, 1e9 if none)
void CloudComposite(inout vec3 color, vec3 worldDir, vec2 tc, vec3 skyAmbient, out vec2 cloudTD) {
	ivec2 px = ivec2(tc * vec2(viewWidth, viewHeight));
	cloudTD = vec2(1.0, 1e9);
	#if CLOUD_DEBUG_VIEW != 2 && CLOUD_DEBUG_VIEW != 3
		if (!CloudPossible(worldDir, CloudSurfaceDistance(tc))) {
			#if CLOUD_DEBUG_VIEW == 1
				color = vec3(0.0);
			#elif CLOUD_DEBUG_VIEW == 4
				color = vec3(2.0);
			#endif
			return;
		}
	#endif

	vec4 hist = CloudHistory(px, true);
	float T = CloudSat(hist.z);
	float depth = CloudDepthAt(px);
	cloudTD = vec2(T, depth);
	vec3 cloudColor = CloudShade(hist.xyz, depth, worldDir, cameraPosition.y, worldSunVector, colorSunlight, skyAmbient);
	cloudColor = DoNightEyeAtNight(cloudColor, timeMidnight) + CloudLightning(worldDir * depth, T);

	#if CLOUD_DEBUG_VIEW == 0
		color = color * T + cloudColor * cloudToComposite;
	#elif CLOUD_DEBUG_VIEW == 1
		color = cloudColor * cloudToComposite;
	#elif CLOUD_DEBUG_VIEW == 2
		color = color * T + cloudColor * cloudToComposite;
		if (tc.x < 0.2 && tc.y < 0.2) {
			vec2 uv = tc / 0.2;
			vec4 w = textureLod(cloudWeatherNearSampler, vec3(uv, 0.25), 0.0);
			color = vec3(w.x, w.z / 3.0, w.w) * 2.0;
			if (max(abs(uv.x - 0.5), abs(uv.y - 0.5)) < 0.004) color = vec3(4.0);
		}
	#elif CLOUD_DEBUG_VIEW == 3
		#if CLOUD_RES == 2
			ivec2 rp = px >> 1;
		#else
			ivec2 rp = px;
		#endif
		color = CloudHeatColor(texelFetch(cloudRawSampler, rp, 0).y) * 2.0;
	#elif CLOUD_DEBUG_VIEW == 4
		color = vec3(T) * 2.0;
	#endif
}

// Screen space reflections that land on the sky read the sky drawn by deferred12, before
// the clouds are composited (composite4). Put the clouds back from the previous frame's
// cloud history, reprojected to where this direction was on screen in that frame (so the
// reflected clouds follow camera rotations without lag). Off screen: the sky capture.
// skyColor: sky colour read from the screen (any unit), unitScale: that unit / deferred12 unit
vec3 CloudOverScreenSky(vec3 skyColor, vec3 worldDir, vec2 tc, vec3 skyAmbient, float unitScale) {
	ivec2 px = ivec2(tc * vec2(viewWidth, viewHeight));
	float depth = CloudDepthAt(px);

	vec3 prevRel = worldDir * depth + (cameraPosition - previousCameraPosition);
	vec4 pc = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(prevRel, 1.0));
	vec2 prevTc = (pc.xy / pc.w + 1.0) * 0.25;
	vec2 prevPx = prevTc * vec2(viewWidth, viewHeight);
	vec2 histSize = vec2(textureSize(cloudHistASampler, 0));
	vec2 internalSize = ceil(vec2(viewWidth, viewHeight) * 0.5);
	if (pc.w <= 0.0 || any(lessThan(prevPx, vec2(0.5))) || any(greaterThan(prevPx, internalSize - 0.5))) {
		#if defined CLOUD_SKY_LOOKUPS && defined CLOUD_SKY_LIGHTING
			return CloudSkyLookup(worldDir).rgb * unitScale;
		#else
			return skyColor;
		#endif
	}

	// previous frame history = the one not written this frame yet
	vec2 uv = prevPx / histSize;
	vec4 hist = (frameCounter & 1) == 0 ? textureLod(cloudHistBSampler, uv, 0.0) : textureLod(cloudHistASampler, uv, 0.0);
	if (any(isnan(hist)) || any(isinf(hist))) return skyColor;

	vec3 cloudColor = CloudShade(hist.xyz, depth, worldDir, cameraPosition.y, worldSunVector, colorSunlight, skyAmbient);
	cloudColor = DoNightEyeAtNight(cloudColor, timeMidnight) + CloudLightning(worldDir * depth, CloudSat(hist.z));
	return skyColor * CloudSat(hist.z) + cloudColor * unitScale;
}

#endif
