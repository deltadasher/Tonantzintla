#version 440
// Independently authored bounded wallpaper optics. No screen capture or time input.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 viewport;
    vec2 sampleOrigin;
    vec2 sampleBasisX;
    vec2 sampleBasisY;
    vec2 cropScale;
    float cornerRadius;
    float strength;
    float frost;
    float dispersion;
    float hoverLight;
    float pressLight;
    float fillOpacity;
    vec4 tint;
    vec4 backing;
} ubuf;
layout(binding = 1) uniform sampler2D wallpaper;
vec3 readField(vec2 uv) { return texture(wallpaper, clamp(uv, vec2(.002), vec2(.998))).rgb; }
void main() {
    vec2 size = max(ubuf.viewport, vec2(1.));
    vec2 p = (qt_TexCoord0 - .5) * size;
    float r = clamp(ubuf.cornerRadius, 0., min(size.x, size.y) * .5);
    vec2 q = abs(p) - size * .5 + r;
    float distance = length(max(q, vec2(0.))) + min(max(q.x,q.y),0.) - r;
    float coverage = 1. - smoothstep(-.8,.4,distance);
    if (coverage <= .001) { fragColor = vec4(0.); return; }
    vec2 cornerNormal = normalize(max(q, vec2(0.)) + vec2(.001)) * sign(p);
    vec2 flatNormal = abs(q.x) < abs(q.y) ? vec2(sign(p.x),0.) : vec2(0.,sign(p.y));
    vec2 normal = any(greaterThan(q,vec2(0.))) ? cornerNormal : flatNormal;
    float edge = exp(min(distance,0.) / 7.);
    float motion = .65 + .25 * ubuf.hoverLight + .35 * ubuf.pressLight;
    vec2 warped = qt_TexCoord0 - normal * edge * ubuf.strength * motion * 9. / size;
    // A small inward lens changes on hover/press; the owner's hit target never moves.
    warped = .5 + (warped - .5) * (1. - ubuf.strength * (.025 + .025 * ubuf.hoverLight - .02 * ubuf.pressLight));
    vec2 uv = (ubuf.sampleOrigin + warped.x * ubuf.sampleBasisX + warped.y * ubuf.sampleBasisY - .5) * ubuf.cropScale + .5;
    vec2 chroma = normal * edge * ubuf.dispersion * ubuf.strength * .007;
    vec3 color = vec3(readField(uv + chroma).r, readField(uv).g, readField(uv - chroma).b);
    // Fixed five-point softening, constant work, no blur framebuffer pyramid.
    vec2 soft = vec2(.006) * clamp(ubuf.frost,0.,1.);
    vec3 diffuse = (readField(uv + vec2(soft.x,0.)) + readField(uv - vec2(soft.x,0.))
                  + readField(uv + vec2(0.,soft.y)) + readField(uv - vec2(0.,soft.y))) * .25;
    color = mix(color, diffuse, clamp(ubuf.frost,0.,1.));
    color = mix(ubuf.backing.rgb, color, .36);
    color = mix(color, ubuf.tint.rgb, .08);
    float facing = dot(normal, normalize(vec2(-.6,-1.)));
    float fresnel = pow(edge, 2.) * (.08 + .12 * max(0.,facing));
    float glint = exp(-pow((distance + 1.6) / 1.1, 2.)) * max(0.,facing) * .22;
    color += vec3(fresnel + glint) * (.5 + .5 * ubuf.strength);
    color *= 1. - .13 * edge * max(0.,-facing);
    float alpha = coverage * clamp(ubuf.fillOpacity,0.,1.) * (.44 + .1 * ubuf.hoverLight);
    fragColor = vec4(color * alpha, alpha) * ubuf.qt_Opacity;
}
