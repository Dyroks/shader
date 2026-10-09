// =====================================================================================
//  Volumetric clouds - lookups for the pack's fragment / vertex programs: sky capture
//  (sky light with clouds) and cloud shadows. Include after Settings.inc and Uniforms.inc.
// =====================================================================================

#ifndef CLOUD_LOOKUPS_INC
#define CLOUD_LOOKUPS_INC

#ifndef CLOUD_WORLDDAY_DECLARED
#define CLOUD_WORLDDAY_DECLARED
uniform int worldDay;
#endif

#include "/lib/clouds/CloudCommon.inc"
#define CLOUD_SKY_LOOKUPS
#include "/lib/clouds/CloudSky.inc"

#endif
