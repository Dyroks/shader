// =====================================================================================
//  GI module: uniforms and libraries of the GI compute passes
//
//  Compute programs do not include the pack's Uniforms.inc / Common.inc. Include after
//  Settings.inc. In the deferred passes colortex3 is the block atlas and depthtex0 the
//  specular atlas (shaders.properties), the solid depth is depthtex1.
// =====================================================================================

#ifndef GI_COMPUTE_HEADER_INC
#define GI_COMPUTE_HEADER_INC

#include "/lib/clouds/CloudUniforms.inc"

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D depthtex1;
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;
uniform sampler2DShadow shadowtex0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 worldLightVector;
uniform vec3 worldSunVector;
uniform vec3 colorSunlight;
uniform vec3 FractedCameraPosition;
uniform vec3 cameraPosCenterDiff;
uniform vec3 cameraPositionDiff;
uniform vec2 JitterSampleOffset;
uniform float nightBrightness;
uniform int isEyeInWater;
uniform int altRTDiameter;
uniform ivec2 eyeBrightnessSmooth;

// sky and clouds (sky light of the escaped rays, cloud shadows on the hit points)
#include "/lib/atmosphere/Sky.inc"
#include "/lib/clouds/CloudCommon.inc"
#define CLOUD_SKY_LOOKUPS
#include "/lib/clouds/CloudSky.inc"

// voxel volume (same constants as the shadow pass)
#ifndef MC_SHADOW_QUALITY
	#define MC_SHADOW_QUALITY 1.0
#endif
const int shadowMapResolution = 8192; // Higher value impacts performance costs, but can get better shadow, and increase path tracing distance. Please increase the shadow distance at the same time. 4096 - 80 blocks path tracing. 8192 - 160 blocks path tracing. 16384 - 300 blocks path tracing, requires at least 6GB VRAM. 34768 - 530 blocks of path tracing, requires at least 20GB VRAM. [4096 8192 16384 32768]
const float SHADOW_MAP_RESOLUTION = shadowMapResolution * MC_SHADOW_QUALITY;
const float RAY_TRACING_RESOLUTION = SHADOW_MAP_RESOLUTION - 2048.0;
const float RAY_TRACING_DIAMETER_TEMP = floor(pow(RAY_TRACING_RESOLUTION, 2.0 / 3.0));
const float RAY_TRACING_DIAMETER = RAY_TRACING_DIAMETER_TEMP - mod(RAY_TRACING_DIAMETER_TEMP - 1.0, 2.0);
const float RAY_TRACING_RADIUS = RAY_TRACING_DIAMETER / 2.0;

#include "/lib/gi/GiCommon.glsl"
#include "/lib/gi/GiVolume.glsl"
#include "/lib/gi/GiSampling.glsl"
#if SHAPE_CALC_FUNC == 0
	#include "/program/template/BlockShapes_CompileTime.glsl"
#else
	#include "/program/template/BlockShapes_Performance.glsl"
#endif
#include "/lib/gi/GiTrace.glsl"
#include "/lib/gi/GiLighting.glsl"
#include "/lib/gi/GiSurface.glsl"
#include "/lib/gi/GiReservoir.glsl"

#endif
