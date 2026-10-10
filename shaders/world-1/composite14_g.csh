#version 430
// Progressive bloom, level 3 (see program/template/BloomUpsample.glsl)
#include "/lib/Settings.inc"
#define BLOOM_LEVEL 3
const vec2 workGroupsRender = vec2(0.135, 0.135);
#include "/program/template/BloomUpsample.glsl"
