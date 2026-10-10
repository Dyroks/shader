// =====================================================================================
//  Atmosphere - user options (included from lib/Settings.inc)
// =====================================================================================

#define ATMOSPHERE_MODEL 1 // 0 = SEUS (original sky), 1 = physical (Hillaire 2020: precomputed scattering, correct at any altitude and for distant terrain). [0 1]
#define ATMOSPHERE_HAZE 3 // Physical model: aerosols (haze) in the lowest kilometres. 0 = very clean air, 3 = typical clear day, 6 = very hazy. Rain adds more. [0 1 2 3 4 5 6]
#define ATMOSPHERE_SKY_BRIGHTNESS 1.0 // Physical model: sky brightness. 1.0 = physically consistent with the sunlight. [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.25 1.5]
#define ATMOSPHERE_AERIAL_PERSPECTIVE 1.0 // Physical model: haze over distant terrain (multiplies the distance). 1.0 = physical. [0.0 0.5 1.0 1.5 2.0 3.0 4.0 6.0 8.0]
#define CREPUSCULAR_RAYS // Physical atmosphere + volumetric clouds with shadows: crepuscular rays, the shadows of the clouds in the air (shafts of light between clouds, sunset rays fanning out over the sky, anticrepuscular rays converging opposite the sun).
#define CREPUSCULAR_STRENGTH 150 // Crepuscular rays, in %: 100 = physical (depends mostly on the valley haze). Higher = darker shadow shafts below the low clouds, more spectacular (never darker than air without any direct light). [50 75 100 125 150 200 250 300]
#define CREPUSCULAR_STEPS 24 // Crepuscular rays: samples along each view ray (more = less noise, slower). [16 24 32 48 64]
#define CREPUSCULAR_DISTANCE 100 // Crepuscular rays: maximum distance in km (scaled). Sunset rays need long distances. [30 50 75 100 150]
#define HAZE_DENSITY 3 // Physical model: haze layer, the dense aerosols that pool in valleys (lit by the sun and shadowed by the clouds: visible light shafts). Visibility at its densest: 0 = off, 1 = 190 km, 2 = 100 km, 3 = 50 km, 4 = 25 km, 5 = 12 km, 6 = 6 km. Rain adds more. [0 1 2 3 4 5 6]
#define HAZE_ALTITUDE 63 // Haze layer: altitude (Y) where it is the densest, set it to the bottom of your valleys. Below, it stays at this density. [0 63 100 150 200 300 400 500 600 700 800 1000 1200 1500 2000]
#define HAZE_HEIGHT 600 // Haze layer: thickness (scale height in metres, scaled): the density is divided by 2.7 every this many metres above its altitude. [150 250 400 600 800 1000 1500 2000 3000]
