# Umbra accretion renderer

`accretion.frag` is an original analytic emission shader: a fixed inclined disk,
advected turbulent filaments, a central shadow and approximate lensing arcs.
It is a stylized renderer, not a physical ray tracer. Theme colors and the existing
Umbra authentication state drive its uniforms. Updates stop while hidden or when
motion is disabled. No external textures or per-frame Canvas uploads are needed.

Rebuild the bundled Qt 6 shader after editing the GLSL:

```sh
/usr/lib/qt6/bin/qsb --glsl '100 es,120,150' --hlsl 50 --msl 12 \
  -o accretion.frag.qsb accretion.frag
```

`accretion-fallback.png` is a transparent 1024px capture of this shader at time zero.
It provides a static image for the Qt Quick software backend or shader errors.
The GPU renderer stays active but stationary under reduced motion, retaining the
current theme colors. The static fallback uses the colors of the captured theme.

The opening is driven by `UmbraSurface.intro`, a 2200ms linear timeline. The shader
forms the shadow, traces the photon ring, advects temporary inward streams, and
ignites the disk from its inner edge. Text and controls use separate smooth reveal
windows on the same timeline. The settled shader output is unchanged at opening=1.
Reduced motion immediately completes the timeline, including when changed mid-open.
The password path becomes visible immediately on typing; authentication is never
delayed by the entrance. Closing cancels the timeline; reopening restarts it.

Unlocking uses a separate 1380ms linear timeline with quintic presentation curves:
disk compression, accelerated emission, interface recession, and a horizon plunge.
The authenticated 1460ms release deadline and PAM success path are unchanged.
Repeated submissions cannot restart capture; early submission completes entrance.

`aperture.frag` / `aperture.frag.qsb` power the shared `UmbraAperture.qml` handoff.
Compile with the same qsb arguments above. The preview creates an alpha-capable
window from the start and remains mounted through the 880ms handoff. Its completion
signal is preview-only and never releases a real lock. The real reveal retains its
existing 1510ms synchronization delay. Software rendering uses a bounded Canvas
mask; reduced motion skips the handoff.
