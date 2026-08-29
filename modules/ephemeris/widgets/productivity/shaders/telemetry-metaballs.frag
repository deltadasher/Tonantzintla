#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 fieldSize;
    vec4 balls12;
    vec4 ball3Radii;
    vec4 color1;
    vec4 color2;
    vec4 color3;
    float phase;
    float distortion;
};

float influence(vec2 point, vec2 center, float radius) {
    vec2 delta = point - center;
    return radius * radius / max(dot(delta, delta), 0.75);
}

void main() {
    vec2 point = qt_TexCoord0 * fieldSize;
    float wave = distortion * 5.5;
    point.x += sin(point.y * 0.035 + phase) * wave;
    point.y += sin(point.x * 0.029 - phase * 1.31) * wave * 0.72;

    vec2 center1 = balls12.xy * fieldSize;
    vec2 center2 = balls12.zw * fieldSize;
    vec2 center3 = ball3Radii.xy * fieldSize;
    float field1 = influence(point, center1, ball3Radii.z);
    float field2 = influence(point, center2, ball3Radii.w);
    float field3 = influence(point, center3, ball3Radii.z * 0.93);
    float field = field1 + field2 + field3;

    float coverage = smoothstep(0.91, 1.08, field);
    float rim = smoothstep(0.93, 1.02, field) - smoothstep(1.12, 1.34, field);
    vec3 mixed = (color1.rgb * field1 + color2.rgb * field2 + color3.rgb * field3)
        / max(field, 0.001);
    mixed = mix(mixed, vec3(1.0), rim * 0.13);

    float alpha = coverage * qt_Opacity;
    fragColor = vec4(mixed * alpha, alpha);
}
