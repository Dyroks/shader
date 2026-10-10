in vec4 texcoord;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/Bloom.inc"


const bool colortex7MipmapEnabled = true;


vec3 GetColorTexture(vec2 coord)
{
	return pow(texture2DLod(colortex1, coord, 0).rgb, vec3(2.2));
}

void main() {


	vec3 color = vec3(0.0);

	color = GetColorTexture(texcoord.st);

	#ifdef MOTION_BLUR
	float VelMult = 0.125 * MOTION_BLUR_INTENSITY;

	vec2 velocity = (texture2DLod(colortex2, texcoord.xy / 16.0, 0).xy * 2.0 - 1.0) * VelMult * 0.04;

	vec3 dither = BlueNoiseTemporal(texcoord.xy);


	vec3 sum = vec3(0.0);
	#ifdef AB_POST
	// camera still: the taps would all land within a few hundredths of a pixel
	if (dot(abs(velocity * ScreenSize), vec2(1.0)) < 0.01)
		sum = color * 5.0;
	else
	#endif
	for (int i = -2; i <= 2; i++)
	{
		vec2 offs = float(i + dither.x) * velocity;
		vec2 coord = texcoord.xy + offs;

		sum += GetColorTexture(coord);
	}

	sum /= 5.0;
	color = sum;
	#endif


	color = pow(color, vec3(1.0 / 2.2));


	gl_FragData[0] = vec4(color, Luminance(color));
	gl_FragData[1] = vec4(CalculateBloomPass0(texcoord.xy), 1.0);
}

/* DRAWBUFFERS:17 */
