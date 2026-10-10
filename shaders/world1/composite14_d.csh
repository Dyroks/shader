#version 430
// Progressive bloom, level 6 (see program/template/BloomUpsample.glsl)
#include "/lib/Settings.inc"
#define BLOOM_LEVEL 6
const vec2 workGroupsRender = vec2(0.02563, 0.02563);
#include "/program/template/BloomUpsample.glsl"
