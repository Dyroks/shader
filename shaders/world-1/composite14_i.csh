#version 430
// Progressive bloom, level 1 (see program/template/BloomUpsample.glsl)
#include "/lib/Settings.inc"
#define BLOOM_LEVEL 1
const vec2 workGroupsRender = vec2(0.51, 0.51);
#include "/program/template/BloomUpsample.glsl"
