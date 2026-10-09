in vec4 texcoord;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/Common.inc"
#include "/lib/Bloom.inc"


void main()
{
	gl_FragData[0] = vec4(CalculateBloomPass1(texcoord.xy), 1.0);
}

/* DRAWBUFFERS:7 */
