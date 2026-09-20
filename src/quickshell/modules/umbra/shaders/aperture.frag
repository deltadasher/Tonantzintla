#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    vec2 viewport;
    vec4 primary;
    vec4 secondary;
    vec4 backing;
};
void main() {
    if (progress >= .9999) { fragColor = vec4(0); return; }
    float t = progress * progress * progress * (progress * (progress * 6. - 15.) + 10.);
    float aspect = viewport.x / max(viewport.y, 1.);
    vec2 p = (qt_TexCoord0 - .5) * vec2(aspect, 1.);
    float angle = atan(p.y,p.x);
    float extent = length(vec2(aspect,1.)) * .5;
    float radius = mix(-.025, extent * 1.12, t);
    float travel = sin(progress * 3.14159265);
    float bend = sin(angle * 3. + progress * 5.) * .004 * travel;
    float distance = length(p * vec2(1., 1. + .14 * (1. - t))) - radius + bend;
    float feather = 1.5 / max(viewport.y,1.) + travel * .004;
    float cover = smoothstep(-feather,feather,distance);
    float rim = exp(-abs(distance) * 650.) * .8;
    float halo = exp(-abs(distance) * 80.) * .22;
    float wake = exp(-abs(distance - .016 * travel) * 240.) * .12;
    float beam = .45 + .55 * pow(.5 + .5 * cos(angle + .7), 3.);
    float fade = smoothstep(0.,.12,progress) * (1. - smoothstep(.75,1.,progress));
    vec3 tint = mix(primary.rgb, secondary.rgb, .5 + .5 * cos(angle - .5));
    vec3 light = (tint * (halo + wake) + mix(tint,vec3(1.,.94,.86),.7) * rim) * beam * fade;
    float alpha = clamp(cover + max(light.r,max(light.g,light.b)),0.,1.);
    fragColor = vec4(min(backing.rgb * cover + light,vec3(alpha)),alpha) * qt_Opacity;
}
