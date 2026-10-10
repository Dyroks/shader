#version 430
// Progressive bloom, level 8 (see program/template/BloomUpsample.glsl)
#include "/lib/Settings.inc"
#define BLOOM_LEVEL 8
const vec2 workGroupsRender = vec2(0.01391, 0.01391);
#include "/program/template/BloomUpsample.glsl"
