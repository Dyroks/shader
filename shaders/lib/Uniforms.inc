uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;

uniform sampler2D gaux1;
uniform sampler2D gaux2;

uniform sampler2DShadow shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;

uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

#ifdef DISTANT_HORIZONS
    uniform sampler2D dhDepthTex0;
    uniform sampler2D dhDepthTex1;

    uniform mat4 dhProjection;
    uniform mat4 dhProjectionInverse;

    uniform int dhRenderDistance;
#endif

#ifdef VOXY
    uniform sampler2D vxDepthTexOpaque;
    uniform sampler2D vxDepthTexTrans;

    uniform mat4 vxProj;
    uniform mat4 vxProjInv;

    uniform int vxRenderDistance;
#endif

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec4 entityColor;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 FractedCameraPosition;
uniform vec3 cameraPosCenterDiff;
uniform vec3 cameraPositionDiff;
uniform vec3 worldLightVector;
uniform vec3 worldSunVector;
uniform vec3 colorSunlight;
uniform vec3 fogColor;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float frameTimeCounter;
uniform float frameTime;
uniform float sunAngle;
uniform float nightVision;
uniform float blindness;
uniform float nightBrightness;
uniform float timeMidnight;
uniform float aspectRatio;

uniform int frameCounter;
uniform int blockEntityId;
uniform int isEyeInWater;
uniform int worldTime;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform int altRTDiameter;

uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 atlasSize;

uniform vec2 ScreenSize;
uniform vec2 ScreenTexel;
uniform vec2 HalfScreen;
uniform vec2 JitterSampleOffset;

#ifndef MC_SHADOW_QUALITY
    #define MC_SHADOW_QUALITY 1.0
#endif
