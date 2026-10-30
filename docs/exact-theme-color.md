# Exact theme color and Wabi Sabi mark — October 29, 2026

The black region of the Wabi Sabi mark is a fixed part of its identity. Several call sites replaced it with Theme.void_ or Theme.mantle, making the center white in light mode. All those overrides are removed in source and the installed payload. The shared component now exposes a read-only black horizon. The colored stream still follows its existing accent/module color, and existing fade animations still apply to the whole mark.

Matugen was receiving the exact requested hex. Its tonal-spot primary is a generated tone rather than that source color: installed Matugen 4.2.0 returns dark primary #deb9f7 for source #170823, and #cbbeff for the user's source #564697. The official [usage reference](https://github.com/InioX/matugen/wiki/Usage) also distinguishes source_color from primary.

Tonantzintla now adapts the returned palette for explicit choices: primary keeps the chosen RGB exactly, on_primary selects contrasting black or white, and the supporting palette remains Matugen-generated. Automatic wallpaper extraction retains the generated primary. Preview swatches use the same adaptation. Existing seeded palette caches are adapted when read; preview cache identity is updated. No external application theme files or Matugen configuration are rewritten.

The Theme studio field is now called **Theme color**, and its description explains exact accent behavior. The separate **Exact action color** override remains optional and takes precedence. Light/dark automatic selection, stale-job rejection, failure recovery and reduced-motion behavior remain in place.

Verification: real Matugen tests cover dark/light with #170823, #564697, black and white; cached palettes and previews are covered. Native tests assert actual Theme.accent values without needing a separate spectral override and preserve explicit-override precedence. The actual launcher/dock marks were rendered and checked in light/dark on both software and the host GPU. These are targeted checks, not a complete shell regression or authentication test.

Next visual proposals, not implemented by this correction:

1. **Per-island styling:** independent material, tint and outline for the clock, workspaces or media island; easy return to inherited styling.
2. **Joined bar groups:** one silhouette around selected neighbors, with optional separators and sensible keyboard targets. Study one joined/filleted attachment before a general shape renderer.
3. **Glass edge controls:** rim width, highlight strength and chromatic edge strength, separately from existing frost/refraction/tint.
4. **Workspace identity:** optional short names or symbols and active/urgent treatments alongside the existing orbit/pill/dot/track faces.
5. **Bar typography controls:** independent clock/icon/label scale and weight, with the existing global font system retained.

Bar-specific controls belong in Bar Studio. These options build on existing Aperture and on-demand instruments and do not introduce background widgets or idle decoration.
