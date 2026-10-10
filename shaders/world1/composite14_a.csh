#version 430
// Progressive bloom, level 9 (see program/template/BloomUpsample.glsl)
#include "/lib/Settings.inc"
#define BLOOM_LEVEL 9
const vec2 workGroupsRender = vec2(0.01195, 0.01195);
#include "/program/template/BloomUpsample.glsl"
