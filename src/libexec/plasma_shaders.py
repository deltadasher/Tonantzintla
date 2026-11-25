"""GLSL 440 shaders and Qt 6 QSB compiler pipeline for Tonantzintla Plasma 6 Plasmoids."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

QSB_CANDIDATES = (
    Path("/usr/lib/qt6/bin/qsb"),
    Path("/usr/lib64/qt6/bin/qsb"),
    Path("/usr/bin/qsb6"),
    Path("/usr/bin/qsb"),
)


def find_qsb() -> Path | None:
    for cand in QSB_CANDIDATES:
        if cand.is_file() and os.access(cand, os.X_OK):
            return cand
    found = shutil.which("qsb") or shutil.which("qsb6")
    return Path(found) if found else None


URANUS_STAGE_FRAG = r"""#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uTime;
    float uLock;
    float uHasTarget;
    float uTyping;
    vec2 uResolution;
    vec2 uCursor;
    vec2 uTarget;
    vec4 uAccent;
    vec4 uText;
};

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(0.80, -0.60, 0.60, 0.80);
    for (int i = 0; i < 4; i++) {
        v += a * noise2(p);
        p = rot * p * 2.04 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

// Distance to quadratic Bezier (approximate 6-segment polyline for crisp 120fps speed)
vec2 bezierDist(vec2 p, vec2 a, vec2 b, vec2 c) {
    float minD = 1e6;
    float bestT = 0.0;
    vec2 prev = a;
    for (int i = 1; i <= 10; i++) {
        float t = float(i) / 10.0;
        float it = 1.0 - t;
        vec2 cur = it * it * a + 2.0 * it * t * b + t * t * c;
        vec2 pa = p - prev;
        vec2 ba = cur - prev;
        float h = clamp(dot(pa, ba) / max(1e-5, dot(ba, ba)), 0.0, 1.0);
        float d = length(pa - ba * h);
        if (d < minD) {
            minD = d;
            bestT = (float(i - 1) + h) / 10.0;
        }
        prev = cur;
    }
    return vec2(minD, bestT);
}

// Ring radial density & color for Uranus's delicate 13-band ice ring system
vec4 evalRings(float r, float angle, float t) {
    if (r < 1.32 || r > 2.34) return vec4(0.0);

    // Subtle azimuthal ice crystal sparkle
    float sparkle = 0.88 + 0.12 * sin(angle * 7.0 - t * 0.45) * cos(r * 28.0 + angle * 3.0);

    // Inner dusty zeta sheet
    float zeta = exp(-pow((r - 1.48) / 0.11, 2.0)) * 0.14;
    // 6 / 5 / 4 thin bands
    float b654 = exp(-pow((r - 1.62) / 0.025, 2.0)) * 0.24
               + exp(-pow((r - 1.67) / 0.018, 2.0)) * 0.28;
    // Alpha / Beta / Eta / Gamma / Delta icy ring group
    float mid = exp(-pow((r - 1.76) / 0.032, 2.0)) * 0.48
              + exp(-pow((r - 1.84) / 0.016, 2.0)) * 0.36
              + exp(-pow((r - 1.90) / 0.020, 2.0)) * 0.42;
    // Prominent bright outer Epsilon ring (icy crystalline edge)
    float eps = exp(-pow((r - 2.04) / 0.044, 2.0)) * 0.88
              + exp(-pow((r - 2.075) / 0.014, 2.0)) * 0.46;
    // Outer whisper Mu / Nu rings
    float outer = exp(-pow((r - 2.22) / 0.022, 2.0)) * 0.18;

    // Fine Cassini-like dark gaps between bands
    float gap1 = 1.0 - 0.85 * exp(-pow((r - 1.71) / 0.014, 2.0));
    float gap2 = 1.0 - 0.90 * exp(-pow((r - 1.965) / 0.018, 2.0));

    float density = clamp((zeta + b654 + mid + eps + outer) * gap1 * gap2 * sparkle, 0.0, 0.95);
    if (density < 0.004) return vec4(0.0);

    vec3 iceCyan = vec3(0.68, 0.95, 0.99);
    vec3 pureIce = vec3(0.93, 0.99, 1.0);
    vec3 col = mix(iceCyan, pureIce, clamp(eps * 0.95 + mid * 0.3, 0.0, 1.0));
    col = mix(col, uAccent.rgb, smoothstep(1.92, 2.28, r) * 0.32);
    return vec4(col, density);
}

void main() {
    vec2 res = max(uResolution, vec2(1.0));
    vec2 px = qt_TexCoord0 * res;
    vec2 center = vec2(res.x * 0.5, res.y * 0.47);
    vec2 dPx = px - center;

    // Gentle spring-damped parallax offset
    vec2 par = uCursor * 5.5;
    vec2 uCenter = center + par * 0.20;
    vec2 pPlanet = px - uCenter;

    float lp = clamp(uLock, 0.0, 1.0);
    float breathe = 0.5 + 0.5 * sin(uTime * 0.85);
    float typingBoost = clamp(uTyping, 0.0, 1.0);

    vec3 col = vec3(0.0);
    float alpha = 0.0;

    // ------------------------------------------------------------------
    // 1. VOLUMETRIC ATMOSPHERIC CORONA & SUBTLE OBSERVATORY NEBULA MIST
    //    (Tight exponential falloff + radial fade -> pure matte obsidian perimeter)
    // ------------------------------------------------------------------
    float distC = length(dPx);
    float stageFade = smoothstep(0.94, 0.42, length(dPx / (res * 0.48)));
    float corona = exp(-distC / (82.0 + breathe * 5.0)) * (0.26 + 0.03 * breathe + typingBoost * 0.05) * stageFade;
    float outerBloom = exp(-distC / 132.0) * (0.085 + lp * 0.065) * stageFade;
    float mist = fbm(dPx * 0.0075 + vec2(uTime * 0.025, -uTime * 0.018)) * exp(-distC / 138.0) * 0.055 * stageFade;

    vec3 cyanGlow = vec3(0.45, 0.88, 0.96);
    col += cyanGlow * (corona + mist * 0.65);
    col += uAccent.rgb * (outerBloom + mist * 0.55);
    alpha = max(alpha, clamp(corona + outerBloom + mist, 0.0, 0.45));

    // ------------------------------------------------------------------
    // 2. MULTI-LAYER PARALLAX STARFIELD (ZERO-LOOP PROCEDURAL CELLS)
    // ------------------------------------------------------------------
    for (int layer = 0; layer < 2; layer++) {
        float scale = (layer == 0) ? 56.0 : 88.0;
        vec2 sp = (px + par * (layer == 0 ? 0.35 : 0.72) + vec2(uTime * (layer == 0 ? 0.35 : -0.22), 0.0)) / scale;
        vec2 cell = floor(sp);
        vec2 f = fract(sp) - 0.5;
        float rnd = hash21(cell + float(layer) * 71.3);
        if (rnd > 0.74) {
            vec2 off = (vec2(hash21(cell + 13.1), hash21(cell + 29.7)) - 0.5) * 0.68;
            float sd = length(f - off) * scale;
            float starR = mix(0.75, 1.45, fract(rnd * 17.3));
            float core = smoothstep(starR + 0.7, 0.0, sd);
            float halo = exp(-sd * 0.42) * 0.16;
            float tw = 0.24 + 0.52 * (0.5 + 0.5 * sin(uTime * (1.4 + fract(rnd * 9.1) * 1.6) + rnd * 40.0));
            // Fade stars gently near stage outer edge
            float edgeFade = smoothstep(0.98, 0.55, length((px - center) / (res * 0.52)));
            float sIntensity = (core + halo) * tw * edgeFade;
            vec3 sCol = (fract(rnd * 31.7) > 0.75) ? vec3(0.74, 0.96, 1.0)
                      : ((fract(rnd * 53.1) > 0.80) ? uAccent.rgb : uText.rgb);
            col += sCol * sIntensity * 0.72;
            alpha = max(alpha, sIntensity * 0.55);
        }
    }

    // ------------------------------------------------------------------
    // 3. DELICATE CONCENTRIC ORBIT TRACKS WITH MAGNETIC POINTER SHEEN
    // ------------------------------------------------------------------
    vec2 r1 = vec2(min(res.x * 0.25, 168.0), min(res.y * 0.305, 122.0));
    vec2 r2 = vec2(min(res.x * 0.415, 290.0), min(res.y * 0.435, 172.0));
    vec2 cursorPx = (uCursor * 0.5 + 0.5) * res;
    float ptrNear = exp(-length(px - cursorPx) / 115.0);

    for (int oi = 0; oi < 2; oi++) {
        vec2 rad = (oi == 0) ? r1 : r2;
        vec2 q = dPx / rad;
        float qLen = length(q);
        // Accurate screen-space pixel distance to ellipse
        vec2 grad = q / max(rad, vec2(1.0));
        float distPx = abs(qLen - 1.0) / max(1e-5, length(grad));
        float line = smoothstep(1.35, 0.25, distPx);
        float sheen = (0.068 - lp * 0.018) + ptrNear * 0.13 + typingBoost * 0.06;
        vec3 trackCol = mix(uText.rgb, uAccent.rgb, ptrNear * 0.72 + typingBoost * 0.35);
        col += trackCol * line * sheen;
        alpha = max(alpha, line * sheen * 1.15);
    }

    // ------------------------------------------------------------------
    // 4. TRUE 3D RAY-SPHERE URANUS + 3D RAY-PLANE ICY RING SYSTEM
    // ------------------------------------------------------------------
    float uR = 45.0;
    vec2 uv3 = pPlanet / uR;

    // Exact orthographic ray: zero silhouette shrink, constant ring-plane denom, pixel-perfect 3D ellipses!
    vec3 ro = vec3(uv3, 4.0);
    vec3 rd = vec3(0.0, 0.0, -1.0);

    // Uranus tilted coordinate basis (97.77 deg sideways ice giant!)
    float roll = 1.34 + uCursor.x * 0.036;   // Steep ~77 deg iconic Uranus ring angle
    float pitch = 0.295 + uCursor.y * 0.032; // Crisp ring foreshortening (~17 deg)
    float cr = cos(roll), sr = sin(roll);
    float cp = cos(pitch), sp = sin(pitch);

    // Ring lies in (axisU, axisV); planet spin axis is ringN
    vec3 axisU = vec3(cr, sr, 0.0);
    vec3 axisV = vec3(-sr * sp, cr * sp, cp);
    vec3 ringN = normalize(cross(axisU, axisV));

    // Sun direction from upper-left front
    vec3 sunDir = normalize(vec3(-0.62, -0.46, 0.64));

    // Exact analytical Ray-Sphere intersection (unit sphere at origin)
    float rad2 = dot(uv3, uv3);
    bool hitSphere = rad2 <= 1.0;
    float zSphere = hitSphere ? sqrt(max(0.0, 1.0 - rad2)) : -1e6;
    float tSphere = hitSphere ? (4.0 - zSphere) : 1e6;

    // Subpixel anti-aliased sphere limb
    float radialLen = sqrt(rad2);
    float sphereAA = smoothstep(1.0 + 1.2 / uR, 1.0 - 0.8 / uR, radialLen);

    // Exact analytical Ray-Ring plane intersection: dot(ro + t*rd, ringN) = 0
    float denom = dot(rd, ringN);
    bool hitRing = abs(denom) > 1e-4;
    float tRing = hitRing ? (-dot(ro, ringN) / denom) : 1e6;
    vec4 backRing = vec4(0.0);
    vec4 frontRing = vec4(0.0);

    if (hitRing && tRing > 0.0) {
        vec3 rp = ro + rd * tRing;
        float rr = length(rp);
        if (rr >= 1.32 && rr <= 2.34) {
            float rx = dot(rp, axisU);
            float ry = dot(rp, axisV);
            float rAng = atan(ry, rx);
            vec4 ringSample = evalRings(rr, rAng, uTime);

            if (ringSample.a > 0.002) {
                // Exact 3D planet-cast shadow onto Uranus's own rings
                float bs = dot(rp, sunDir);
                float cs = dot(rp, rp) - 1.0;
                float ds = bs * bs - cs;
                float shadow = 1.0;
                if (bs < 0.0 && ds > 0.0) {
                    shadow = mix(0.24, 1.0, smoothstep(0.10, -0.02, sqrt(ds)));
                }
                float ringLight = 0.72 + 0.34 * clamp(dot(normalize(rp), sunDir) * 0.5 + 0.5, 0.0, 1.0);
                ringSample.rgb *= ringLight * shadow;

                if (tRing > tSphere) {
                    backRing = vec4(ringSample.rgb, ringSample.a * (0.94 - lp * 0.14));
                } else {
                    frontRing = vec4(ringSample.rgb, ringSample.a * (0.98 - lp * 0.72));
                }
            }
        }
    }

    // Step 4A: Composite back rings behind planet
    if (backRing.a > 0.001) {
        col = mix(col, backRing.rgb, backRing.a);
        alpha = max(alpha, backRing.a);
    }

    // Helper for 3D depth-sorted icy moons (Titania, Miranda, Oberon)
    vec3 moonBackCol = vec3(0.0);
    float moonBackA = 0.0;
    vec3 moonFrontCol = vec3(0.0);
    float moonFrontA = 0.0;
    for (int m = 0; m < 3; m++) {
        float mSpeed = (m == 0) ? 0.46 : ((m == 1) ? -0.72 : 0.31);
        float mPhase = (m == 0) ? 0.55 : ((m == 1) ? 2.85 : 4.65);
        float mRad   = (m == 0) ? 2.04 : ((m == 1) ? 1.69 : 2.26);
        float mSize  = (m == 0) ? 2.45 : ((m == 1) ? 1.85 : 1.55);
        float ma = uTime * mSpeed + mPhase;
        vec3 mp = axisU * (cos(ma) * mRad) + axisV * (sin(ma) * mRad);
        vec2 mScreen = uCenter + mp.xy * uR;
        float md = length(px - mScreen);
        if (md < 18.0) {
            float mCore = smoothstep(mSize + 0.75, mSize - 0.55, md);
            float mGlow = exp(-md / (mSize * 2.2)) * 0.46;
            vec3 mc = (m == 1) ? uAccent.rgb : vec3(0.86, 0.98, 1.0);
            float maOut = clamp(mCore + mGlow, 0.0, 1.0);
            if (mp.z < 0.0) {
                moonBackCol += mc * maOut;
                moonBackA = max(moonBackA, maOut);
            } else {
                moonFrontCol += mc * maOut;
                moonFrontA = max(moonFrontA, maOut);
            }
        }
    }
    if (moonBackA > 0.001) {
        col += moonBackCol;
        alpha = max(alpha, moonBackA);
    }

    // Step 4B: Composite 3D Ray-Shaded Uranus Sphere
    if (sphereAA > 0.001) {
        vec3 spPos = vec3(uv3, sqrt(max(0.0001, 1.0 - min(rad2, 0.9999))));
        vec3 N = normalize(spPos);
        vec3 V = vec3(0.0, 0.0, 1.0);

        // Transform normal into Uranus's tilted body frame (spin axis = ringN)
        float bx = dot(N, axisU);
        float bz = dot(N, axisV);
        float by = dot(N, ringN);
        float lat = asin(clamp(by, -1.0, 1.0));
        float lon = atan(bz, bx) + uTime * 0.14;

        // Procedural silky methane cloud bands + gentle domain-warped equatorial jets
        float warp = fbm(vec2(lon * 1.4, lat * 3.8 + uTime * 0.03)) * 0.22;
        float bandCoord = lat * 5.2 + warp;
        float bands = 0.5 + 0.5 * (sin(bandCoord * 2.4) * 0.62 + cos(bandCoord * 4.7 - warp * 2.8) * 0.38);
        float fineCloud = fbm(vec2(lon * 2.6 + uTime * 0.04, lat * 8.0)) * 0.16;

        // Luminous Voyager 2 / JWST Uranus aquamarine-cerulean methane palette
        vec3 deepTeal = vec3(0.18, 0.54, 0.68);
        vec3 midCyan  = vec3(0.48, 0.88, 0.95);
        vec3 paleIce  = vec3(0.86, 0.99, 1.00);
        vec3 albedo = mix(deepTeal, midCyan, clamp(bands * 0.80 + fineCloud, 0.0, 1.0));

        // Signature bright sunlit methane north polar hood (tilted sideways!)
        float polarHood = smoothstep(0.24, 0.92, -by) * 0.48 + smoothstep(0.60, 0.98, by) * 0.18;
        albedo = mix(albedo, paleIce, polarHood);

        // Exact 3D ring-cast shadow onto Uranus's cloud tops!
        float ringShadowOnPlanet = 1.0;
        float sDenom = dot(sunDir, ringN);
        if (abs(sDenom) > 1e-4) {
            float ts = -dot(spPos, ringN) / sDenom;
            if (ts > 0.0) {
                vec3 srp = spPos + sunDir * ts;
                float srr = length(srp);
                if (srr >= 1.32 && srr <= 2.34) {
                    vec4 sRing = evalRings(srr, 0.0, uTime);
                    ringShadowOnPlanet = 1.0 - sRing.a * 0.40;
                }
            }
        }

        // Rich atmospheric diffuse + soft subsurface wrap + night-side cerulean ambient
        float ndl = dot(N, sunDir);
        float diff = smoothstep(-0.30, 0.86, ndl);
        float spec = pow(max(dot(reflect(-sunDir, N), V), 0.0), 16.0) * 0.14;
        vec3 lit = albedo * (0.20 + 0.94 * diff * ringShadowOnPlanet) + vec3(0.88, 0.99, 1.0) * spec;

        // Physical Rayleigh scattering ice-cyan Fresnel limb glow
        float ndv = max(dot(N, V), 0.0);
        float fresnel = pow(1.0 - ndv, 3.0);
        vec3 rimCol = mix(vec3(0.62, 0.96, 1.0), uAccent.rgb, lp * 0.78);
        lit += rimCol * fresnel * (0.48 + 0.36 * smoothstep(-0.35, 0.7, ndl));

        // Smooth velvety obsidian core aperture when an app is locked
        if (lp > 0.005) {
            float coreFade = smoothstep(1.0, 0.20, radialLen);
            vec3 obsidianCore = vec3(0.055, 0.058, 0.088);
            lit = mix(lit, obsidianCore, lp * (0.42 + 0.50 * coreFade));
        }

        col = mix(col, lit, sphereAA);
        alpha = max(alpha, sphereAA);
    }

    // Subtle Rayleigh outer glow + refined lavender focus ring on lock
    float atmoGlow = exp(-max(0.0, radialLen - 0.96) * 9.0) * 0.22 * (1.0 - sphereAA * 0.75);
    col += mix(vec3(0.56, 0.95, 1.0), uAccent.rgb, lp * 0.65) * atmoGlow;
    alpha = max(alpha, atmoGlow * 0.85);

    if (lp > 0.01) {
        float focusR = 1.0 + (4.2 + lp * 1.4) / uR;
        float focusRing = smoothstep(1.4, 0.2, abs(radialLen - focusR) * uR) * lp * 0.45;
        col += uAccent.rgb * focusRing;
        alpha = max(alpha, focusRing);
    }

    // Step 4C: Composite front rings sweeping across Uranus + front moons
    if (frontRing.a > 0.001) {
        col = mix(col, frontRing.rgb, frontRing.a);
        alpha = max(alpha, frontRing.a);
    }
    if (moonFrontA > 0.001) {
        col += moonFrontCol;
        alpha = max(alpha, moonFrontA);
    }

    // ------------------------------------------------------------------
    // 5. LUMINOUS GRAVITY TETHER + PHOTON ENERGY WAVE TO SELECTED APP
    // ------------------------------------------------------------------
    if (uHasTarget > 0.5 && lp > 0.01) {
        vec2 dir = uTarget - uCenter;
        float dLen = max(1.0, length(dir));
        vec2 nDir = dir / dLen;
        vec2 perp = vec2(-nDir.y, nDir.x);

        vec2 a = uCenter + nDir * (uR + 3.5);
        vec2 c = uTarget - nDir * 27.0;
        // Subtle gentle orbital curve on the gravity filament
        vec2 b = (a + c) * 0.5 + perp * (sin(uTime * 0.9) * 5.0 + 10.0);

        vec2 bd = bezierDist(px, a, b, c);
        float lineCore = smoothstep(1.65, 0.25, bd.x);
        float lineHalo = exp(-bd.x * 0.22) * 0.42;
        float tParam = bd.y;

        // Dual photon wave pulses streaming from selected app into Uranus
        float wave1 = exp(-pow(fract(tParam + uTime * 0.62) - 0.5, 2.0) * 48.0);
        float wave2 = exp(-pow(fract(tParam + uTime * 0.62 + 0.5) - 0.5, 2.0) * 60.0) * 0.72;
        float waveBoost = (wave1 + wave2) * smoothstep(0.0, 0.12, tParam) * smoothstep(1.0, 0.88, tParam);

        vec3 tetherCol = mix(vec3(0.58, 0.95, 1.0), uAccent.rgb, tParam);
        vec3 pulseCol = vec3(0.95, 0.99, 1.0);
        float tetherAmt = (lineCore * 0.95 + lineHalo) * lp;
        float pulseMask = waveBoost * (lineCore + lineHalo * 0.85) * lp;
        col += tetherCol * tetherAmt + pulseCol * pulseMask;
        alpha = max(alpha, clamp(tetherAmt + pulseMask * 0.70, 0.0, 1.0));

        // Soft lavender gravity well bloom right underneath the selected app node
        float targetDist = length(px - uTarget);
        float targetAura = exp(-targetDist / 38.0) * 0.32 * lp;
        col += uAccent.rgb * targetAura;
        alpha = max(alpha, targetAura);
    }

    // Premultiplied alpha output for spotless compositing over obsidian dialog frame
    float outA = clamp(alpha, 0.0, 1.0);
    fragColor = vec4(col, outA) * qt_Opacity;
}
"""


WORKSPACES_METABALL_FRAG = r"""#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uTime;
    float uCount;
    float uActivePos;
    float uHoverIdx;
    float uHoverAmt;
    vec2 uResolution;
    vec4 uAccent;
    vec4 uText;
    vec4 uMuted;
};

float sdCapsule(vec2 p, vec2 a, vec2 b, float r) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(1e-5, dot(ba, ba)), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / max(1e-4, k), 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

void main() {
    vec2 res = max(uResolution, vec2(1.0));
    vec2 p = qt_TexCoord0 * res;
    int count = clamp(int(uCount + 0.5), 1, 10);

    float cy = res.y * 0.5;
    float padX = 16.0;
    float usableW = max(1.0, res.x - padX * 2.0);
    // The active capsule is wider than a dot, so it gets extra room on both sides and every gap stays equal.
    float room = 9.0;
    float stepX = (count > 1) ? ((usableW - room * 2.0) / float(count - 1)) : 0.0;

    // Active liquid capsule position + motion stretch while gliding between desktops
    float actIdx = clamp(uActivePos, 0.0, float(count - 1));
    float actX = (count > 1) ? (padX + actIdx * stepX + room) : (res.x * 0.5);
    float transit = sin(fract(actIdx) * 3.14159265);
    float halfLen = 8.5 + transit * 5.2;
    float actR = 3.65 - transit * 0.35;

    float dActive = sdCapsule(p, vec2(actX - halfLen, cy), vec2(actX + halfLen, cy), actR);

    // Combine inactive dots with liquid metaball smooth-minimum near the gliding active capsule
    float dDots = 1e5;
    float hoverMask = 0.0;
    float metaballField = dActive;

    for (int i = 0; i < 10; i++) {
        if (i >= count) break;
        float fi = float(i);
        float dx = (count > 1) ? (padX + fi * stepX + room * (clamp(fi - actIdx, -1.0, 1.0) + 1.0)) : (res.x * 0.5);
        float distToActive = abs(fi - actIdx);
        float isHov = (abs(fi - uHoverIdx) < 0.25) ? uHoverAmt : 0.0;
        float dotHalf = isHov * 2.2;
        float dotR = 3.25 + isHov * 0.35;
        float di = sdCapsule(p, vec2(dx - dotHalf, cy), vec2(dx + dotHalf, cy), dotR);

        // Smoothly merge nearby dot into active liquid bead ONLY during transition (crisp at rest!)
        float mergeK = smoothstep(1.30, 0.05, distToActive) * (transit * 6.2);
        if (mergeK > 0.05) {
            metaballField = smin(metaballField, di, mergeK);
        }
        if (distToActive > 0.35) {
            dDots = min(dDots, di);
            if (isHov > 0.01) {
                hoverMask = max(hoverMask, smoothstep(1.0, -0.6, di) * isHov);
            }
        }
    }

    float aa = 0.9;
    float inactiveAlpha = smoothstep(aa, -aa, dDots) * mix(0.42, 0.86, hoverMask);
    vec3 inactiveCol = mix(uMuted.rgb, uText.rgb, hoverMask);

    float activeAlpha = smoothstep(aa, -aa, metaballField);
    // Subtle liquid top-edge glass sheen + soft outer glow
    float topSheen = smoothstep(1.5, -2.5, p.y - cy) * 0.16;
    vec3 activeCol = uAccent.rgb + vec3(topSheen);
    float glow = exp(-max(0.0, metaballField) * 0.42) * 0.22;

    vec3 rgb = vec3(0.0);
    float outA = 0.0;

    // Inactive dots
    rgb += inactiveCol * inactiveAlpha;
    outA = max(outA, inactiveAlpha);

    // Active glow
    rgb += uAccent.rgb * glow * (1.0 - activeAlpha);
    outA = max(outA, glow);

    // Active liquid capsule on top
    rgb = mix(rgb, activeCol, activeAlpha);
    outA = max(outA, activeAlpha);

    fragColor = vec4(rgb * outA + (activeCol - rgb * outA) * 0.0, outA);
    // Exact premultiplied composite
    vec3 premul = inactiveCol * inactiveAlpha * (1.0 - activeAlpha)
                + uAccent.rgb * glow * (1.0 - activeAlpha)
                + activeCol * activeAlpha;
    fragColor = vec4(premul, clamp(outA, 0.0, 1.0)) * qt_Opacity;
}
"""


VINYL_DISC_FRAG = r"""#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uAngle;
    float uPlaying;
    vec2 uResolution;
    vec4 uAccent;
};

void main() {
    vec2 res = max(uResolution, vec2(1.0));
    vec2 uv = (qt_TexCoord0 - 0.5) * 2.0;
    float r = length(uv);
    float px = 2.0 / min(res.x, res.y);

    float discMask = smoothstep(1.0, 1.0 - px * 1.4, r);
    if (discMask < 0.002) {
        fragColor = vec4(0.0);
        return;
    }

    float theta = atan(uv.y, uv.x);
    float rotTheta = theta - uAngle;

    // Deep obsidian-graphite pressed vinyl base
    vec3 col = mix(vec3(0.075, 0.075, 0.105), vec3(0.036, 0.036, 0.052), smoothstep(0.32, 0.98, r));

    // High-frequency concentric micro-grooves + subtle track lead-in/lead-out bands
    float inGrooves = smoothstep(0.34, 0.38, r) * smoothstep(0.97, 0.93, r);
    float micro = 0.5 + 0.5 * sin(r * 195.0 + sin(rotTheta * 2.0) * 0.18);
    float bandGap = exp(-pow((r - 0.58) / 0.015, 2.0)) + exp(-pow((r - 0.79) / 0.014, 2.0));
    col += vec3(0.042, 0.044, 0.060) * micro * inGrooves * (1.0 - bandGap * 0.7);

    // Anisotropic brushed specular light wedges (stationary studio light, subtle wobble with spin)
    float lightAng = theta + 0.62 + sin(uAngle * 2.0) * 0.03 * uPlaying;
    float lobe = pow(abs(cos(lightAng)), 10.0) * 0.24 + pow(abs(cos(lightAng)), 34.0) * 0.28;
    // Whisper-subtle rainbow optical diffraction along the specular wedge (true vinyl look!)
    vec3 diffTint = vec3(
        0.5 + 0.5 * sin(r * 26.0 + 0.0),
        0.5 + 0.5 * sin(r * 26.0 + 2.1),
        0.5 + 0.5 * sin(r * 26.0 + 4.2)
    );
    vec3 sheenCol = mix(vec3(0.88, 0.90, 0.98), diffTint, 0.22);
    col += sheenCol * lobe * inGrooves * (0.55 + 0.45 * micro);

    // Outer beveled accent rim
    float rim = smoothstep(px * 2.2, 0.0, abs(r - (1.0 - px * 1.0)));
    col = mix(col, uAccent.rgb, rim * (0.34 + 0.22 * uPlaying));

    // Center accent record label with rotating micro-grooves & print arc
    float labelMask = smoothstep(0.34 + px, 0.34 - px, r);
    if (labelMask > 0.001) {
        vec3 lblCol = mix(uAccent.rgb * 0.86, uAccent.rgb * 1.08, 0.5 + 0.5 * cos(theta + 0.7));
        float innerRing = smoothstep(px * 1.4, 0.0, abs(r - 0.24));
        float arcMark = smoothstep(px * 1.6, 0.0, abs(r - 0.19)) * smoothstep(0.25, 0.45, cos(rotTheta));
        lblCol = mix(lblCol, vec3(0.08, 0.08, 0.12), innerRing * 0.42 + arcMark * 0.45);
        col = mix(col, lblCol, labelMask);
    }

    // Center spindle bore
    float holeMask = smoothstep(0.095 + px, 0.095 - px, r);
    col = mix(col, vec3(0.045, 0.045, 0.065), holeMask);

    fragColor = vec4(col * discMask, discMask) * qt_Opacity;
}
"""


MEDIA_WAVE_FRAG = r"""#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uTime;
    float uProgress;
    float uHoverRatio;
    float uPlaying;
    float uSeed;
    vec2 uResolution;
    vec4 uAccent;
    vec4 uText;
};

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 res = max(uResolution, vec2(1.0));
    vec2 p = qt_TexCoord0 * res;

    const float N = 32.0;
    float barW = 3.8;
    float cellW = res.x / N;
    float idx = clamp(floor(p.x / cellW), 0.0, N - 1.0);
    float norm = (idx + 0.5) / N;

    // Track-seeded acoustic silhouette + subtle harmonic breathing when playing
    float s = uSeed * 0.17;
    float contour = 0.26
                  + 0.36 * abs(sin(idx * 0.62 + s))
                  + 0.22 * abs(cos(idx * 1.38 - s * 0.65))
                  + 0.12 * abs(sin(idx * 2.35 + s * 1.4));

    // Gentle traveling harmonic ripple radiating from playhead when playing
    float distHead = abs(norm - uProgress);
    float liveWave = uPlaying * (
        0.10 * sin(uTime * 5.2 - idx * 0.55) * exp(-distHead * 5.5)
      + 0.05 * sin(uTime * 3.1 + idx * 0.9)
    );

    // Tactile Gaussian dock-wave lift around hovered scrub position
    float hovering = step(0.0, uHoverRatio);
    float hoverLift = hovering * 0.24 * exp(-pow((norm - uHoverRatio) / 0.085, 2.0));

    float hFrac = clamp(contour + liveWave + hoverLift, 0.18, 0.92);
    float barHalfH = max(2.6, (res.y * 0.45) * hFrac);

    vec2 barCenter = vec2((idx + 0.5) * cellW, res.y * 0.5);
    float d = sdRoundBox(p - barCenter, vec2(barW * 0.5, barHalfH), barW * 0.5);
    float barMask = smoothstep(0.85, -0.45, d);

    bool passed = norm <= uProgress;
    bool preview = (hovering > 0.5) && (norm <= uHoverRatio) && !passed;

    vec3 barCol = passed
        ? mix(uAccent.rgb, vec3(0.95, 0.94, 1.0), exp(-distHead * 18.0) * 0.35 * uPlaying)
        : (preview ? mix(uText.rgb * 0.3, uAccent.rgb, 0.58) : uText.rgb);
    float barA = passed ? 0.98 : (preview ? 0.55 : 0.17);

    // Subtle soft glow beneath the active playhead bar
    float headPxX = uProgress * res.x;
    float headGlow = exp(-length((p - vec2(headPxX, res.y * 0.5)) * vec2(0.09, 0.11))) * 0.24 * (0.45 + 0.55 * uPlaying);

    vec3 premul = uAccent.rgb * headGlow;
    float outA = headGlow;

    premul = mix(premul, barCol * barA, barMask);
    outA = max(outA, barMask * barA);

    // Crisp hovering vertical playhead hairline
    if (hovering > 0.5) {
        float hx = uHoverRatio * res.x;
        float hLine = smoothstep(1.3, 0.2, abs(p.x - hx)) * smoothstep(0.0, 3.0, p.y) * smoothstep(res.y, res.y - 3.0, p.y);
        premul += uText.rgb * hLine * 0.72;
        outA = max(outA, hLine * 0.72);
    }

    fragColor = vec4(premul, clamp(outA, 0.0, 1.0)) * qt_Opacity;
}
"""


CLOCK_DIAL_FRAG = r"""#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uHourAngle;
    float uMinAngle;
    float uSecAngle;
    vec2 uResolution;
    vec4 uAccent;
    vec4 uText;
    vec4 uSurface;
};

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(1e-5, dot(ba, ba)), 0.0, 1.0);
    return length(pa - ba * h);
}

void main() {
    vec2 res = max(uResolution, vec2(1.0));
    vec2 c = res * 0.5;
    vec2 p = qt_TexCoord0 * res - c;
    float scale = min(res.x, res.y) * 0.5;
    float r = length(p);
    float ang = atan(p.y, p.x);

    // 12-lobed Serpantinum scalloped silhouette SDF
    float baseR = scale * 0.84;
    float amp = scale * 0.068;
    float scallopR = baseR + amp * cos(12.0 * ang);
    float dScallop = r - scallopR;

    float faceMask = smoothstep(0.95, -0.65, dScallop);
    vec3 col = vec3(0.0);
    float outA = 0.0;

    if (faceMask > 0.002) {
        // Brushed matte radial depth + subtle top-left observatory light gradient
        float radial = clamp(r / baseR, 0.0, 1.0);
        float topLeft = clamp(dot(normalize(p + vec2(1e-4)), normalize(vec2(-1.0, -1.0))) * 0.5 + 0.5, 0.0, 1.0);
        vec3 centerCol = uSurface.rgb + vec3(0.032, 0.032, 0.045);
        vec3 rimBase   = uSurface.rgb - vec3(0.018, 0.018, 0.022);
        vec3 face = mix(centerCol, rimBase, radial * 0.85);
        // Subtle machined concentric dial texture
        face += vec3(0.012) * sin(r * 1.7) * (1.0 - radial * 0.5);

        // Delicate recessed inner chapter ring
        float chRing = smoothstep(0.95, 0.15, abs(r - scale * 0.67));
        face = mix(face, uText.rgb, chRing * 0.055);

        // 60 micro-ticks + 12 crisp hour indices (cardinal indices in accent)
        float sector60 = mod(ang + 3.14159265 + 0.05235987, 0.10471975) - 0.05235987;
        float tickDist60 = abs(sector60) * r;
        float tick60 = smoothstep(0.62, 0.12, tickDist60) * smoothstep(scale * 0.72, scale * 0.735, r) * smoothstep(scale * 0.765, scale * 0.75, r);
        face = mix(face, uText.rgb, tick60 * 0.14);

        float sector12 = mod(ang + 3.14159265 + 0.26179938, 0.52359877) - 0.26179938;
        float tickDist12 = abs(sector12) * r;
        float isCardinal = step(0.88, abs(cos(ang * 2.0)));
        float innerIdx = mix(scale * 0.68, scale * 0.61, isCardinal);
        float thickIdx = mix(0.65, 1.05, isCardinal);
        float tick12 = smoothstep(thickIdx + 0.45, thickIdx - 0.25, tickDist12)
                     * smoothstep(innerIdx - 0.5, innerIdx + 0.5, r)
                     * smoothstep(scale * 0.765, scale * 0.745, r);
        face = mix(face, mix(uText.rgb, uAccent.rgb, isCardinal), tick12 * mix(0.32, 0.92, isCardinal));

        // Subtle beveled scalloped rim highlight catching upper-left light
        float rimBand = smoothstep(1.4, 0.15, abs(dScallop + 0.55));
        face = mix(face, uText.rgb, rimBand * (0.075 + 0.085 * topLeft));

        // Continuous sweeping amber-gold second comet trail
        float sTrackR = scale * 0.685;
        float dDiff = mod(uSecAngle - ang + 6.2831853, 6.2831853);
        float cometArc = exp(-dDiff * 3.4) * smoothstep(1.45, 0.0, dDiff) * smoothstep(1.35, 0.15, abs(r - sTrackR));
        vec3 gold = vec3(0.925, 0.753, 0.471);
        face += gold * cometArc * 0.42;

        // Soft drop shadows for hour and minute hands
        vec2 hDir = vec2(cos(uHourAngle), sin(uHourAngle));
        vec2 mDir = vec2(cos(uMinAngle), sin(uMinAngle));
        float dHourSh = sdSegment(p - vec2(1.0, 1.6), -hDir * (scale * 0.11), hDir * (scale * 0.43));
        float dMinSh  = sdSegment(p - vec2(1.0, 1.8), -mDir * (scale * 0.14), mDir * (scale * 0.61));
        face *= 1.0 - 0.34 * smoothstep(3.2, 0.4, dHourSh);
        face *= 1.0 - 0.28 * smoothstep(2.6, 0.3, dMinSh);

        // Hour hand (pastel accent)
        float dHour = sdSegment(p, -hDir * (scale * 0.11), hDir * (scale * 0.43));
        float hourMask = smoothstep(1.95, 1.15, dHour);
        face = mix(face, uAccent.rgb, hourMask);

        // Minute hand (crisp silver-white)
        float dMin = sdSegment(p, -mDir * (scale * 0.14), mDir * (scale * 0.61));
        float minMask = smoothstep(1.35, 0.65, dMin);
        face = mix(face, uText.rgb, minMask * 0.96);

        // Orbiting golden second orb with luminous halo
        vec2 sPos = vec2(cos(uSecAngle), sin(uSecAngle)) * sTrackR;
        float sdSec = length(p - sPos);
        face += gold * exp(-sdSec * 0.48) * 0.46;
        face = mix(face, gold, smoothstep(2.55, 1.75, sdSec));

        // Double-layered jewel center pivot pin
        float capOuter = smoothstep(3.4, 2.6, r);
        float capInner = smoothstep(1.45, 0.85, r);
        face = mix(face, uAccent.rgb, capOuter);
        face = mix(face, vec3(0.086, 0.086, 0.114), capInner);

        col = face;
        outA = faceMask;
    }

    fragColor = vec4(col * outA, outA) * qt_Opacity;
}
"""


STATUS_FADER_FRAG = r"""#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uTime;
    float uRatio;
    float uMuted;
    float uPressed;
    float uEnergy;
    vec2 uResolution;
    vec4 uAccent;
    vec4 uAccentFg;
    vec4 uSurface;
    vec4 uText;
};

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 res = max(uResolution, vec2(1.0));
    vec2 p = qt_TexCoord0 * res;
    vec2 halfRes = res * 0.5;
    float rad = 10.0;

    float dTrack = sdRoundBox(p - halfRes, halfRes - vec2(0.5), rad);
    float trackMask = smoothstep(0.85, -0.55, dTrack);
    if (trackMask < 0.002) {
        fragColor = vec4(0.0);
        return;
    }

    // Matte recessed obsidian slider bed with subtle top inner shadow
    float topShadow = exp(-max(0.0, p.y) * 0.35) * 0.16;
    vec3 col = uSurface.rgb * (1.0 - topShadow);

    // Subtle precision tick notches along the empty right side of the fader bed
    float notchSpacing = res.x / 10.0;
    float nx = abs(mod(p.x + notchSpacing * 0.5, notchSpacing) - notchSpacing * 0.5);
    float ny = abs(p.y - halfRes.y);
    float notch = smoothstep(0.9, 0.2, nx) * smoothstep(4.5, 2.5, ny);
    col = mix(col, uText.rgb, notch * 0.055);

    // Active fill bar (cleanly SDF-clipped inside the rounded capsule at ANY percentage!)
    float fillW = clamp(uRatio, 0.0, 1.0) * res.x;
    if (fillW > 0.5) {
        float fillRad = min(7.0, fillW * 0.5);
        float dFill = sdRoundBox(p - vec2(fillW * 0.5, halfRes.y), vec2(fillW * 0.5, halfRes.y), fillRad);
        float fillMask = smoothstep(0.85, -0.55, dFill);

        vec3 mutedFill = mix(uSurface.rgb, uText.rgb, 0.24);
        vec3 baseFill = mix(uAccent.rgb, mutedFill, uMuted);

        // Living liquid-light caustic shimmer + transient pressure ripple on volume change
        float wave1 = 0.5 + 0.5 * sin(p.x * 0.045 - uTime * 2.2 + sin(p.y * 0.18));
        float edgeDist = max(0.0, fillW - p.x);
        float ripple = sin(edgeDist * 0.28 - uTime * 10.0) * exp(-edgeDist * 0.032) * uEnergy;
        float topSheen = exp(-max(0.0, p.y) * 0.42) * 0.14;

        vec3 liveFill = baseFill
                      + vec3(0.055, 0.045, 0.085) * wave1 * (1.0 - uMuted)
                      + vec3(0.14, 0.12, 0.18) * max(0.0, ripple) * (1.0 - uMuted)
                      + vec3(topSheen) * (1.0 - uMuted * 0.6);

        // Crisp vertical tactile handle pill inset 9px from the active fill edge
        if (fillW > 18.0) {
            float dPip = sdRoundBox(p - vec2(fillW - 8.5, halfRes.y), vec2(1.6, 7.2), 1.6);
            float pipMask = smoothstep(0.75, -0.45, dPip);
            vec3 pipCol = mix(uAccentFg.rgb, uText.rgb, uMuted);
            float pipOp = mix(0.58, 0.94, uPressed);
            liveFill = mix(liveFill, pipCol, pipMask * pipOp);
        }

        col = mix(col, liveFill, fillMask);
    }

    // Razor-crisp 1px inner hairline border
    float rim = smoothstep(1.2, 0.1, abs(dTrack + 0.4));
    col = mix(col, mix(uText.rgb, uAccent.rgb, uPressed * 0.6), rim * (0.075 + uPressed * 0.12));

    fragColor = vec4(col * trackMask, trackMask) * qt_Opacity;
}
"""


SPLASH_HORIZON_FRAG = r"""#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uTime;
    float uProgress;
    vec2 uResolution;
    vec4 uAccent;
};

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 34.2);
    return fract(p.x * p.y);
}

void main() {
    vec2 res = max(uResolution, vec2(1.0));
    vec2 px = qt_TexCoord0 * res;
    vec2 c = vec2(res.x * 0.5, res.y * 0.45);
    vec2 d = px - c;
    float r = length(d);
    float ang = atan(d.y, d.x);

    vec3 col = vec3(0.0);
    float outA = 0.0;

    // Subtle deep-space starfield
    vec2 sp = px / 72.0;
    vec2 cell = floor(sp);
    vec2 f = fract(sp) - 0.5;
    float rnd = hash21(cell);
    if (rnd > 0.72) {
        vec2 off = (vec2(hash21(cell + 7.1), hash21(cell + 19.3)) - 0.5) * 0.72;
        float sd = length(f - off) * 72.0;
        float tw = 0.14 + 0.30 * (0.5 + 0.5 * sin(uTime * 1.6 + rnd * 35.0));
        float star = smoothstep(1.5, 0.0, sd) * tw;
        col += vec3(0.92, 0.91, 0.96) * star;
        outA = max(outA, star);
    }

    // Soft gravitational observatory aura behind the canonical Wabi Sabi Black Hole mark
    float aura = exp(-pow((r - 58.0) / 56.0, 2.0)) * 0.14 + exp(-r / 155.0) * 0.07;
    vec3 gold = vec3(0.914, 0.722, 0.447);
    col += mix(gold, uAccent.rgb, smoothstep(45.0, 145.0, r)) * aura;
    outA = max(outA, aura * 0.9);

    // Outer rotating astrolabe ring (radius 126px) + 12 engraved degree ticks + lavender satellite
    float aOuter = ang - uTime * 0.14;
    float ringOut = smoothstep(1.2, 0.15, abs(r - 126.0)) * 0.24;
    float sec12 = mod(aOuter + 3.14159265 + 0.26179938, 0.52359877) - 0.26179938;
    float tick = smoothstep(0.85, 0.15, abs(sec12) * r) * smoothstep(120.5, 121.5, r) * smoothstep(127.0, 126.0, r) * 0.30;
    vec2 sat1Pos = vec2(cos(uTime * 0.14), sin(uTime * 0.14)) * 126.0;
    float sat1D = length(d - sat1Pos);
    float sat1 = smoothstep(3.2, 1.8, sat1D) + exp(-sat1D * 0.25) * 0.38;

    col += uAccent.rgb * (ringOut + tick + sat1 * 0.92);
    outA = max(outA, clamp(ringOut + tick + sat1 * 0.85, 0.0, 1.0));

    // Inner counter-rotating gold arcs (radius 94px) + amber satellite
    float aIn = mod(ang + uTime * 0.22 + 6.2831853, 2.0943951);
    float arcMask = smoothstep(0.20, 0.26, aIn) * smoothstep(1.38, 1.32, aIn);
    float ringIn = smoothstep(1.35, 0.2, abs(r - 94.0)) * arcMask * 0.38;
    vec2 sat2Pos = vec2(cos(-uTime * 0.22 + 3.14159265), sin(-uTime * 0.22 + 3.14159265)) * 94.0;
    float sat2D = length(d - sat2Pos);
    float sat2 = smoothstep(2.7, 1.5, sat2D) + exp(-sat2D * 0.30) * 0.35;

    col += gold * (ringIn + sat2 * 0.92);
    outA = max(outA, clamp(ringIn + sat2 * 0.85, 0.0, 1.0));

    fragColor = vec4(col, clamp(outA, 0.0, 1.0)) * qt_Opacity;
}
"""


SHADERS: dict[str, str] = {
    "plasmoids/org.tonantzintla.launcher/contents/shaders/uranus_stage.frag.qsb": URANUS_STAGE_FRAG,
    "plasmoids/org.tonantzintla.workspaces/contents/shaders/workspaces_metaball.frag.qsb": WORKSPACES_METABALL_FRAG,
    "plasmoids/org.tonantzintla.media/contents/shaders/vinyl_disc.frag.qsb": VINYL_DISC_FRAG,
    "plasmoids/org.tonantzintla.media/contents/shaders/media_wave.frag.qsb": MEDIA_WAVE_FRAG,
    "plasmoids/org.tonantzintla.clock/contents/shaders/clock_dial.frag.qsb": CLOCK_DIAL_FRAG,
    "plasmoids/org.tonantzintla.status/contents/shaders/status_fader.frag.qsb": STATUS_FADER_FRAG,
    "look-and-feel/org.tonantzintla.desktop/contents/splash/shaders/splash_horizon.frag.qsb": SPLASH_HORIZON_FRAG,
}


def compile_shaders(output_root: Path, fallback_root: Path | None = None) -> list[str]:
    """Compile all GLSL 440 fragment shaders to Qt 6 .frag.qsb binaries via qsb."""
    qsb = find_qsb()
    built: list[str] = []

    with tempfile.TemporaryDirectory(prefix="tonantzintla-qsb-") as tmp:
        tmp_dir = Path(tmp)
        for rel, source in SHADERS.items():
            dst = output_root / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            if qsb is not None:
                slug = hashlib.sha256(rel.encode("utf-8")).hexdigest()[:12]
                src_file = tmp_dir / f"{slug}.frag"
                src_file.write_text(source.lstrip("\n"), encoding="utf-8")
                res = subprocess.run(
                    [str(qsb), "--glsl", "100 es,120,150", "-o", str(dst), str(src_file)],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                if res.returncode != 0:
                    raise RuntimeError(f"qsb failed for {rel}: {res.stderr.strip() or res.stdout.strip()}")
                built.append(rel)
            elif fallback_root is not None and (fallback_root / rel).is_file():
                shutil.copy2(fallback_root / rel, dst)
                built.append(rel)
            else:
                raise RuntimeError(f"Qt 6 qsb shader compiler not found and no prebuilt {rel} available.")
    return built
