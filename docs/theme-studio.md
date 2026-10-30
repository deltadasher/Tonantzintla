# Theme studio

Open **Settings → Appearance → Theme studio** for global colors and Ephemeris. Open **Bar Studio → Appearance** for bar finish, corners, edges, workspace indicators and clock faces. Changes apply immediately and save with the other appearance preferences.

- **Colors:** Automatic, Light or Dark; an exact theme color field; and an optional separate action color. Any valid six-digit hex is allowed, including black and white. An explicitly chosen theme color stays exact as the main accent; Matugen generates the supporting palette. A separate exact action color takes precedence over it. Automatic uses that color, or the chosen source when there is no override, to select light or dark. Without either explicit color it retains dark mode. Text on selected controls independently chooses black or white for contrast. Color transitions are finite and respect reduced motion.
- **Materials:** Ephemeris finishes; the independent Aperture finish is in Bar Studio. Classic preserves the ordinary backing; Ephemeris also retains Gravity. Frosted and Liquid glass sample a bounded wallpaper still, with adjustable frost, refraction, tint and instrument density. They do not capture application windows. Video or missing-wallpaper paths and software rendering use a solid fallback with an explanation in the studio.
- **Bar Studio → Appearance:** square, soft, round or capsule corners; quiet, hairline or accent edges; numbered, pill, dot or track workspace indicators; and a matrix clock alongside the existing faces. Occupied, urgent and active workspaces remain distinct, with stationary keyboard-accessible targets.

**Prism**, **Porcelain** and **Ink** apply material/appearance presets without changing wallpaper, source color, fonts or bar arrangement. Independent per-instrument overrides in current source still take precedence over the global Ephemeris finish.

Glass uses one bounded cached image per URL/size in Qt's image cache, direct shader draws, fixed texture reads and no frame timer, screen capture, extra daemon or polling loop. Closing a surface releases its shader/image loaders. Matrix digits use the existing clock and introduce no additional clock service. These are design/lifecycle properties, not a performance benchmark.

Palette generation uses Matugen's dry-run JSON output for the shell. It does not rewrite external application themes. Cache identity includes light/dark mode, source and seed. Failed or superseded jobs cannot commit a new source color.

The current owner request explicitly permits optional glass instrument backings, superseding the older opaque-only recommendation in the dated surface audit. Classic remains available. Parallax retains its open orbit; no desktop background widgets or telemetry are added.

## Visual research

Serpantinum's [configuration reference](https://serpantinum.dev/configure/) documents light/dark Matugen generation, corner radius, workspace faces, clock faces and bar composition. The local Serpantinum visual index separately records pinned LiquidGlass, lens, fillet and media implementations. This implementation borrows mechanisms and uses original QML/shader work; it does not copy upstream branding or claim complete visual parity.

Other indexed mechanisms remain distinct: existing Tonantzintla control lenses and elastic toggles were not counted as new; joined fillets, arbitrary nested bar groups, a Pac-Man workspace face and additional media effects were not implemented in this pass.

## Liquid glass correction

The first backing was too opaque and its edge model was too shallow. The [source-driven correction](liquid-glass-correction.md) adds curved-surface refraction, local-pixel frost, color dispersion and angle-dependent reflections while preserving the bounded wallpaper source and fallback. It includes the pinned upstream evidence and GPU verification scope.
