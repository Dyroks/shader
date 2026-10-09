in vec4 color;
in vec4 texcoord;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/TAA.inc"


void main()
{
	if (PixelOutOfScreenBounds(gl_FragCoord.st)) {
		discard;
	}
	vec4 albedo = color;
	albedo.a = 1.0;

	albedo *= texture2D(texture, texcoord.xy);

	gl_FragData[0] = albedo;
}

/* DRAWBUFFERS:0 */
