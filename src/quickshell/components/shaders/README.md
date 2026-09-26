# Gravity panel material

A procedural signed-distance edge field drawn directly by Qt Quick ShaderEffect.
This is an artistic approximation, not a ray-traced gravitational simulation and
not refraction of application windows. Six curved light paths collect into a
moving caustic as the existing panel geometry opens; they settle to a static rim.

Build with Qt 6 Shader Tools:

```sh
/usr/lib/qt6/bin/qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 -o gravity.frag.qsb gravity.frag
```

The source and baked shader are shipped together. No sampler, captured desktop,
ShaderEffectSource, offscreen layer, framebuffer pyramid, or private animation
clock is used. The quad extends 72 logical pixels around the current panel and
is clipped to Ephemeris's Aperture-safe viewport. Interior pixels take an early
opaque-fill path. Shader/driver memory and the existing window buffers still
cost memory; this is not a zero-VRAM claim.

Activity comes from SurfaceTransition. Reduced motion removes the sweep. Hidden
panels unload the material; settled panels do not schedule their own frames.
Software rendering or a shader error retains InstrumentBridge. Classic is also
available under Settings → Appearance → Panel material. The environment override
TONANTZINTLA_DISABLE_GRAVITY=1 prevents loading the material.

The software host uses rectangular content clipping because Quickshell’s rounded
mask also needs a shader. Rounded containment remains in use on the GPU.
