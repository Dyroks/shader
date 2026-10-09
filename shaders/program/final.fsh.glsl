#extension GL_ARB_gpu_shader5 : enable


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"


in vec4 texcoord;


// #define DEPTH_OF_FIELD //Toggle Depth of Field (DoF).
#define DOF_STRENGTH 0.3 //Adjust the maximum Blur Amount. [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define BIAS 0.15 //Adjust the Aperture. Bigger values cause a shallower Depth of Field. [0.04 0.06 0.08 0.10 0.12 0.14 0.15 0.16 0.18 0.20 0.22 0.24]


vec3 GetColorTexture(vec2 coord) {
	return pow(texture2DLod(colortex0, coord, 0).rgb, vec3(2.2));
}

vec3 DepthOfField(float dofblur) {
	vec2 aspectcorrect = vec2(1.0, aspectRatio) * 1.5;

	vec3 col = vec3(0.0);
	col += GetColorTexture(texcoord.st);

	col += GetColorTexture(texcoord.st + (vec2( 0.0,0.4 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.15,0.37 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.29,0.29 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.37,0.15 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.4,0.0 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.37,-0.15 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.29,-0.29 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.15,-0.37 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.0,-0.4 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.15,0.37 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.29,0.29 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.37,0.15 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.4,0.0 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.37,-0.15 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( -0.29,-0.29 )*aspectcorrect) * dofblur);
	col += GetColorTexture(texcoord.st + (vec2( 0.15,-0.37 )*aspectcorrect) * dofblur);

	col += GetColorTexture(texcoord.st + (vec2( 0.15,0.37 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( -0.37,0.15 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( 0.37,-0.15 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( -0.15,-0.37 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( -0.15,0.37 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( 0.37,0.15 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( -0.37,-0.15 )*aspectcorrect) * dofblur*0.9);
	col += GetColorTexture(texcoord.st + (vec2( 0.15,-0.37 )*aspectcorrect) * dofblur*0.9);

	col += GetColorTexture(texcoord.st + (vec2( 0.29,0.29 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( 0.4,0.0 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( 0.29,-0.29 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( 0.0,-0.4 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( -0.29,0.29 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( -0.4,0.0 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( -0.29,-0.29 )*aspectcorrect) * dofblur*0.7);
	col += GetColorTexture(texcoord.st + (vec2( 0.0,0.4 )*aspectcorrect) * dofblur*0.7);

	col += GetColorTexture(texcoord.st + (vec2( 0.29,0.29 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( 0.4,0.0 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( 0.29,-0.29 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( 0.0,-0.4 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( -0.29,0.29 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( -0.4,0.0 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( -0.29,-0.29 )*aspectcorrect) * dofblur*0.4);
	col += GetColorTexture(texcoord.st + (vec2( 0.0,0.4 )*aspectcorrect) * dofblur*0.4);

	vec3 color = col/41;
	color = pow(color, vec3(1.0 / 2.2));

	return color;
}


void main() {

	vec3 color = texture2D(colortex0, texcoord.st).rgb;
	// color = GammaToLinear(color);

	#ifndef SKIP_AA
	// Sharpen
	{
		vec2 texel = 0.5 / vec2(viewWidth, viewHeight);
		vec3 cs = texture2D(colortex0, texcoord.st + vec2(texel.x, texel.y)  ).rgb;
		cs += 	  texture2D(colortex0, texcoord.st + vec2(texel.x, -texel.y) ).rgb;
		cs += 	  texture2D(colortex0, texcoord.st + vec2(-texel.x, texel.y) ).rgb;
		cs += 	  texture2D(colortex0, texcoord.st + vec2(-texel.x, -texel.y)).rgb;
		cs -= color;
		cs /= 3.0;

		float gain = 0.5;
		#if PIXEL_LOOK == 1
		gain = 1.0;
		#endif

		// color += clamp(dot(color - cs, vec3(0.333333)), -0.001, 0.001) * 12.3 * pow(Luminance(color), 0.5);
		const float sClamp = 0.1;
		color += clamp(dot(color - cs, vec3(0.333333)), -sClamp, sClamp)
				* gain * POST_SHARPENING
				* sqrt(Luminance(color)) * normalize(color.rgb + 0.00000001);
	}
	#endif

	#ifdef DEPTH_OF_FIELD
	float depth = texture2D(depthtex0, texcoord.st * 0.5).x;
	if(depth < 0.7) {
		depth += 0.45f;
	}
	float dofblur = (depth - texture2D(depthtex0, vec2(0.25)).x) * BIAS * DOF_STRENGTH;
	vec3 dofColor = DepthOfField(dofblur);
	color = mix(dofColor, color, saturate(exp(-dofblur * 1000.0)));
	#endif

	gl_FragColor = vec4(color, 1.0);
}
