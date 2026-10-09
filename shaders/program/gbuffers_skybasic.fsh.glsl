in vec4 color;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/TAA.inc"


void main() {
	if (PixelOutOfScreenBounds(gl_FragCoord.st)) {
		discard;
	}
	vec3 skyCol = vec3(0.0);

	float saturation = abs(color.r - color.g) + abs(color.r - color.b) + abs(color.g - color.b);

	if (saturation <= 0.01 && length(color.rgb) > 0.5)
		skyCol.rgb = vec3(0.4);


	gl_FragData[0] = vec4(skyCol.rgb, 1.0);
}

/* DRAWBUFFERS:0 */
