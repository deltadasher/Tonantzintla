#version 440
// Direct Image textures; no scene capture or render-to-texture transition.
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 oldCrop;
    vec2 newCrop;
    vec2 dimensions;
    float amount;
    float mode;
} u;
layout(binding=1) uniform sampler2D oldImage;
layout(binding=2) uniform sampler2D newImage;
void main() {
    vec2 uv=qt_TexCoord0;
    vec4 oldColor=texture(oldImage,(uv-.5)*u.oldCrop+.5);
    vec4 newColor=texture(newImage,(uv-.5)*u.newCrop+.5);
    float p=clamp(u.amount,0.,1.);
    float blend=p;
    vec2 aspect=u.dimensions/max(u.dimensions.x,u.dimensions.y);
    vec2 point=(uv-.5)*aspect;
    float radius=length(point);
    float farthest=length(aspect*.5);
    if (u.mode>.5 && u.mode<1.5)
        blend=1.-smoothstep(p*(farthest+.06)-.03,p*(farthest+.06)+.03,radius);
    else if (u.mode>1.5 && u.mode<2.5)
        blend=1.-smoothstep(p*1.12-.06,p*1.12+.06,uv.x);
    else if (u.mode>2.5) {
        // Finite orbit-shaped reveal; the image itself never rotates or distorts.
        float angle=atan(point.y,point.x);
        float edge=p*(farthest+.10)+.025*sin(angle*2.-p*6.2831853)*sin(p*3.14159265);
        blend=1.-smoothstep(edge-.035,edge+.035,radius);
    }
    if (p<=0.) blend=0.;
    if (p>=1.) blend=1.;
    vec4 color=mix(oldColor,newColor,blend);
    // Wallpaper is a solid backing even if the prepared still contains alpha.
    fragColor=vec4(color.rgb,1.)*u.qt_Opacity;
}
