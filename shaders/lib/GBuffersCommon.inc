vec3 GetRainAnimationTex(sampler2D tex, vec2 uv, vec2 wet)
{
	float frame = floor(fract(frameTimeCounter) * 60.0);
	vec2 coord = vec2(uv.x, fract(uv.y / 60.0) - frame / 60.0);

	vec3 n = textureLod(tex, coord, 0.0).rgb * 2.0 - 1.0;
	n.y = -n.y;

	n.xy = pow(abs(n.xy), wet) * sign(n.xy);

	return n;
}

vec3 BilateralRainTex(sampler2D tex, vec2 uv, float wet)
{
	vec2 wet3 = vec2(2.0 - wet * wet * wet * 1.2);
	vec3 n = GetRainAnimationTex(tex, uv.xy, wet3);
	vec3 nR = GetRainAnimationTex(tex, uv.xy + vec2(1.0, 0.0) / 128.0, wet3);
	vec3 nU = GetRainAnimationTex(tex, uv.xy + vec2(0.0, 1.0) / 128.0, wet3);
	vec3 nUR = GetRainAnimationTex(tex, uv.xy + vec2(1.0, 1.0) / 128.0, wet3);

	vec2 fractCoord = fract(uv.xy * 128.0);

	vec3 lerpX = mix(n, nR, fractCoord.x);
	vec3 lerpX2 = mix(nU, nUR, fractCoord.x);
	vec3 lerpY = mix(lerpX, lerpX2, fractCoord.y);

	return lerpY;
}



vec3 GetRainSplashNormal(vec3 worldPosition, vec3 worldNormal, inout float wet)
{
	if (wetness < 0.01)
		return vec3(0.0, 0.0, 1.0);

	vec3 pos = worldPosition * 0.5;

	#ifdef RAIN_SPLASH_BILATERAL
	vec3 n = BilateralRainTex(gaux2, pos.xz, wet);
	#else
	vec3 n = GetRainAnimationTex(gaux2, pos.xz, vec2(2.0 - wet * wet * wet * 1.2));
	#endif

	pos.x -= frameTimeCounter * 1.5;
	float downfall = textureLod(noisetex, pos.xz * 0.0025, 0.0).x;
	downfall = saturate(downfall * 1.5 - 0.25);

	float lod = dot(abs(fwidth(pos.xyz)), vec3(20.0));

	n.xy /= 1.0 + lod;

	wet = saturate(wet * 1.0 + downfall * (1.0 - wet) * 0.95);

	n.xy *= rainStrength;

	vec3 rainSplashNormal = n;

	vec3 rainFlowNormal = vec3(0.0, 0.0, 1.0);

	n = mix(rainFlowNormal, rainSplashNormal, saturate(worldNormal.y));

	return n;
}

void CalculateNormalAndTBN(vec3 p, vec2 uv, out vec3 N, out mat3 tbn, out mat3 tbnRaw)
{
	// get edge vectors of the pixel triangle
	vec3 dp1 = dFdx(p);
	vec3 dp2 = dFdy(p);
	vec2 duv1 = dFdx(uv);
	vec2 duv2 = dFdy(uv);

	N = normalize(cross(dp1, dp2));

	// solve the linear system
	vec3 dp2perp = cross(dp2, N);
	vec3 dp1perp = cross(N, dp1);
	vec3 T = normalize(dp2perp * duv1.x + dp1perp * duv2.x);
	vec3 B = normalize(dp2perp * duv1.y + dp1perp * duv2.y);

	tbn = mat3(T, B, N);

	tbnRaw = mat3(T.x, B.x, N.x,
            	  T.y, B.y, N.y,
            	  T.z, B.z, N.z);
}

