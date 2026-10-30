#version 440
// Tonantzintla glass: an analytic curved interface over a bounded wallpaper still.
// Original implementation. Optical mechanisms reviewed against Serpantinum's
// LiquidGlass/WallpaperBlur; see docs/liquid-glass-correction.md for provenance.
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 viewport;
    vec2 fieldSize;
    vec2 fieldOrigin;
    vec2 cropScale;
    float cornerRadius;
    float strength;
    float frostAmount;
    float pigment;
    float density;
    float lightMode;
    float hoverAmount;
    vec2 pointerPosition;
    float liquid;
    vec4 tint;
    vec4 backing;
} u;
layout(binding=1) uniform sampler2D wallpaper;

float boundary(vec2 point, vec2 extent, float radius) {
    vec2 delta=abs(point)-extent+radius;
    return length(max(delta,0.))+min(max(delta.x,delta.y),0.)-radius;
}
vec2 fieldUv(vec2 pixel) {
    return clamp(((u.fieldOrigin+pixel)/u.fieldSize-.5)*u.cropScale+.5,vec2(.001),vec2(.999));
}
vec3 readField(vec2 pixel,float level) {
    return textureLod(wallpaper,fieldUv(pixel),level).rgb;
}
vec3 soften(vec2 pixel,float radius) {
    // Filter in screen pixels, not a percentage of the complete wallpaper.
    vec2 texelRatio=vec2(textureSize(wallpaper,0))*u.cropScale/u.fieldSize;
    float level=max(0.,log2(max(1.,radius*max(texelRatio.x,texelRatio.y)*.6)));
    vec3 sum=readField(pixel,level)*.28;
    for(int tap=0;tap<8;tap++) {
        float angle=float(tap)*.7853981634;
        sum+=readField(pixel+vec2(cos(angle),sin(angle))*radius,level)*.09;
    }
    return sum;
}
vec2 transmit(vec3 normal,float index,float depth) {
    vec3 ray=refract(vec3(0.,0.,-1.),normal,1./index);
    return ray.xy*depth/max(.22,-ray.z);
}
void main() {
    vec2 size=max(u.viewport,vec2(1.));
    vec2 pixel=qt_TexCoord0*size;
    vec2 p=pixel-size*.5;
    float radius=clamp(u.cornerRadius,0.,min(size.x,size.y)*.5);
    float distance=boundary(p,size*.5,radius);
    float coverage=1.-smoothstep(-.7,.5,distance);
    if(coverage<.001){fragColor=vec4(0.);return;}

    float inside=max(0.,-distance);
    float bezel=clamp(min(size.x,size.y)*.34,7.,25.);
    // Central differences give one continuous normal through corners and edges.
    vec2 dx=vec2(.6,0.);
    vec2 gradient=vec2(boundary(p+dx,size*.5,radius)-boundary(p-dx,size*.5,radius),
                       boundary(p+dx.yx,size*.5,radius)-boundary(p-dx.yx,size*.5,radius));
    vec2 outward=gradient/max(length(gradient),.001);
    float shoulder=clamp(1.-inside/bezel,0.,1.);
    float slope=min(6.,shoulder/sqrt(max(.025,1.-shoulder*shoulder)));
    vec2 pointerDelta=u.pointerPosition-pixel;
    float reach=clamp(min(size.x,size.y)*.7,35.,130.);
    float proximity=exp(-dot(pointerDelta,pointerDelta)/(reach*reach))*u.hoverAmount;
    vec2 dent=pointerDelta/ reach *proximity*.12*u.liquid;
    vec3 normal=normalize(vec3(outward*slope*u.liquid-dent,1.));
    float thickness=bezel*(.65+u.strength*1.1);
    float index=1.3+u.strength*.24;
    vec2 bend=transmit(normal,index,thickness)*u.liquid;

    // A shallow interior lens is visible on capsules without distorting large text panels.
    float smallLens=1.-smoothstep(320.,800.,max(size.x,size.y));
    vec2 unit=p/(size*.5);
    float center=max(0.,1.-dot(unit,unit)*.5);
    vec2 samplePixel=pixel-p*(.025+.045*u.strength)*center*smallLens*u.liquid+bend;
    float softRadius=mix(5.+u.frostAmount*15.,.35+u.frostAmount*2.8,u.liquid);
    softRadius*=mix(.45,1.,smoothstep(0.,bezel,inside));
    vec3 field=soften(samplePixel,softRadius);
    if(u.liquid>.5 && shoulder>.01) {
        vec2 redBend=transmit(normal,index+.022,thickness);
        vec2 blueBend=transmit(normal,index-.022,thickness);
        field.r=readField(samplePixel+redBend-bend,0.).r;
        field.b=readField(samplePixel+blueBend-bend,0.).b;
    }

    float luminance=dot(field,vec3(.2126,.7152,.0722));
    field=mix(vec3(luminance),field,1.08);
    // Glass density controls absorption, not a nearly opaque paint layer.
    float clearAbsorption=mix(.04+.20*u.density,.24+.30*u.density,u.lightMode);
    float absorption=mix(.45+.35*u.density,clearAbsorption,u.liquid);
    vec3 color=mix(field,u.backing.rgb,absorption);
    color=mix(color,u.tint.rgb,clamp(u.pigment,0.,1.)*.16);

    vec2 light=normalize(mix(vec2(-.7,-1.),pointerDelta/max(length(pointerDelta),1.),u.hoverAmount*.25));
    float facing=dot(outward,light);
    float f0=pow((index-1.)/(index+1.),2.);
    float fresnel=f0+(1.-f0)*pow(1.-normal.z,4.);
    vec3 reflection=readField(pixel+outward*bezel*1.7,1.);
    color=mix(color,reflection*1.1+.025,clamp(fresnel*.5,0.,.55)*u.liquid);
    float highlight=pow(max(0.,facing),3.)+.35*pow(max(0.,-facing),5.);
    float lip=exp(-inside/1.2)*(.06+.30*highlight);
    float broad=exp(-inside/(bezel*.6))*.13*highlight;
    float meniscus=exp(-pow((inside-bezel*.68)/(bezel*.16+1.),2.))*.045*highlight;
    color+=vec3(lip+broad+meniscus)*mix(.25,1.,u.liquid)*(1.+.35*proximity);
    color*=1.-.11*shoulder*max(0.,-facing)*u.liquid;
    fragColor=vec4(clamp(color,0.,1.)*coverage,coverage)*u.qt_Opacity;
}
