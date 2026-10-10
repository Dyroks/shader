#version 430
// Progressive bloom, level 2 (see program/template/BloomUpsample.glsl)
#include "/lib/Settings.inc"
#define BLOOM_LEVEL 2
const vec2 workGroupsRender = vec2(0.26, 0.26);
#include "/program/template/BloomUpsample.glsl"
