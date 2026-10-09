layout(triangles) in;
layout(triangle_strip, max_vertices = 7) out;


in vec4 vTexcoord[];
in vec4 vColor[];
in vec4 voxelCoord[];
in vec4 vWorldPos[];
in vec4 vVoxelOrigin[];
in vec2 vOffsetCenter[];
in vec2 vMidTexCoord[];
in float vMaterialIDs[];
in float vMCEntity[];
in float ignore[];
in float voxelDepth[];


out vec4 color;
out vec4 texcoord;
out vec3 worldPos;
out vec2 midTexCoord;
out float textureResolution;
out float materialIDs;
out float mcEntity;
out float isVoxelOutput;


#include "/lib/Uniforms.inc"


const int shadowMapResolution = 8192; // Higher value impacts performance costs, but can get better shadow, and increase path tracing distance. Please increase the shadow distance at the same time. 4096 - 80 blocks path tracing. 8192 - 160 blocks path tracing. 16384 - 300 blocks path tracing, requires at least 6GB VRAM. 34768 - 530 blocks of path tracing, requires at least 20GB VRAM. [4096 8192 16384 32768]
const float SHADOW_MAP_RESOLUTION = shadowMapResolution * MC_SHADOW_QUALITY;


void main()
{
	int i;


	//Standard shadow pos
	for (i = 0; i < 3; i++)
	{
		gl_Position = gl_in[i].gl_Position;

		color = vColor[i];
		texcoord = vTexcoord[i];
		worldPos = vWorldPos[i].xyz;
		midTexCoord = vOffsetCenter[i];
		textureResolution = 0.0;
		materialIDs = 0.0;
		mcEntity = 0.0;
		isVoxelOutput = 0.0;

		EmitVertex();
	}
	EndPrimitive();


	//Voxel pos
	if (ignore[0] + ignore[1] + ignore[2] < 0.5 &&
		distance(voxelCoord[0].xy, voxelCoord[1].xy) < 4.0 / SHADOW_MAP_RESOLUTION &&
		distance(voxelCoord[0].xy, voxelCoord[2].xy) < 4.0 / SHADOW_MAP_RESOLUTION &&
		distance(voxelCoord[1].xy, voxelCoord[2].xy) < 4.0 / SHADOW_MAP_RESOLUTION)
	{
		vec2 texCoordUnit[3] = vec2[3](abs(vTexcoord[0].st - vTexcoord[1].st) / distance(vWorldPos[0].xyz, vWorldPos[1].xyz),
									   abs(vTexcoord[1].st - vTexcoord[2].st) / distance(vWorldPos[1].xyz, vWorldPos[2].xyz),
									   abs(vTexcoord[2].st - vTexcoord[0].st) / distance(vWorldPos[2].xyz, vWorldPos[0].xyz));
		vec2 maxCoordUnit = max(texCoordUnit[0], max(texCoordUnit[1], texCoordUnit[2]));
		float maxTextureResolution = max(atlasSize.x * maxCoordUnit.x, atlasSize.y * maxCoordUnit.y);

		float depth = max(voxelDepth[0], max(voxelDepth[1], voxelDepth[2]));

		for (i = 0; i < 3; i++)
		{
			vec2 offset = sign(vec2(vTexcoord[i].s, vMidTexCoord[i].t) - vec2(vMidTexCoord[i].s, vTexcoord[i].t));
			gl_Position = vVoxelOrigin[0];
			gl_Position.z = depth;
			gl_Position.xy += offset / (SHADOW_MAP_RESOLUTION);

			color = vColor[0];
			texcoord = vTexcoord[0];
			worldPos = vWorldPos[0].xyz;
			midTexCoord = vMidTexCoord[0];
			textureResolution = maxTextureResolution;
			materialIDs = vMaterialIDs[0];
			mcEntity = vMCEntity[0];
			isVoxelOutput = 1.0;

			EmitVertex();
		}
		EndPrimitive();
	}
}
