// Aurora Shaders for Hytale - volumetric light shafts.
// Ray-marched shafts tracing Hytale's sun shadow cascades.

#ifndef AU_VL
#define AU_VL

#include "AU_Shadow.glsl"
#include "AU_Fog.glsl"

#ifndef AU_LIGHTSHAFT_SOFTNESS
#define AU_LIGHTSHAFT_SOFTNESS 1.0
#endif
// Widest lit stretch (blocks, across the light) that still counts as a beam for the boost.
#ifndef AU_LIGHTSHAFT_BEAM_WIDTH
#define AU_LIGHTSHAFT_BEAM_WIDTH 3.0
#endif

// The scene is still in gamma space here (PostEffectFS applies the pow 2.2); the shafts belong
// in linear space, after that pow.
vec3 AU_AddVL(vec3 color, vec3 vl)
{
    return pow(pow(max(color, vec3(0.0)), vec3(2.2)) + vl, vec3(1.0 / 2.2));
}

// nPlayerPos: normalised world-space view direction. lViewPos1: distance to the opaque
// surface (ignored for sky pixels).
vec3 GetVolumetricLight(vec3 nPlayerPos, float lViewPos1, bool sky, float dither)
{
#if AU_LIGHTSHAFTS
    if (GetLuminance(lightColor) <= 0.00001) return vec3(0.0);
    float far = AU_LIGHTSHAFT_DISTANCE;
    float vlMult = AU_LIGHTSHAFT_STRENGTH;
    vec3 vlColor = lightColor;   // r5.9 volumetricLight.glsl uses the sun light colour
    // Only the darkness around the camera (caves, rooms) widens the shafts globally: Hytale eases
    // it smoothly. The overhead-cover check went per frame through a shadow map Hytale refits to
    // the view every frame, so it jumped at canopy edges and the whole screen's haze flickered;
    // beams under trees now come from the per-sample boost below instead.
    float vlSceneIntensity = clamp((0.6 - GetEyeBrightness()) * 2.5, 0.0, 1.0) * AU_LIGHTSHAFT_SCENE_AWARE;

    if (sunVisibility < 0.5) {
        vlSceneIntensity = 0.0;
        float vlMultNightModifier = 0.3 + 0.4 * rainFactor2 + 0.5 * max0(far - lViewPos1) / far;
        vlMult *= vlMultNightModifier;
        vlColor = pow(vlColor, vec3(1.0 - max0(1.0 - 1.5 * nightFactor) + rainFactor));
        vlColor /= max(length(vlColor), 0.0001);
        vlColor *= 0.0766 + 0.0766 * vsBrightness;
    }

    float VdotL = dot(nPlayerPos, lightVec);
    float VdotU = nPlayerPos.y;
    float rainyNight = (1.0 - sunVisibility) * rainFactor;
    float VdotLM = max((VdotL + 1.0) / 2.0, 0.0);
    float VdotUmax0 = max(VdotU, 0.0);
    // Haze fades toward the sky as you look up; beams (the boosted part below) keep the
    // under-cover version of that fade wherever the camera is, so shafts falling through a
    // roof or a canopy stay visible when you look up at them.
    float VdotUM = mix(pow2(1.0 - VdotUmax0), 1.0, 0.5 * vlSceneIntensity);
    VdotUM = pow(smoothstep1(VdotUM), min(lViewPos1 / far, 1.0) * (3.0 - 2.0 * vlSceneIntensity));
    float VdotUMShaft = pow(smoothstep1(mix(pow2(1.0 - VdotUmax0), 1.0, 0.5)), min(lViewPos1 / far, 1.0));
    float dirBase = mix(VdotUM * VdotLM, 1.0, 0.4 * rainyNight);
    float dirShaft = mix(VdotUMShaft * VdotLM, 1.0, 0.4 * rainyNight);

    float vlTime = min(abs(SdotU) - 0.05, 0.15) / 0.15;
    vlMult *= vlTime;
    float noonMult = mix(invNoonFactor2 * 0.875 + 0.125, 1.0, rainFactor2);
    vlMult *= noonMult;
    vlMult *= 1.4 - 0.4 * rainFactor;
    // Scene-aware strength per sample: light right after shadow along the ray - a shaft, a narrow
    // lit stretch with shadow on both sides (see below) - gets full strength at noon plus the
    // boost wherever the camera is, under the trees or looking at them from outside. Open daylit
    // air (a door, a gap, an open field) keeps the dimmed noon haze.
    float shaftMult = (1.0 / noonMult) * (1.0 + AU_LIGHTSHAFT_SCENE_BOOST * float(sunVisibility > 0.5));
    // How much of the boost a ray gets depends on the ray itself, not on where the camera is: the
    // share of it that ran through shadow so far (rooms, caves, under a canopy: most of it; an
    // open field: little). Only nearby air counts (below), so distant forests don't haze over.
    float shaftAmount = AU_LIGHTSHAFT_SCENE_AWARE;
    float shadowSum = 0.0, shadowN = 0.0;

    if (vlMult * max(dirBase, dirShaft * shaftMult) < 0.0001) return vec3(0.0);

    // Short rays (rooms, under trees) get up to 75% more samples: they are cheap there, and thin
    // beams crossing them otherwise sparkle at their edges.
    float rayLenGuess = !sky ? lViewPos1 : 1.0e9;
    int nearSamples = int(mix(float(AU_LIGHTSHAFT_SAMPLES), 1.5 * float(AU_LIGHTSHAFT_SAMPLES), vlSceneIntensity)
                          * clamp(48.0 / max(rayLenGuess, 1.0), 1.0, 1.75));
    int farSamples = 1;
    float fogCurve = mix(0.9, 0.5, max(vlSceneIntensity, rainFactor));
    float sampleDistribution = mix(2.0, 1.5, vlSceneIntensity);
    float sampleDistributionFar = 2.5;
    float maxDistance = max(far * 0.98, 128.0);
    if (IsCameraUnderwater > 0.5) maxDistance = min(maxDistance, 128.0);
    float shadowRange = SunShadowCascadeStats[AU_SHADOW_CASCADES - 1].x;
    float qualityThreshold = min(far, shadowRange > 1.0 ? shadowRange : far) * 0.98;
    qualityThreshold = mix(qualityThreshold, 100.0, vlSceneIntensity);

    float rayEnd = !sky ? min(lViewPos1, maxDistance) : maxDistance;
    float lastFogWeight = 0.0, lastShaftWeight = 0.0;
    float activeThreshold = min(qualityThreshold, maxDistance);
    // March the near samples over the ray that actually exists: indoors the ray ends at a wall
    // 10-20 blocks away, and spreading the samples over the full shaft range left only a dozen
    // of them in the room, ~1.7 blocks apart - coarser than a light beam through a hole, so the
    // beam came out as heavy grain.
    float nearEnd = min(activeThreshold, rayEnd);
    int totalSamples = (rayEnd <= qualityThreshold) ? nearSamples : (nearSamples + farSamples);
    float eyeBrightnessM = GetEyeBrightness();

    float vlBase = 0.0, vlShaft = 0.0;
    // Hytale fits its cascades tightly around the view, so a ray can leave them sideways well
    // inside the shaft range; the box side then projects as a hard line through the sun.
    // Carry the last real shadow value along the ray instead of assuming full light.
    float lastDensity = eyeBrightnessM;
    // Short-memory average of the samples so far: the scene-aware boost only lifts light that
    // stands out right after shadow along the ray (a shaft crossing a dark room), not the run of
    // daylit air seen through a door or a gap, which would otherwise turn into bright fog.
    float litRecent = 0.0;
    // One hard shadow lookup per sample showed the shadow map's texels: beams came out boxy,
    // with stair-stepped edges (worst with big texels: far cascades, low shadow resolution),
    // and the beam boost made them stand out. The ray looks the shadow map up a little to the
    // side instead - up to AU_LIGHTSHAFT_SOFTNESS * 2 texels, a different offset per pixel and
    // per frame - and the TAA blends that into soft beam edges. One offset for the whole ray,
    // not one per sample: the boost below reacts to light right after shadow, and samples
    // flickering between the two along a beam's edge drew a bright rim on it. The offset comes
    // from the ray's own dither: that converged faster under the TAA than separate noise.
    vec2 shaftTexel = 1.0 / vec2(textureSize(uHookShadowMap, 0));
    vec2 shaftU = vec2(fract(dither * 3.17 + 0.25), fract(dither * 7.31 + 0.5));
    vec2 shaftOffset = sqrt(shaftU.x) * vec2(cos(6.2831853 * shaftU.y), sin(6.2831853 * shaftU.y))
                     * 2.0 * AU_LIGHTSHAFT_SOFTNESS * shaftTexel;
    // Beams, not open air. Light right after shadow is also what a ray meets where it leaves the
    // shade for a sunlit clearing, the field behind a tree line or the air above a canopy, and
    // boosting that drew a solid wall of haze with the shadows' straight block edges, starting
    // where the shade around the player ended (objects still in the shade stayed clear, so it cut
    // across trees at odd heights). A lit stretch's boost now only counts once the ray is back in
    // shadow and the stretch was narrow - up to about AU_LIGHTSHAFT_BEAM_WIDTH blocks across the
    // light: a beam. A stretch the ray ends in (open air, a sunlit field, the sky through a gap)
    // keeps the dimmed haze only.
    float sinVL = sqrt(max(1.0 - VdotL * VdotL, 0.0));
    bool inLight = false;
    float runStart = 0.0, runLast = 0.0, runShaft = 0.0;
    for (int i = 0; i <= totalSamples; i++) {
        float nextDistance;
        float localDensity;

        if (i <= nearSamples) {
            float t = (float(i) + dither) / float(nearSamples);
            nextDistance = pow(t, sampleDistribution) * nearEnd;
            if (nextDistance >= rayEnd) break;
            vec3 sc;
            int cascade;
            if (GetShadowCoordCascade(nPlayerPos * nextDistance, sc, cascade)) {
                if (AU_LIGHTSHAFT_SOFTNESS > 0.0) {
                    // Less in the far cascades (bigger texels), like the soft sun shadows.
                    const float cascadeScale = 1.0 / float(AU_SHADOW_CASCADES);
                    sc.xy += shaftOffset / (1.0 + 0.6 * float(cascade));
                    // Stay inside this cascade's part of the atlas.
                    sc.x = clamp(sc.x, cascadeScale * float(cascade) + 2.0 * shaftTexel.x,
                                 cascadeScale * float(cascade + 1) - 2.0 * shaftTexel.x);
                }
                localDensity = texture(uHookShadowMap, vec3(sc.xy, sc.z - 0.0002));
                lastDensity = localDensity;
            } else {
                localDensity = lastDensity;
            }
        } else {
            float t = (float(i - nearSamples) + dither) / float(farSamples);
            nextDistance = mix(activeThreshold, maxDistance, pow(t, sampleDistributionFar));
            if (nextDistance >= rayEnd) nextDistance = rayEnd;
            localDensity = eyeBrightnessM;
        }

        float nextWeight = smoothstep1(pow(nextDistance / maxDistance, fogCurve));
        // Beams use the dense, near-weighted curve of enclosed spaces everywhere.
        float nextShaftWeight = smoothstep1(sqrt(nextDistance / maxDistance));
        float shaftWeight = nextShaftWeight - lastShaftWeight;
        shadowSum += 1.0 - localDensity;
        shadowN += 1.0;
        float enclosed = shadowSum / shadowN;
        float nearW = (1.0 - smoothstep(12.0, 48.0, nextDistance)) * (1.0 - litRecent) * shaftAmount * mix(0.4, 1.0, enclosed);
        float sampleLight = localDensity * (nextWeight - lastFogWeight);
        vlBase += sampleLight;
        float boost = localDensity * shaftWeight * (shaftMult - 1.0) * nearW;
        // Lit / shadow at 0.5: leaf shadows let some light through, and that is still shade.
        if (localDensity > 0.5) {
            if (!inLight) { inLight = true; runStart = nextDistance; runShaft = 0.0; }
            runLast = nextDistance;
            runShaft += boost;
        } else if (inLight) {
            // Back in shadow: the stretch (and this soft edge of it) was a beam if it was narrow.
            float width = (runLast - runStart) * sinVL;
            vlShaft += (runShaft + boost) * (1.0 - smoothstep(0.5, 2.5, width / AU_LIGHTSHAFT_BEAM_WIDTH));
            inLight = false;
        }
        litRecent = mix(litRecent, localDensity, 0.6);
        lastFogWeight = nextWeight;
        lastShaftWeight = nextShaftWeight;
    }
    // Still in the light where the ray meets a surface: if the surface is in shadow, the stretch
    // ended in shadow just short of the next sample (a beam crossed right in front of a shaded
    // wall or floor). A sunlit surface - a beam's own patch of light, a sunlit field - is not.
    // Only shade from over a block up counts (a roof, a canopy): right at the surface the shadow
    // map shades the surface itself, which drew rings.
    if (inLight && !sky) {
        vec3 sc;
        int c;
        if (GetShadowCoordCascade(nPlayerPos * max(rayEnd - 0.25, 0.0), sc, c)) {
            vec3 zRow = vec3(SunShadowMatrix[c][0][2], SunShadowMatrix[c][1][2], SunShadowMatrix[c][2][2]);
            if (texture(uHookShadowMap, vec3(sc.xy, sc.z - 0.0002 - 0.5 * length(zRow))) <= 0.5) {
                float width = (runLast - runStart) * sinVL;
                vlShaft += runShaft * (1.0 - smoothstep(0.5, 2.5, width / AU_LIGHTSHAFT_BEAM_WIDTH));
            }
        }
    }

    vlColor = pow(vlColor, vec3(0.5 + (0.5 + 0.25 * sunVisibility) * invNoonFactor * invRainFactor + 0.3 * rainFactor));
    vlColor *= 1.0 - (0.3 + 0.3 * noonFactor) * rainFactor - 0.5 * rainyNight + sunVisibility * invNoonFactor2 * invRainFactor;

    // Strength per time of day (noon / sunset / night).
    if (IsCameraUnderwater < 0.5)
        vlMult *= mix(AU_LIGHTSHAFT_NIGHT_I, mix(AU_LIGHTSHAFT_SUNSET_I, AU_LIGHTSHAFT_NOON_I, auPow3(noonFactor)), sunVisibility);
    // The open-air haze (vlBase) has its own strength: Hytale's land is darker than Minecraft's
    // under Complementary's light, and at full strength the haze turned open views milky. Beams
    // (vlShaft: light right after shadow - forests, caves, windows) keep theirs.
    vec3 volumetricLight = (vlBase * dirBase * AU_LIGHTSHAFT_HAZE + vlShaft * dirShaft) * vlColor * vlMult;
    if (IsCameraUnderwater > 0.5) volumetricLight *= pow2(vec3(0.46, 0.62, 1.0) * 0.55);
    return max(volumetricLight - 0.0025, vec3(0.0));
#else
    return vec3(0.0);
#endif
}

#endif // AU_VL
