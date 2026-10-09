#extension GL_ARB_gpu_shader5 : enable

#define AVERAGE_EXPOSURE
#define CONTRAST 1.0 // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.25 1.3 1.35 1.4 1.45 1.5 1.6 1.7 1.8 1.9 2.0]

#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/Bloom.inc"


in vec4 texcoord;


const float overlap = 1.9;

const float rgOverlap = 0.1 * overlap;
const float rbOverlap = 0.03 * overlap;
const float gbOverlap = 0.04 * overlap;

const mat3 coneOverlap = mat3(1.0, 			rgOverlap, 	rbOverlap,
							  rgOverlap, 	1.0, 		gbOverlap,
							  rbOverlap, 	rgOverlap, 	1.0);

const mat3 coneOverlapInverse = mat3(	1.0 + (rgOverlap + rbOverlap), 			-rgOverlap, 	-rbOverlap,
									  	-rgOverlap, 		1.0 + (rgOverlap + gbOverlap), 		-gbOverlap,
									  	-rbOverlap, 		-rgOverlap, 	1.0 + (rbOverlap + rgOverlap));

// ACES
const mat3 ACESInputMat = mat3(
    0.59719, 0.35458, 0.04823,
    0.07600, 0.90834, 0.01566,
    0.02840, 0.13383, 0.83777
);

const mat3 ACESOutputMat = mat3(
     1.60475, -0.53108, -0.07367,
    -0.10208,  1.10813, -0.00605,
    -0.00327, -0.07276,  1.07602
);

vec3 Uncharted2Tonemap(vec3 x)
{
	x *= 3.0;

	float A = 0.9;
	float B = 0.8;
	float C = 0.1;
	float D = 1.0;
	float E = 0.02;
	float F = 0.30;

	// x = x * coneOverlap;

	x = ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;

	// x = x * coneOverlapInverse;

    return x;
}

float almostIdentity( float x, float m, float n )
{
    if(x > m) return x;

    float a = 2.0 * n - m;
    float b = 2.0 * m - 3.0 * n;
    float t = x / m;

    return (a * t + b) * t * t + n;
}

vec3 almostIdentity(vec3 x, vec3 m, vec3 n)
{
	return vec3(
		almostIdentity(x.x, m.x, n.x),
		almostIdentity(x.y, m.y, n.y),
		almostIdentity(x.z, m.z, n.z)
		);
}

vec3 BlackDepth(vec3 color, vec3 blackDepth)
{
	vec3 m = blackDepth;
	vec3 n = blackDepth * 0.5;
	return (almostIdentity(color, m, n) - n);
}

vec3 BurgessTonemap(vec3 col)
{
	col *= 0.9;
	// col = col * coneOverlap;

	vec3 maxCol = col;

    const float p = 1.0;
    maxCol = pow(maxCol, vec3(p));

    vec3 retCol = (maxCol * (6.2 * maxCol + 0.05)) / (maxCol * (6.2 * maxCol + 2.3) + 0.06);
	retCol = pow(retCol, vec3(1.0 / p));

	// retCol = retCol * coneOverlapInverse;

    return retCol;
}

vec3 SEUSTonemap(vec3 color)
{
	color *= 1.1;

	const float p = TONEMAP_CURVE;

	color = pow(color, vec3(p));
	color = color / (1.0 + color);
	color = pow(color, vec3((1.0 / GAMMA) / p));

	{
		const float a = 0.3;
		float l = a * a * (3.0 - 2.0 * a);

		vec3 c = color * (1.0 - a) + a;
		
		color = c * c * (3.0 - 2.0 * c);
		color -= l;
		color /= 1.0 - l;
		color = max(vec3(0.0), color);
		color = pow(color, vec3(1.0));
	}

	{
		vec3 c = color;
		color = mix(color, c * c * (3.0 - 2.0 * c), vec3(0.2));
	}

	return color;
}

vec3 ReinhardJodie(vec3 v)
{
	v = pow(v, vec3(TONEMAP_CURVE));
    float l = Luminance(v);
    vec3 tv = v / (1.0f + v);

    vec3 tonemapped = mix(v / (1.0f + l), tv, tv);
	tonemapped = pow(tonemapped, vec3(1.0 / TONEMAP_CURVE));

	return tonemapped;
}

/////////////////////////////////////////////////////////////////////////////////
//	ACES Fitting by Stephen Hill
vec3 RRTAndODTFit(vec3 v)
{
    vec3 a = v * (v + 0.0245786f) - 0.000090537f;
    vec3 b = v * (1.0f * v + 0.4329510f) + 0.238081f;
    return a / b;
}

vec3 ACESTonemap2(vec3 color)
{
	color *= 1.5;
	color = color * ACESInputMat;

    // Apply RRT and ODT
    color = RRTAndODTFit(color);


    // Clamp to [0, 1]
	color = color * ACESOutputMat;
    color = saturate(color);

    return color;
}
/////////////////////////////////////////////////////////////////////////////////

vec3 ACESTonemap(vec3 color)
{
	color *= 0.4;

	// color = color * coneOverlap;

	vec3 crosstalk = vec3(0.05, 0.2, 0.05) * 2.9;

	float avgColor = Luminance(color.rgb);

	const float p = 1.0;

	color = pow(color, vec3(p));

	color = (color * (2.51 * color + 0.03)) / (color * (2.43 * color + 0.59) + 0.14);

	color = pow(color, vec3(1.0 / p));

	// color = color * coneOverlapInverse;

	float avgColorTonemapped = Luminance(color.rgb);

	color = saturate(color);

	color = pow(color, vec3(0.85));

	return color;
}

vec3 ExponentialTonemap(vec3 c)
{
	// c = 1.0 - exp2(-c*1.3);
	
	const vec3 t = vec3(2.0);
	const vec3 p = vec3(10.5);
	
	c = 1.0 - pow((t*c + 1.0) * p, -c);
	return c;
}



void Vignette(inout vec3 color)
{
	float dist = distance(texcoord.st, vec2(0.5f)) * 2.0f;
		  dist /= 1.5142f;

	color.rgb *= 1.0f - dist * 0.5;

}

float AutoExposureMin = mix(0.00064, 0.0000001, nightVision);
const float AutoExposureMult = 25.0;

void AverageExposure(inout vec3 color, float avgLum)
{
	color = (color / (avgLum + AutoExposureMin)) * AutoExposureMult;
}

vec3 Tonemap(vec3 color)
{

	
	// if (TOGGLER > 0.5)
	// {
	color *= coneOverlap;
		color = TONEMAP_OPERATOR(color);
	// // 	// color = (mix(color, vec3(Luminance(color)), vec3(-0.1)));
	// // 	// color = normalize(pow(color, vec3(1.3)) + 0.0000001) * length(color);
	color *= coneOverlapInverse;
	
		color = TransformOutputColor(color);
		return color;

}


void main()
{
	vec3 color = 	(texture2D(colortex1, texcoord.st).rgb);

	color = GammaToLinear(color);

	#ifndef SKIP_AA
	#if PIXEL_LOOK == 1
	{
		vec3 col = vec3(0.0);
		col += GammaToLinear(texture2D(colortex1, texcoord.st + ScreenTexel * vec2(0.0, 0.0)).rgb);
		col += GammaToLinear(texture2D(colortex1, texcoord.st + ScreenTexel * vec2(0.0, 1.0)).rgb);
		col += GammaToLinear(texture2D(colortex1, texcoord.st + ScreenTexel * vec2(1.0, 0.0)).rgb);
		col += GammaToLinear(texture2D(colortex1, texcoord.st + ScreenTexel * vec2(1.0, 1.0)).rgb);
		col /= 4.0;
		color = col;
	}
	#endif
	#endif

	vec3 bloom = GetBloom(texcoord.xy).rgb * 0.01;
	float avgLum = texture2DLod(colortex6, vec2(0.0, 0.0), 0).a * 0.01;
	#ifndef AVERAGE_EXPOSURE
		avgLum = 0.1;
	#endif
	float bloomAmount = 0.06 * BLOOM_AMOUNT;
	bloomAmount /= sqrt(avgLum) * 4.0 + 0.5;
	bloomAmount = mix(bloomAmount, 0.9, saturate(isEyeInWater));
	color = mix(color, bloom, saturate(vec3(bloomAmount)));

	Vignette(color);

	color = BlackDepth(color, vec3(0.000015 * BLACK_DEPTH * BLACK_DEPTH));

	{
		color *= 2.0;

		vec3 oc = color;
		float PP = 3.0;
		color = pow(color, vec3(1.0 / PP));
		color = saturate(color - 0.001);
		color = pow(color, vec3(PP));

		float rL = 0.00000008;
		float rodExcitement = dot(oc, vec3(0.001, 0.3, 0.8));
		rodExcitement = rodExcitement*rL / (rL + rodExcitement);
		color += rodExcitement * vec3(0.2, 0.3, 0.4) * 5.0;

		color /= 2.0;
	}

	AverageExposure(color, avgLum);

	color *= pow(vec3(1.0, 1.07, 1.25), vec3(1.1));

	color *= EXPOSURE;

	// Contrast from [Photon](https://github.com/sixthsurge/photon), MIT Licence
	const float log_midpoint = log2(0.18);
	color = log2(color + 1e-8);
	color = CONTRAST * (color - log_midpoint) + log_midpoint;
	color = max(exp2(color) - 1e-8, 0.0);

	color = saturate(Tonemap(color) * (1.0 + WHITE_CLIP));

	color = pow(color, vec3(1.0 / 2.2 + (1.0 - GAMMA)));

	color = (mix(color, vec3(Luminance(color)), vec3(1.0 - SATURATION)));

	color += (BlueNoiseTemporal(texcoord.st) - 0.95) * (3.0 / 255.0);

	gl_FragData[0] = vec4(color.rgb, Luminance(color.rgb));
}


/* DRAWBUFFERS:0 */
