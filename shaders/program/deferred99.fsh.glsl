layout(location = 0) out vec4 texBuffer0;
layout(location = 1) out vec4 texBuffer1;

uniform sampler2D colortex17;
uniform sampler2D colortex18;

#include "/lib/Uniforms.inc"

void main() {
    ivec2 texel = ivec2(gl_FragCoord.st);
    vec4 trasnparent = texelFetch(colortex17, texel, 0);
    float overlay = float(texelFetch(depthtex1, texel, 0).r == 1.0 && trasnparent.w > 0.0);
    texBuffer0 = mix(texelFetch(colortex1, texel, 0), texelFetch(colortex17, texel, 0), overlay);
    texBuffer1 = mix(texelFetch(colortex2, texel, 0), texelFetch(colortex18, texel, 0), overlay);
}

/* DRAWBUFFERS:12 */
