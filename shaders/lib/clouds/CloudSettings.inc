// =====================================================================================
//  Volumetric clouds - user options
//  (included from lib/Settings.inc so every program sees the same values)
// =====================================================================================

#define VOLUMETRIC_CLOUDS // Volumetric cloud system (replaces the old 2D cloud plane).

// ---- Quality --------------------------------------------------------------------------
#define CLOUD_QUALITY 2 // Preset. 0 = Low, 1 = Medium, 2 = High, 3 = Ultra, 4 = Custom (uses the values below). [0 1 2 3 4]
#define CLOUD_RES 2 // 1 = every pixel is ray marched every frame. 2 = 1 pixel out of 4 per frame, reconstructed temporally (much faster). [1 2]
#define CLOUD_STEPS 72 // [Custom] Max ray march samples inside clouds. [24 32 40 48 56 64 72 96 128 160 192 256]
#define CLOUD_LIGHT_STEPS 5 // [Custom] Samples toward the sun for each cloud sample. [2 3 4 5 6 7 8 10 12]
#define CLOUD_MS_OCTAVES 3 // [Custom] Multiple scattering octaves. [1 2 3 4]
#define CLOUD_DETAIL_DISTANCE 25 // [Custom] Distance (km, scaled) up to which small detail erosion is computed. [0 5 10 15 20 25 30 40 60 80]
#define CLOUD_STEP_SCALE 1.0 // [Custom] Ray march step length multiplier (lower = finer = slower). [0.5 0.6 0.7 0.8 0.9 1.0 1.25 1.5 1.75 2.0]
#define CLOUD_MAX_DISTANCE 120 // Maximum cloud render distance in km (scaled by Cloud Scale). [40 60 80 100 120 160 200 300]
#define CLOUD_TEMPORAL // Temporal accumulation (reduces noise, may ghost slightly in fast motion).
#define CLOUD_SKIP_MAP // Hierarchical empty space skipping (tiles of 1.6 / 6.4 / 25.6 km): rays cross empty areas in one step.

// ---- World / look ---------------------------------------------------------------------
#define CLOUD_SCALE 1.0 // Size of everything related to the clouds and the physical atmosphere. 1.0 = real world scale (cumulus about 1 km wide). Lower for vanilla-sized worlds. Rendering stays identical at every scale. [0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.6 0.7 0.8 0.9 1.0 1.25 1.5 2.0]
#define CLOUD_ALTITUDE 1500 // Altitude (absolute Y) of the base of low clouds. [150 200 250 300 350 400 450 500 600 700 800 900 1000 1100 1200 1300 1400 1500 1600 1800 2000 2250 2500 2750 3000 3500 4000]
#define CLOUD_COVERAGE 0.5 // Average fraction of the sky covered by clouds. [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define CLOUD_CONVECTION 0.55 // 0 = flat layered clouds, 1 = tall towering cumulus. [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define CLOUD_EROSION 0.55 // Small scale detail: finest cauliflower lobes of cumulus, erosion of the edges of layered clouds (wisps at the bottom). [0.0 0.1 0.2 0.3 0.4 0.5 0.55 0.6 0.7 0.8 0.9 1.0]
#define CLOUD_CUMULUS_MODEL 1 // Shape of cumulus clouds. 0 = previous (smooth rounded shapes), 1 = cauliflower lobes carved in a solid dome, crisp edges. [0 1]
#define CLOUD_LOBES 1.0 // Cumulus (model 1): depth of the creases between the cauliflower lobes. [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define CLOUD_IRREGULARITY 1.0 // Distortion of cloud shapes and height variation of their tops (turrets). [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define CLOUD_DENSITY 1.0 // Optical density multiplier. [0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0 4.0]
#define CLOUD_WEATHER_VARIATION 1.0 // How much coverage and cloud types vary across the sky and over time. [0.0 0.25 0.5 0.75 1.0 1.25 1.5]
#define CLOUD_WIND_SPEED 10 // Wind speed in m/s (scaled). [0 1 2 3 5 7 10 15 20 30 50]
#define CLOUD_WIND_ANGLE 30 // Wind direction in degrees. [0 15 30 45 60 75 90 105 120 135 150 165 180 195 210 225 240 255 270 285 300 315 330 345]
#define CLOUD_EVOLUTION 1.0 // How fast cloud shapes evolve over time. [0.0 0.25 0.5 1.0 1.5 2.0 3.0 4.0]
#define CLOUD_TIME_SOURCE 0 // 0 = world time (frozen if the daylight cycle is off, consistent between players), 1 = real time. [0 1]
#define CLOUD_SEED 0 // Changes the whole cloud pattern. [0 1 2 3 4 5 6 7 8 9]

// ---- Cloud types / weather ------------------------------------------------------------
#define CLOUD_REGIME 0 // Kind of sky. 0 = changes every day, 1 = manual (only the settings of this menu), 2 = clear, 3 = fair weather cumulus, 4 = cumulus and altocumulus, 5 = cirrus, 6 = towering cumulus, 7 = stratocumulus, 8 = warm front (cirrostratus, altostratus), 9 = mixed. [0 1 2 3 4 5 6 7 8 9]
#define CLOUD_MID_LAYER 100 // Amount of mid level clouds (altocumulus, altostratus), in %. 0 removes the layer (faster). [0 25 50 75 100 125 150 200]
#define CLOUD_HIGH_LAYER 100 // Amount of high clouds (cirrus, cirrocumulus, cirrostratus), in %. 0 removes the layer. [0 25 50 75 100 125 150 200]
#define CLOUD_STORMS // Cumulonimbus with anvils during thunderstorms (and rarely in convective weather).
#define CLOUD_LIGHTNING 1.0 // Brightness of the lightning flashes inside clouds during thunderstorms. 0 = off. [0.0 0.5 1.0 1.5 2.0 3.0]

// ---- Lighting --------------------------------------------------------------------------
#define CLOUD_AMBIENT 1.0 // Sky light received by clouds. [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define CLOUD_SUNLIGHT 1.0 // Sun light received by clouds. [0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0]
#define CLOUD_LIGHT_MODEL 1 // Multiple scattering. 0 = previous (brighter, nearly uniform), 1 = calibrated on a path traced reference (shaded sides and bases darker, more contrast). [0 1]
#define CLOUD_DEEP_DIFFUSION 0.4 // Sunlight diffusing deep inside clouds: lights their interior and shaded sides. 0 = previous look (darker, more contrast). [0.0 0.1 0.2 0.3 0.4 0.5 0.6]
#define CLOUD_GROUND_BOUNCE 0.2 // Ground albedo used for light bounced from the ground onto cloud bases. 0 disables it. [0.0 0.1 0.2 0.3 0.4 0.5]
#define CLOUD_AERIAL_PERSPECTIVE // Atmospheric haze between the camera and the clouds.

// ---- Integration -----------------------------------------------------------------------
#define CLOUD_SHADOWS // Cloud shadows on the terrain, in the GI sunlight and in the godrays.
#define CLOUD_SKY_LIGHTING // Clouds seen by the GI, the sky light and the reflections (sky capture).

// ---- Debug ----------------------------------------------------------------------------
#define CLOUD_DEBUG_VIEW 0 // 0 = off, 1 = clouds only, 2 = weather map (top-down), 3 = ray march cost heat map, 4 = transmittance. [0 1 2 3 4]
