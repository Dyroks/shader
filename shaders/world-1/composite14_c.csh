#version 430
// Progressive bloom, level 7 (see program/template/BloomUpsample.glsl)
#include "/lib/Settings.inc"
#define BLOOM_LEVEL 7
const vec2 workGroupsRender = vec2(0.01781, 0.01781);
#include "/program/template/BloomUpsample.glsl"
