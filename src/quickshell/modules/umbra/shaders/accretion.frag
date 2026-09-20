#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float energy;
    float collapse;
    float shock;
    float opening;
    vec4 primary;
    vec4 secondary;
    vec4 coreColor;
};

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float gas(vec2 p) { return noise(p) * .57 + noise(p * 2.07) * .28 + noise(p * 4.13) * .15; }

void main() {
    vec2 p = (qt_TexCoord0 - .5) * 2.0;
    // The disk plane stays fixed; only the emission travels around it.
    p = mat2(.966, .259, -.259, .966) * p;
    float drain = smoothstep(.08, .64, collapse);
    float rush = smoothstep(.12, .76, collapse);
    float flowTime = time + collapse * collapse * 8.;
    float r = length(p);
    float angle = atan(p.y, p.x);
    float born = smoothstep(.015, .27, opening);
    float ignition = smoothstep(.19, .76, opening);
    float sweep = smoothstep(.06, .52, opening);
    float horizon = .285 * (.32 + .68 * born);
    float ellipse = length(vec2(p.x, p.y / .205));
    float diskAngle = atan(p.y / .205, p.x);
    float diskMask = smoothstep(.29, .38, ellipse)
        * (1.0 - smoothstep(mix(.65, .35, drain), mix(.99, .48, drain), ellipse));
    float filaments = pow(.5 + .5 * sin(ellipse * 245.0 + gas(vec2(diskAngle * 7., ellipse * 23. - flowTime * .65)) * 8.), 3.);
    float turbulence = gas(vec2(diskAngle * 9. - flowTime * .9, ellipse * 48.));
    float beam = .42 + .9 * (1.0 - smoothstep(-.7, .6, p.x));
    float disk = diskMask * (.14 + filaments * .75 + turbulence * .42) * beam;
    // Far disk is occulted; the near side crosses in front of the shadow.
    disk *= mix(smoothstep(horizon - .006, horizon + .015, r), 1., smoothstep(-.012, .04, p.y));
    float lensRadius = length(vec2(p.x, p.y / (p.y < 0. ? 1.0 : .77)));
    float lensTexture = .56 + .44 * gas(vec2(angle * 11. - flowTime * .65, lensRadius * 95.));
    float lens = exp(-abs(lensRadius - .315) * 80.) * lensTexture;
    lens += exp(-abs(lensRadius - .34) * 42.) * .23 * lensTexture;
    float photon = exp(-abs(r - (horizon + .003)) * mix(440., 300., rush));
    // A luminous head traces the ring, then hands off to the full disk.
    float azimuth = fract((angle + 1.5707963) / 6.2831853);
    float arcReveal = 1.0 - smoothstep(sweep, sweep + .055, azimuth);
    float ringHead = exp(-abs(azimuth - sweep) * 65.)
        * (1.0 - smoothstep(.40, .55, opening));
    photon *= arcReveal * born;
    photon += exp(-abs(r - (horizon + .003)) * 160.) * ringHead * born * .7;
    lens *= smoothstep(.13, .57, opening) * arcReveal;
    // Ignition runs from the inner rim to the outer disk, not a global fade.
    float diskFront = mix(.29, 1.08, ignition);
    float ignitionHead = exp(-abs(ellipse - diskFront) * 42.)
        * sin(ignition * 3.14159265) * diskMask;
    disk *= (1.0 - smoothstep(diskFront - .05, diskFront + .05, ellipse))
        * smoothstep(.17, .35, opening);
    disk += ignitionHead * .65;
    disk *= 1.0 - smoothstep(.52, .94, collapse);
    float aura = exp(-abs(r - .33) * 13.) * .12;
    aura *= smoothstep(.28, .32, r);
    float equator = exp(-abs(p.y) * 115.) * exp(-abs(p.x) * 1.8) * .27
        * (1.0 - smoothstep(.45, .78, collapse));
    float capture = rush * exp(-abs(r - .30) * 45.) * .42;
    vec3 violet = primary.rgb;
    vec3 ice = mix(secondary.rgb, vec3(.66, .86, 1.), .65);
    vec3 hot = mix(vec3(1., .91, .81), primary.rgb, .18);
    vec3 light = mix(violet, ice, (1.0 - smoothstep(-.65, .65, p.x))) * (disk * .78 + lens * .9 + aura * born + capture);
    light += hot * (pow(max(disk, 0.), 2.) * .36 + photon * .76 + equator * ignition);
    // Uneven streams break up the mechanical spoke pattern. Light moves
    // inward along fixed bent paths; the disk itself never rotates.
    float formation = smoothstep(.015, .13, opening)
        * (1.0 - smoothstep(.37, .75, opening));
    float streamPhase = angle * 11. + log(max(r, .02)) * 17.;
    float filamentNoise = gas(vec2(angle * 1.5, r * 2.));
    float spiral = pow(max(0., cos(streamPhase + filamentNoise * .9)), 28.);
    float packet = pow(max(0., cos(r * 16. + opening * 29. + collapse * 32.
        + sin(angle * 4.) * 2.)), 10.);
    float envelope = (formation * .36 + rush * .62 * (1.0 - smoothstep(.52, .9, collapse)))
        * smoothstep(horizon, horizon + .055, r) * (1.0 - smoothstep(.76, 1.02, r));
    light += mix(violet, ice, filamentNoise) * spiral * packet * envelope;
    // A plane-aligned ignition bloom replaces the detached circular ripple.
    float ignitionPulse = sin(ignition * 3.14159265);
    float glint = exp(-abs(p.y) * 95.) * exp(-abs(p.x) * 4.2);
    light += hot * glint * (ignitionPulse * .30 + sin(drain * 3.14159265) * .48);
    light += ice * exp(-abs(r - .31) * 20.) * rush * .15;
    light *= 1.0 + energy * .45 + shock * .6;
    light *= mix(born, 1.0, smoothstep(.14, .30, opening));
    light = mix(light, light / (1.0 + light * .6), rush * .6);
    float shadow = (1. - smoothstep(horizon - .008, horizon, r)) * .995 * born;
    float alpha = clamp(max(max(light.r, light.g), light.b) + shadow, 0., 1.);
    vec3 color = light + coreColor.rgb * shadow;
    // Premultiplied output keeps the void opaque and the outer emission soft.
    fragColor = vec4(min(color, vec3(alpha)), alpha) * qt_Opacity;
}
