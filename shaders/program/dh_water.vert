#ifndef DISTANT_HORIZONS
    #define DISTANT_HORIZONS
    in int dhMaterialId;
#endif

out vec4 color;
out vec4 viewPos;
out vec3 tangent;
out vec3 binormal;
out vec3 worldPos;
out vec3 viewNormal;
out vec3 viewVector;
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
    materialID = MAT_ID_STAINED_GLASS;

    if (dhMaterialId == DH_BLOCK_WATER) {
        materialID = MAT_ID_WATER;
    }

	if (abs(gl_Normal.x) > 0.5) {
		//  1.0,  0.0,  0.0
		tangent  = vec3( 0.0,  0.0, -sign(gl_Normal.x));
		binormal = vec3( 0.0, -1.0,  0.0);
	} else if (abs(gl_Normal.y) > 0.5) {
		//  0.0,  1.0,  0.0
		tangent  = vec3( 1.0,  0.0,  0.0);
		binormal = vec3( 0.0,  0.0,  1.0);
	} else if (abs(gl_Normal.z) > 0.5) {
		//  0.0,  0.0,  1.0
		tangent  = vec3(sign(gl_Normal.z),  0.0,  0.0);
		binormal = vec3( 0.0, -1.0,  0.0);
	}
    tangent = normalize(gl_NormalMatrix * tangent);
    binormal = normalize(gl_NormalMatrix * binormal);

    viewPos = gl_ModelViewMatrix * gl_Vertex;
    worldPos = (gbufferModelViewInverse * viewPos).xyz + cameraPosition;
    gl_Position = dhProjection * viewPos;
    FinalVertexTransformTAA(gl_Position);

	mat3 tbnMatrix = mat3(tangent.x, binormal.x, viewNormal.x,
                          tangent.y, binormal.y, viewNormal.y,
                          tangent.z, binormal.z, viewNormal.z);
	viewVector = normalize(tbnMatrix * viewPos.xyz);
}
