#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 viewport;
    vec2 panelSize;
    float cornerRadius;
    float reveal;
    float activity;
    vec4 primary;
    vec4 secondary;
    vec4 backing;
};

float roundBox(vec2 p, vec2 halfSize, float radius) {
    vec2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}
void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * viewport;
    float radius = min(cornerRadius, min(panelSize.x, panelSize.y) * 0.5);
    float d = roundBox(p, panelSize * 0.5, radius);
    // Most panel pixels only need an opaque fill. Optical work is confined to
    // the narrow edge field, irrespective of panel size or display resolution.
    if (d < -3.0) {
        fragColor = vec4(backing.rgb, 1.0) * qt_Opacity;
        return;
    }
    float aa = max(fwidth(d), 0.7);
    float inside = 1.0 - smoothstep(-aa, aa, d);
    vec2 n = p / max(panelSize * 0.5, vec2(1.0));
    float angle = atan(n.y, n.x);
    float motion = clamp(activity, 0.0, 1.0);
    // A moving caustic bends six contour paths around the surface. Nothing
    // rotates the controls or samples/refracts another application's pixels.
    float focusAngle = -2.5 + reveal * 5.8;
    float focus = pow(0.5 + 0.5 * cos(angle - focusAngle), 12.0);
    float bend = sin(angle * 2.0 + reveal * 3.0) * (1.6 + motion * 12.0);
    float capture = pow(0.5 + 0.5 * cos(angle - focusAngle), 3.0);
    float field = 0.0;
    for (int i = 0; i < 6; ++i) {
        float lane = float(i);
        float distanceToRay = d - (5.0 + lane * (3.2 + motion * 3.8))
            - bend * (0.35 + lane * 0.15);
        float ray = exp(-abs(distanceToRay) * (1.6 - lane * 0.1));
        float travel = 0.35 + 0.65 * pow(0.5 + 0.5 * cos(angle * 2.0 - lane * 0.4 - reveal * 8.0), 4.0);
        field += ray * travel * (1.0 - lane * 0.12) * (0.35 + capture * 1.5);
    }
    field *= (0.07 + motion * 1.15) * smoothstep(1.0, 4.0, d);
    field *= 1.0 - smoothstep(48.0, 70.0, d);
    float rim = exp(-abs(d) * 1.7) * (0.28 + focus * (0.35 + motion));
    float glow = exp(-abs(d - 2.0) * 0.17) * (0.025 + motion * 0.13);
    vec3 cold = mix(primary.rgb, secondary.rgb, 0.55 + 0.35 * sin(angle + 0.4));
    vec3 hot = mix(vec3(1.0, 0.91, 0.77), primary.rgb, 0.24);
    vec3 light = cold * (field + glow) + mix(cold, hot, focus) * rim;
    float lightAlpha = clamp(max(light.r, max(light.g, light.b)), 0.0, 0.95);
    // Premultiplied alpha keeps the solid interior and translucent rays correct.
    vec3 rgb = backing.rgb * inside + light * (1.0 - inside * 0.55);
    float alpha = inside + lightAlpha * (1.0 - inside);
    fragColor = vec4(min(rgb, vec3(alpha)), alpha) * qt_Opacity;
}
