#if MC_VERSION >= 11700
in vec4 mc_Entity;
#elif MC_VERSION >= 11500
layout(location = 11) in vec4 mc_Entity;
#else
layout(location = 10) in vec4 mc_Entity;
#endif


out mat3 tbnMatrix;
out vec4 texcoord;
out vec4 viewPosition;
out vec3 worldPosition;
out vec3 viewVector;
out vec3 worldNormal;
out vec3 normal;
out vec2 blockLight;
flat out float isWater;
flat out float isStainedGlass;
flat out float isSlime;


#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"
#include "/lib/TAA.inc"
#include "/lib/PhysicsOcean.inc"

#ifdef PHYSICS_OCEAN
    #ifdef PHYSICS_OCEAN_V2
        in float physics_waviness;
    #endif

    out vec3 physics_localPosition;
    out float physics_localWaviness;
#endif

void main() {

	isWater = 0.0;
	isStainedGlass = 1.0;
	isSlime = 0.0;

	if(mc_Entity.x == 8 || mc_Entity.x == 9 || mc_Entity.x == 389)
	{
		isWater = 1.0;
		isStainedGlass = 0.0;
	}

	if (mc_Entity.x == 165)
	{
		isSlime = 1.0;
		isStainedGlass = 0.0;
	}


    #ifdef PHYSICS_OCEAN
        #ifdef PHYSICS_OCEAN_V2
            // basic value to determine how shallow/far away from the shore the water is
            physics_localWaviness = physics_waviness;
            // transform gl_Vertex (since it is the raw mesh, i.e. not transformed yet)
            float baseWaveHeight = physics_waveHeight(gl_Vertex.xz, PHYSICS_ITERATIONS_OFFSET, physics_localWaviness, physics_gameTime);
            float rippleHeight = physics_rippleVertexHeight(gl_Vertex.xz);
            // pass this to the fragment shader to fetch the texture there for per fragment normals
            physics_localPosition = vec3(gl_Vertex.x, gl_Vertex.y + baseWaveHeight + rippleHeight, gl_Vertex.z);
        #else
            physics_localWaviness = texelFetch(physics_waviness, ivec2(gl_Vertex.xz) - physics_textureOffset, 0).r;
            physics_localPosition = gl_Vertex.xyz + vec3(0.0, physics_waveHeight(gl_Vertex.xz, PHYSICS_ITERATIONS_OFFSET, physics_localWaviness, physics_gameTime), 0.0);
        #endif

        viewPosition = gl_ModelViewMatrix * vec4(physics_localPosition, 1.0);
    #else
        viewPosition = gl_ModelViewMatrix * gl_Vertex;
    #endif

	vec4 position = gbufferModelViewInverse * viewPosition;

	worldPosition.xyz = position.xyz + cameraPosition.xyz;

	gl_Position = gl_ProjectionMatrix * viewPosition;

	FinalVertexTransformTAA(gl_Position);

	gl_Position.z -= 0.0001;

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

	vec4 lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

	blockLight = clamp((lmcoord.st * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);

	gl_FogFragCoord = gl_Position.z;




	normal = normalize(gl_NormalMatrix * gl_Normal);
	vec3 tangent = vec3(0.0), binormal = vec3(0.0);

	if (abs(gl_Normal.x) > 0.5) {
		//  1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0, -sign(gl_Normal.x)));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (abs(gl_Normal.y) > 0.5) {
		//  0.0,  1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (abs(gl_Normal.z) > 0.5) {
		//  0.0,  0.0,  1.0
		tangent  = normalize(gl_NormalMatrix * vec3(sign(gl_Normal.z),  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}

	tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
                     tangent.y, binormal.y, normal.y,
                     tangent.z, binormal.z, normal.z);

	viewVector = normalize(tbnMatrix * viewPosition.xyz);


	worldNormal = gl_Normal.xyz;


}
