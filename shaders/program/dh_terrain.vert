#ifndef DISTANT_HORIZONS
    #define DISTANT_HORIZONS
    in int dhMaterialId;
#endif

out vec4 color;
out vec3 worldPos;
out vec3 viewNormal;
out vec2 blockLight;
flat out int materialID;

#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/TAA.inc"
#include "/lib/Materials.inc"

void main() {
    color = gl_Color;
    viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    vec4 lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
    blockLight = clamp(lmcoord.st * 33.05 / 32.0 - 0.0328125f, 0.0, 1.0);
    materialID = 1;

    if (dhMaterialId == DH_BLOCK_LEAVES) {
        materialID = MAT_ID_LEAVES;
    }
    if (dhMaterialId == DH_BLOCK_LAVA) {
        materialID = MAT_ID_LAVA;
    }
    if (dhMaterialId == DH_BLOCK_ILLUMINATED) {
        materialID = MAT_ID_GLOWSTONE;
    }

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    worldPos = (gbufferModelViewInverse * viewPos).xyz + cameraPosition;
    gl_Position = dhProjection * viewPos;
    FinalVertexTransformTAA(gl_Position);
}
