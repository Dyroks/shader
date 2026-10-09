#define FXAA_QUALITY_PRESET 10




/*============================================================================

                           FXAA QUALITY - PRESETS

============================================================================*/

/*============================================================================
                     FXAA QUALITY - MEDIUM DITHER PRESETS
============================================================================*/
#define FXAA_QUALITY_P0 1.5
#define FXAA_QUALITY_P1 3.0
#define FXAA_QUALITY_P2 12.0

/*============================================================================

                                API PORTING

============================================================================*/
#define FxaaBool bool
#define FxaaDiscard discard
#define FxaaFloat float
#define FxaaFloat2 vec2
#define FxaaFloat3 vec3
#define FxaaFloat4 vec4
#define FxaaHalf float
#define FxaaHalf2 vec2
#define FxaaHalf3 vec3
#define FxaaHalf4 vec4
#define FxaaInt2 ivec2
#define FxaaSat(x) clamp(x, 0.0, 1.0)
#define FxaaTex sampler2D

/*--------------------------------------------------------------------------*/
#define FxaaTexTop(t, p) textureLod(t, p, 0.0)
#define FxaaTexOff(t, p, o, r) textureLodOffset(t, p, 0.0, o)
#define FxaaTexAlpha4(t, p) textureGather(t, p, 3)
#define FxaaTexOffAlpha4(t, p, o) textureGatherOffset(t, p, o, 3)
/*============================================================================
                   GREEN AS LUMA OPTION SUPPORT FUNCTION
============================================================================*/
FxaaFloat FxaaLuma(FxaaFloat4 rgba) { return rgba.w; }




/*============================================================================

                             FXAA3 QUALITY - PC

============================================================================*/
FxaaFloat4 FxaaPixelShader(
    //
    // Use noperspective interpolation here (turn off perspective interpolation).
    // {xy} = center of pixel
    FxaaFloat2 pos,
    //
    // Input color texture.
    // {rgb_} = color in linear or perceptual color space
    // if (FXAA_GREEN_AS_LUMA == 0)
    //     {__a} = luma in perceptual color space (not linear)
    FxaaTex tex,
    //
    // Only used on FXAA Quality.
    // This must be from a constant/uniform.
    // {x_} = 1.0/screenWidthInPixels
    // {_y} = 1.0/screenHeightInPixels
    FxaaFloat2 fxaaQualityRcpFrame,
    //
    // Only used on FXAA Quality.
    // This used to be the FXAA_QUALITY_SUBPIX define.
    // It is here now to allow easier tuning.
    // Choose the amount of sub-pixel aliasing removal.
    // This can effect sharpness.
    //   1.00 - upper limit (softer)
    //   0.75 - default amount of filtering
    //   0.50 - lower limit (sharper, less sub-pixel aliasing removal)
    //   0.25 - almost off
    //   0.00 - completely off
    FxaaFloat fxaaQualitySubpix)
{
/*--------------------------------------------------------------------------*/
    FxaaFloat2 posM;
    posM.x = pos.x;
    posM.y = pos.y;
    FxaaFloat4 rgbyM = FxaaTexTop(tex, posM);
    #define lumaM rgbyM.w
    FxaaFloat4 luma4A = FxaaTexAlpha4(tex, posM);
    FxaaFloat4 luma4B = FxaaTexOffAlpha4(tex, posM, FxaaInt2(-1, -1));
    #define lumaE luma4A.z
    #define lumaS luma4A.x
    #define lumaSE luma4A.y
    #define lumaNW luma4B.w
    #define lumaN luma4B.z
    #define lumaW luma4B.x
/*--------------------------------------------------------------------------*/
    FxaaFloat maxSM = max(lumaS, lumaM);
    FxaaFloat minSM = min(lumaS, lumaM);
    FxaaFloat maxESM = max(lumaE, maxSM);
    FxaaFloat minESM = min(lumaE, minSM);
    FxaaFloat maxWN = max(lumaN, lumaW);
    FxaaFloat minWN = min(lumaN, lumaW);
    FxaaFloat rangeMax = max(maxWN, maxESM);
    FxaaFloat rangeMin = min(minWN, minESM);
    FxaaFloat range = rangeMax - rangeMin;
/*--------------------------------------------------------------------------*/
    FxaaFloat lumaNE = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2(1, -1), fxaaQualityRcpFrame.xy));
    FxaaFloat lumaSW = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2(-1, 1), fxaaQualityRcpFrame.xy));
/*--------------------------------------------------------------------------*/
    FxaaFloat lumaNS = lumaN + lumaS;
    FxaaFloat lumaWE = lumaW + lumaE;
    FxaaFloat subpixRcpRange = 1.0/range;
    FxaaFloat subpixNSWE = lumaNS + lumaWE;
    FxaaFloat edgeHorz1 = (-2.0 * lumaM) + lumaNS;
    FxaaFloat edgeVert1 = (-2.0 * lumaM) + lumaWE;
/*--------------------------------------------------------------------------*/
    FxaaFloat lumaNESE = lumaNE + lumaSE;
    FxaaFloat lumaNWNE = lumaNW + lumaNE;
    FxaaFloat edgeHorz2 = (-2.0 * lumaE) + lumaNESE;
    FxaaFloat edgeVert2 = (-2.0 * lumaN) + lumaNWNE;
/*--------------------------------------------------------------------------*/
    FxaaFloat lumaNWSW = lumaNW + lumaSW;
    FxaaFloat lumaSWSE = lumaSW + lumaSE;
    FxaaFloat edgeHorz4 = (abs(edgeHorz1) * 2.0) + abs(edgeHorz2);
    FxaaFloat edgeVert4 = (abs(edgeVert1) * 2.0) + abs(edgeVert2);
    FxaaFloat edgeHorz3 = (-2.0 * lumaW) + lumaNWSW;
    FxaaFloat edgeVert3 = (-2.0 * lumaS) + lumaSWSE;
    FxaaFloat edgeHorz = abs(edgeHorz3) + edgeHorz4;
    FxaaFloat edgeVert = abs(edgeVert3) + edgeVert4;
/*--------------------------------------------------------------------------*/
    FxaaFloat subpixNWSWNESE = lumaNWSW + lumaNESE;
    FxaaFloat lengthSign = fxaaQualityRcpFrame.x;
    FxaaBool horzSpan = edgeHorz >= edgeVert;
    FxaaFloat subpixA = subpixNSWE * 2.0 + subpixNWSWNESE;
/*--------------------------------------------------------------------------*/
    if(!horzSpan)
        lumaN = lumaW, lumaS = lumaE;
    else
        lengthSign = fxaaQualityRcpFrame.y;
    FxaaFloat subpixB = (subpixA / 12.0) - lumaM;
/*--------------------------------------------------------------------------*/
    FxaaFloat gradientN = lumaN - lumaM;
    FxaaFloat gradientS = lumaS - lumaM;
    FxaaFloat lumaNN = (lumaN + lumaM) * 0.5;
    FxaaFloat lumaSS = lumaS + lumaM;
    FxaaBool pairN = abs(gradientN) >= abs(gradientS);
    FxaaFloat gradient = max(abs(gradientN), abs(gradientS));
    if(pairN) lengthSign = -lengthSign;
    FxaaFloat subpixC = FxaaSat(abs(subpixB) * subpixRcpRange);
/*--------------------------------------------------------------------------*/
    FxaaFloat2 posB;
    posB.x = posM.x;
    posB.y = posM.y;
    FxaaFloat2 offNP = FxaaFloat2(0.0);
    if(!horzSpan) {
        posB.x += lengthSign * 0.5;
        offNP.y = fxaaQualityRcpFrame.y;
    }
    else {
        posB.y += lengthSign * 0.5;
        offNP.x = fxaaQualityRcpFrame.x;
    }
/*--------------------------------------------------------------------------*/
    FxaaFloat2 posN;
    FxaaFloat2 posP;
    FxaaFloat2 offNP0 = offNP * FXAA_QUALITY_P0;
    posN = posB - offNP0;
    posP = posB + offNP0;
    FxaaFloat subpixD = ((-2.0)*subpixC) + 3.0;
    FxaaFloat lumaEndN = FxaaLuma(FxaaTexTop(tex, posN));
    FxaaFloat subpixE = subpixC * subpixC;
    FxaaFloat lumaEndP = FxaaLuma(FxaaTexTop(tex, posP));
/*--------------------------------------------------------------------------*/
    if(!pairN) lumaNN = lumaSS * 0.5;
    FxaaFloat gradientScaled = gradient / 4.0;
    FxaaFloat lumaMM = lumaM - lumaNN;
    FxaaFloat subpixF = subpixD * subpixE;
    FxaaBool lumaMLTZero = lumaMM < 0.0;
/*--------------------------------------------------------------------------*/
    lumaEndN -= lumaNN;
    lumaEndP -= lumaNN;
    FxaaBool doneN = abs(lumaEndN) >= gradientScaled;
    FxaaBool doneP = abs(lumaEndP) >= gradientScaled;
    FxaaFloat2 offNP1 = offNP * FXAA_QUALITY_P1;
    if(!doneN) posN -= offNP1;
    if(!doneP) posP += offNP1;
    FxaaBool doneNP = !(doneN && doneP);
/*--------------------------------------------------------------------------*/
    if(doneNP) {
        if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy)) - lumaNN;
        if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy)) - lumaNN;
        doneN = abs(lumaEndN) >= gradientScaled;
        doneP = abs(lumaEndP) >= gradientScaled;
        FxaaFloat2 offNP2 = offNP * FXAA_QUALITY_P2;
        if(!doneN) posN -= offNP2;
        if(!doneP) posP += offNP2;
    }
/*--------------------------------------------------------------------------*/
    FxaaFloat dstN;
    FxaaFloat dstP;
    if(!horzSpan) {dstN = posM.y - posN.y; dstP = posP.y - posM.y;}
    else          {dstN = posM.x - posN.x; dstP = posP.x - posM.x;}
/*--------------------------------------------------------------------------*/
    FxaaBool goodSpanN = (lumaEndN < 0.0) != lumaMLTZero;
    FxaaFloat spanLength = (dstP + dstN);
    FxaaBool goodSpanP = (lumaEndP < 0.0) != lumaMLTZero;
    FxaaFloat spanLengthRcp = 1.0/spanLength;
/*--------------------------------------------------------------------------*/
    FxaaBool directionN = dstN < dstP;
    FxaaFloat dst = min(dstN, dstP);
    FxaaBool goodSpan = directionN ? goodSpanN : goodSpanP;
    FxaaFloat subpixG = subpixF * subpixF;
    FxaaFloat pixelOffset = dst * (-spanLengthRcp) + 0.5;
    FxaaFloat subpixH = subpixG * fxaaQualitySubpix;
/*--------------------------------------------------------------------------*/
    FxaaFloat pixelOffsetGood = goodSpan ? pixelOffset : 0.0;
    FxaaFloat pixelOffsetSubpix = max(pixelOffsetGood, subpixH) * lengthSign;
    if(!horzSpan)
        posM.x += pixelOffsetSubpix;
    else
        posM.y += pixelOffsetSubpix;
    return FxaaFloat4(FxaaTexTop(tex, posM).xyz, lumaM);
}
/*==========================================================================*/

const float FXAA_Subpix = 0.3; // Amount of sub-pixel aliasing removal. Higher values makes the image softer/blurrier.

vec3 DoFXAA(sampler2D tex, vec2 coord, vec2 texelSize)
{
  #ifdef SKIP_AA
  return texture2DLod(tex, coord, 0).rgb;
  #endif
  return FxaaPixelShader(
    coord, // pos
    tex, // tex
    texelSize, // fxaaQualityRcpFrame
    FXAA_Subpix // fxaaQualitySubpix
  ).rgb;
}


