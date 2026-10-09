// =====================================================================================
//  Volumetric clouds - uniforms and samplers used by the cloud compute programs.
//  (Compute shaders do not include the pack's Uniforms.inc / Common.inc.)
// =====================================================================================

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 shadowModelViewInverse;

uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float sunAngle;
uniform float wetness;
uniform float rainStrength;
uniform float thunderStrength;
uniform int frameCounter;
uniform int worldTime;
uniform int worldDay;

uniform sampler2D depthtex0;
uniform sampler2D noisetex;

#ifdef DISTANT_HORIZONS
	uniform sampler2D dhDepthTex0;
	uniform mat4 dhProjectionInverse;
#endif

#ifdef VOXY
	uniform sampler2D vxDepthTexOpaque;
	uniform sampler2D vxDepthTexTrans;
	uniform mat4 vxProjInv;
#endif

uniform sampler3D cloudNoiseBase;
uniform sampler3D cloudNoiseDetail;
uniform sampler2D cloudCurl;
uniform sampler2D cloudCirrus;
uniform sampler3D cloudWeatherNearSampler;
uniform sampler3D cloudWeatherFarSampler;
uniform sampler2D cloudRegimeSampler;
uniform sampler2D cloudSkipSampler;
