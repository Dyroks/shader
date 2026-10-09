out vec4 color;
out vec4 texcoord;
out vec4 viewPos;
out vec3 worldPosition;
out vec3 worldNormal;
out vec2 blockLight;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/TAA.inc"


void main() {

	color = gl_Color;

	texcoord = gl_MultiTexCoord0;

	vec4 lmcoord = gl_TextureMatrix[1]*gl_MultiTexCoord1;

	blockLight = clamp((lmcoord.st * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);

	worldNormal = gl_Normal;

	viewPos = gl_ModelViewMatrix * gl_Vertex;

	vec4 localWorldPos = gbufferModelViewInverse * viewPos;

	worldPosition = localWorldPos.xyz + cameraPosition.xyz;

	gl_Position = gl_ProjectionMatrix * viewPos;

	gl_Position.z -= 1e-5;

	FinalVertexTransformTAA(gl_Position);
}
