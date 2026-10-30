# Liquid glass correction — October 29, 2026

The first Tonantzintla material did not reproduce the important optical mechanisms. At the user's bar opacity of 75%, its shader painted 75% backing color over the wallpaper; the instrument default painted 82%. Frost was measured as a fraction of the entire wallpaper, and the edge had a small two-dimensional displacement and a thin outline. Calling this equivalent to Serpantinum's liquid glass overstated the result.

## Source examined

The official repository was resolved again on October 29. These references use the newly inspected revision, separately from the older visual index pin:

- [LiquidGlass.qml](https://github.com/ilyamiro/serpantinum/blob/a62f82500a68f8c6026309dcf035bab347ec5ff0/src/quickshell/reusables/display/LiquidGlass.qml): material uniforms, shape and interaction inputs.
- [liquid_glass.frag](https://github.com/ilyamiro/serpantinum/blob/a62f82500a68f8c6026309dcf035bab347ec5ff0/src/assets/shaders/effects/liquid_glass.frag): curved surface normals, Snell refraction, dispersion, local frost, Fresnel reflection and edge lighting.
- [WallpaperBlur.qml](https://github.com/ilyamiro/serpantinum/blob/a62f82500a68f8c6026309dcf035bab347ec5ff0/src/quickshell/reusables/display/WallpaperBlur.qml): wallpaper source, sampling geometry, shared sources and video snapshots.

An isolated GPU comparison rendered that upstream wrapper/shader, with only its import, default tint and shader URL adapted for the fixture. It was not a running Serpantinum desktop. Upstream reference files remain in the local research directory, outside the Tonantzintla product. The replacement product shader is independently authored; no upstream implementation is copied into the product.

## Correction

| Mechanism | Tonantzintla correction |
| --- | --- |
| Curved glass edge | Rounded-box distance field produces a continuous three-dimensional bevel normal; refraction uses the incident ray and refractive index. |
| Clear interior | Lower absorption preserves wallpaper detail. Density still changes absorption; light mode uses a brighter backing for dark foreground text. |
| Frost | Fixed taps sample a small radius in logical screen pixels, with mipmapped filtering. Frosted retains stronger blur and backing. |
| Color separation | Separate red and blue refraction samples at the bevel. |
| Reflection | View-angle reflectance samples a nearby wallpaper region; broad directional highlights, a narrow lip and an inner meniscus provide edge depth. |
| Pointer response | A passive hover handler drives a small local deformation and light response. It consumes no button presses. The finite transition respects reduced motion. |
| Lifecycle | Bounded 1024 × 1024 image request, Qt image cache, no recurring frame timer, no screen capture or additional service; hidden surfaces unload. |

Both implementations sample wallpaper, not application windows. Tonantzintla still uses a still wallpaper only; its video path retains the explicit solid fallback. The upstream video snapshot, nested clear layers, fillet joins and shape morphing are separate mechanisms, not implemented by this correction.

## Build

The source and baked shader ship together. This shader uses mip levels and texture-size queries, with modern OpenGL/ES variants plus Vulkan, HLSL and Metal representations:

```sh
/usr/lib/qt6/bin/qsb --glsl '150,300 es,330' --hlsl 50 --msl 12 -o liquid-surface.frag.qsb liquid-surface.frag
```

Unsupported shader/backend combinations retain the existing solid fallback. The shader path was rendered on this host's GPU; other backend variants were compiled, not run on hardware.

## Verification

- Reproduced the original opaque appearance in an actual GPU baseline and compared it with the pinned upstream shader.
- Rendered and visually inspected the corrected reference comparison at bar and panel sizes.
- Ran the actual LiquidSurface component against current canonical and installed-payload snapshots in dark/light modes: four GPU cases and four software cases, all passed.
- Those cases check shader activation/fallback, independent frosted/classic paths, clicks through the passive handler, video fallback, still restoration and hidden-surface unloading. Real component screenshots were inspected in both color modes.
- GPU cases were repeated with motion enabled so the handler was active during click checks. These checks establish component behavior, not an end-user performance benchmark or complete visual parity.

Reproduction scripts and logs: `work/glass-correction/` in the task workspace. User preferences were isolated during these checks.
