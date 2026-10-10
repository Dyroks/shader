#version 430
// Progressive bloom, level 5 (see program/template/BloomUpsample.glsl)
#include "/lib/Settings.inc"
#define BLOOM_LEVEL 5
const vec2 workGroupsRender = vec2(0.04125, 0.04125);
#include "/program/template/BloomUpsample.glsl"
