in vec4 color;
in vec3 worldPos;
in vec3 worldNormal;
in vec2 offsetCenter;

#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"

// #define DH_SHADOW_FIX

void main() {
	vec2 offset = gl_FragCoord.st - offsetCenter;
    if (any(greaterThan(abs(offset), vec2(1024.0))) || max(dot(worldPos.xz, worldPos.xz), worldPos.y * worldPos.y) < (far - 16.0) * (far - 16.0)) {
        discard;
    }
	vec4 albedo = color;
	if (color.w == 1.0) {
		ivec3 pixelPos = ivec3(floor(worldPos * 16.0 + 1e-3));
		ivec2 texel = (pixelPos.xz + 17 * pixelPos.y) & 63;
		float noise = texelFetch(noisetex, texel, 0).r;
		albedo.rgb = pow(albedo.rgb, vec3(noise * 0.3 + 0.85));
	}

	/*  Huge surface fix code from Sunial-GeForceLegend  */
	#ifdef DH_SHADOW_FIX
		/* Inverse disortion of shadow coord */
		float depth = gl_FragCoord.z * 10.0 - 7.0;
		vec3 shadowProjPos = vec3(offset / 1024.0, depth);
		float shadowBias = (1.0 - SHADOW_MAP_BIAS) / (0.95 - length(shadowProjPos.st) * SHADOW_MAP_BIAS);
		shadowProjPos.st *= shadowBias;
		/*  Change it to fit your disortion  */

		vec3 shadowViewPos = vec3(shadowProjectionInverse[0].x, shadowProjectionInverse[1].y, shadowProjectionInverse[2].z) * shadowProjPos + shadowProjectionInverse[3].xyz;
		vec3 pixelWorldPos = mat3(shadowModelViewInverse) * shadowViewPos + shadowModelViewInverse[3].xyz;
		vec3 positionDiff = worldPos - pixelWorldPos;
		float pixelDistanceToFace = dot(positionDiff, worldNormal);
		float NdotL = dot(worldNormal, shadowModelViewInverse[2].xyz);
		float offsetLength = uintBitsToFloat(floatBitsToUint(pixelDistanceToFace / max(1e-5, abs(NdotL))) ^ (floatBitsToUint(NdotL) & 0x80000000u));
		// 0.1 = 0.5 * Z_multiplier_of_PTGI
		gl_FragDepth = gl_FragCoord.z + offsetLength * shadowProjection[2].z * 0.1;
	#endif
	/* Plz make a credit while using it in other project */

    float x = min(albedo.w * 7.0, 1.0);
    albedo.xyz=normalize(albedo.xyz + 1e-4)*pow(dot(albedo.xyz,albedo.xyz), 0.25);
    albedo.xyz=mix(vec3(1.0), albedo.xyz, vec3(pow(albedo.w, 0.2)));
    gl_FragData[0]=vec4(albedo.xyz,x);
    gl_FragData[1]=vec4(1.-((worldPos.y+cameraPosition.y)/512.+.25),0.,0.,x);
}
