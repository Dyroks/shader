#ifndef IS_IRIS
    in int dhMaterialId;
#endif

out vec4 color;
out vec3 worldPos;
out vec3 worldNormal;
out vec2 offsetCenter;

#include "/lib/Settings.inc"
#include "/lib/Uniforms.inc"

const int shadowMapResolution = 8192; // Higher value impacts performance costs, but can get better shadow, and increase path tracing distance. Please increase the shadow distance at the same time. 4096 - 80 blocks path tracing. 8192 - 160 blocks path tracing. 16384 - 300 blocks path tracing, requires at least 6GB VRAM. 34768 - 530 blocks of path tracing, requires at least 20GB VRAM. [4096 8192 16384 32768]
const float SHADOW_MAP_RESOLUTION = shadowMapResolution * MC_SHADOW_QUALITY;

void main() {
    color = gl_Color;
    worldNormal = gl_Normal;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    worldPos = (shadowModelViewInverse * viewPos).xyz;

    offsetCenter = vec2(SHADOW_MAP_RESOLUTION - 1024);
    float isWater = float(dhMaterialId == DH_BLOCK_WATER);
    offsetCenter.y -= isWater * SHADOW_MAP_RESOLUTION * 0.5;
    float isTransparent = step(color.w, 0.999);
    offsetCenter.x -= isTransparent * (1.0 - isWater) * SHADOW_MAP_RESOLUTION * 0.5;

    gl_Position = gl_ProjectionMatrix * viewPos;
    float r=length(gl_Position.xy),a=1.f-SHADOW_MAP_BIAS+r*SHADOW_MAP_BIAS;
    gl_Position.xy *= 0.95 / a;
    gl_Position.xy *= 2048.0 / SHADOW_MAP_RESOLUTION;
    gl_Position.xy += (SHADOW_MAP_RESOLUTION - 2048.0) / SHADOW_MAP_RESOLUTION;
    gl_Position.x -= isTransparent * (1.0 - isWater);
    gl_Position.y -= isWater;
    gl_Position.z=mix(gl_Position.z,.5,.8);
}
