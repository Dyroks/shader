layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"

in vec4 Vcolor[];
in vec4 Vtexcoord[];
in vec4 VviewPos[];
in vec3 VworldPosition[];
in vec3 VworldNormal[];
in vec2 VblockLight[];
flat in float VmaterialIDs[];

out vec4 color;
out vec4 texcoord;
out vec4 viewPos;
out vec3 worldNormal;
out vec2 blockLight;
flat out float materialIDs;
flat out float textureResolution;

void main()
{
    int i, j;

    vec3 posDiff[3] = vec3[3](VworldPosition[0] - VworldPosition[1],
                              VworldPosition[1] - VworldPosition[2],
                              VworldPosition[2] - VworldPosition[0]);
    vec3 posDiffLength2 = vec3(dot(posDiff[0], posDiff[0]),
                               dot(posDiff[1], posDiff[1]),
                               dot(posDiff[2], posDiff[2]));
    vec3 posDiffLength = sqrt(posDiffLength2);
    vec2 texCoordUnit[3] = vec2[3](abs(Vtexcoord[0].st - Vtexcoord[1].st) / posDiffLength.x,
                                   abs(Vtexcoord[1].st - Vtexcoord[2].st) / posDiffLength.y,
                                   abs(Vtexcoord[2].st - Vtexcoord[0].st) / posDiffLength.z);
    vec2 maxCoordUnit = max(texCoordUnit[0], max(texCoordUnit[1], texCoordUnit[2]));

    float maxTextureResolution = max(atlasSize.x * maxCoordUnit.x, atlasSize.y * maxCoordUnit.y);

    #ifdef SKYLIGHT_FIX
    const float lightUnit = 1.0 / 15.0;

    vec3 lightDiff = vec3(VblockLight[0].y - VblockLight[1].y,
                          VblockLight[1].y - VblockLight[2].y,
                          VblockLight[2].y - VblockLight[0].y);
    vec3 lightDiffUnit[3] = vec3[3](lightDiff.x * posDiff[0] / posDiffLength2.x,
                                    lightDiff.y * posDiff[1] / posDiffLength2.y,
                                    lightDiff.z * posDiff[2] / posDiffLength2.z);
    int lightIndex = 0;
    int asixIndex = 0;
    int maxLightIndex = 0;
    float maxLightDiffUnit = 0.0;
    float maxAbsLightDiffUnit = 0.0;
    for(i = 0; i < 3; i++)
    {
        maxLightIndex = VblockLight[i].y > VblockLight[maxLightIndex].y ? i : maxLightIndex;
        for(j = 0; j < 3; j++)
        {
            float currLightDiffUnit = abs(lightDiffUnit[i][j]);
            if(currLightDiffUnit > maxAbsLightDiffUnit) {
                lightIndex = i;
                asixIndex = j;
                maxLightDiffUnit = lightDiffUnit[i][j];
                maxAbsLightDiffUnit = currLightDiffUnit;
            }
        }
    }
    float maxLight = VblockLight[maxLightIndex].y;
    float lightFixUnit = maxAbsLightDiffUnit - lightUnit;
    float direction = sign(maxLightDiffUnit);
    #endif

    for(i = 0; i < 3; i ++)
    {
        gl_Position = gl_in[i].gl_Position;

        color = Vcolor[i];
        texcoord = Vtexcoord[i];
        viewPos = VviewPos[i];
        worldNormal = VworldNormal[i];
        blockLight = VblockLight[i];
        materialIDs = VmaterialIDs[0];
        textureResolution = maxTextureResolution;

        #ifdef SKYLIGHT_FIX
        float lightDistance = direction * (0.5 - fract(VworldPosition[i][asixIndex] + 1e-5)) + 0.5;
        lightDistance = mix(step(posDiffLength[(4 - i - maxLightIndex) % 3] * lightUnit + 1e-4,
                        maxLight - VblockLight[i].y), lightDistance, step(abs(lightDistance - 0.5), 0.499));
        blockLight.y += (lightFixUnit * lightDistance) * step(0.0, lightFixUnit);
        #endif

		EmitVertex();
    }
	EndPrimitive();
}