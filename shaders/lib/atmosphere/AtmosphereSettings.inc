// =====================================================================================
//  Atmosphere - user options (included from lib/Settings.inc)
// =====================================================================================

#define ATMOSPHERE_MODEL 1 // 0 = SEUS (original sky), 1 = physical (Hillaire 2020: precomputed scattering, correct at any altitude and for distant terrain). [0 1]
#define ATMOSPHERE_HAZE 3 // Physical model: aerosols (haze) in the lowest kilometres. 0 = very clean air, 3 = typical clear day, 6 = very hazy. Rain adds more. [0 1 2 3 4 5 6]
#define ATMOSPHERE_SKY_BRIGHTNESS 1.0 // Physical model: sky brightness. 1.0 = physically consistent with the sunlight. [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.25 1.5]
#define ATMOSPHERE_AERIAL_PERSPECTIVE 1.0 // Physical model: haze over distant terrain (multiplies the distance). 1.0 = physical. [0.0 0.5 1.0 1.5 2.0 3.0 4.0 6.0 8.0]
