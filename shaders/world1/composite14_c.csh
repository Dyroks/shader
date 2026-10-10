#version 430
// Progressive bloom, level 7 (see program/template/BloomUpsample.glsl)
#include "/lib/Settings.inc"
#define BLOOM_LEVEL 7
#ifdef AB_BLOOM
const vec2 workGroupsRender = vec2(0.01781, 0.01781);
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif
#include "/program/template/BloomUpsample.glsl"
