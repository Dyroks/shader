#version 430
// Progressive bloom, level 4 (see program/template/BloomUpsample.glsl)
#include "/lib/Settings.inc"
#define BLOOM_LEVEL 4
#ifdef AB_BLOOM
const vec2 workGroupsRender = vec2(0.0725, 0.0725);
#else
const ivec3 workGroups = ivec3(1, 1, 1);
#endif
#include "/program/template/BloomUpsample.glsl"
