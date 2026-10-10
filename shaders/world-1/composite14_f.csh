#version 430
// Progressive bloom, level 4 (see program/template/BloomUpsample.glsl)
#include "/lib/Settings.inc"
#define BLOOM_LEVEL 4
const vec2 workGroupsRender = vec2(0.0725, 0.0725);
#include "/program/template/BloomUpsample.glsl"
