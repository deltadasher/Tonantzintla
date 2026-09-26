# Visual identity audit: Tonantzintla, Serpantinum and Caelestia — 2026-09-26

A rendered mock of the proposal (HTML, not the running shell) accompanies this
document as a private artifact shared in the session that produced it.

This audit asks one question: where does Tonantzintla look like Serpantinum or
Caelestia, and what would make it look like nothing else? It updates the
[1.1 surface audit](visual-audit-1.1.md). That document covered usability. This
one covers identity.

Sections 1–3 are evidence. Sections 4–6 are design proposals, not approved
work. Per [AGENTS.md](../AGENTS.md), none of these observations authorizes
redesigning a working surface. Every proposal below needs an explicit go-ahead.

## 1. Evidence and limits

| Source | Revision | How it was examined |
| --- | --- | --- |
| Tonantzintla | `72137df` (this branch) | Source read and counted; the maintainer's 2026-09-12 recording stills in `docs/assets/` (bar, Settings, Parallax, Resonance, Umbra preview) |
| Serpantinum ([ilyamiro/serpantinum](https://github.com/ilyamiro/serpantinum)) | `40ae13a`, 2026-09-27 | Source read; its four README preview screenshots (1920×1080) viewed |
| Caelestia ([caelestia-dots/shell](https://github.com/caelestia-dots/shell)) | `20e625d`, 2026-09-20 | Source read (C++ config tokens, QML). Its README preview is a video on `user-attachments`, which this session's network scope rejected. **No Caelestia pixels were viewed.** |

None of the three shells was run. No QML was rendered. The Tonantzintla stills
are two weeks older than the procedural gravity material (`cd81970`), which
therefore appears in none of them. Counts below come from `grep` over
`src/quickshell` and are approximate.

Licenses: Tonantzintla is GPL-3.0, Caelestia GPL-3.0, Serpantinum
AGPL-3.0-or-later. Nothing in this audit copies upstream source.

## 2. What each upstream's visual signature is

**Serpantinum** (from its source and screenshots):

- Monospace everywhere. `ThemeBackend.fontFamily` defaults to Adwaita Mono. The
  bundle ships about 35 mostly Nerd/mono fonts, plus Iosevka Nerd Font for glyphs.
- A Catppuccin token vocabulary (`base`, `mantle`, `crust`, `surface0..2`,
  `mauve`…). It has 90+ bundled themes named after gemstones and editor themes,
  and a Matugen option.
- One global `borderRadius: 8`. Panels are flat, dark and rectangular. Selected
  list rows are a solid accent fill.
- Bar topology: launcher/workspaces/media pill with prev·play·next on the left.
  The centre has a `HH:MM:SS` clock with the date under it, plus weather. On the
  right, each status (network, headset, volume, battery) is its own solid,
  accent-coloured chip. Workspaces are dots, and the active one is a stretched pill.
- Desktop analog-clock and weather widgets, an equalizer popup, and sounds on
  most reusable controls.

**Caelestia** (from source only):

- Material 3 Expressive throughout. It uses the `m3primary` palette roles, rounding
  tokens of 4/8/12/16/20 up to `full`, M3 duration tokens (200/400/600) and
  expressive spatial curves that overshoot (`expressiveDefaultSpatial` =
  `0.38, 1.21, 0.22, 1`).
- Google Sans Flex for the UI, Rubik for the clock and workspaces, Material
  Symbols Rounded for icons, and CaskaydiaCove NF for mono.
- A screen border frame (thickness 10, rounding 25). Drawers emerge from it and
  are joined by `Caelestia.Blobs`, an SDF smooth-min union. Surfaces use
  translucent layers (`base 0.85`, `layers 0.4`) and compositor blur.
- A vertical left bar with a pill-shaped active workspace whose leading and
  trailing edges animate at different durations.

## 3. Findings: where Tonantzintla converges on them

| # | Dimension | Tonantzintla today | Converges on | Evidence |
| --- | --- | --- | --- | --- |
| F1 | Typography | Default profile "Observatory" sets text, display and mono all to JetBrains Mono (`Settings.qml:504-509`). The comment at `Settings.qml:429` still calls this "Serpantinum's visual voice". 235 of 427 `font.family` bindings use `fontMono`. | Serpantinum | The preset was renamed from `serpantinum` to `observatory`, but the fonts did not change. The recording's Settings still shows the preset as "SERP". |
| F2 | Letterforms | 76 all-caps string literals plus 48 `toUpperCase()` calls, letter-spaced mono (`CPU 9% MEM 30% GPU 64°`, `SEMITONES`, `MEMORY`). | Serpantinum / generic "HUD" | The [design guide](agent-design-guide.md) already asks to avoid meaningless uppercase telemetry. Serpantinum itself has about 6 such literals, so Tonantzintla is further down this road than its reference. |
| F3 | Bar topology | Launcher · workspaces · media pill with ‹ ▶ › │ centre `HH:MM:SS` + weather │ telemetry · status · tray · controls. | Serpantinum | Recording still vs. Serpantinum previews 2 and 4: same arrangement, clock format and weather placement. |
| F4 | Workspace indicator | `WorkspaceOrbit` is named after an orbit but is a stretched rounded pill. Its leading and trailing edges animate at 340/180 ms (`WorkspaceOrbit.qml:48`). | Caelestia (`ActiveIndicator.qml`), Serpantinum (dots + pill) | Same mechanism and silhouette. The code is independent. |
| F5 | Radii | Tokens are 8/13/20. There are about 25 distinct literal radii (4, 6, 7, 9, 10, 11, 12, 14, 24, 26…), with `width/2` circles the most common. | Caelestia's M3 scale (4–20) / Serpantinum's 8 | The generic "rounded rectangle plus circle" vocabulary. Nothing about the silhouette is specific to Tonantzintla. |
| F6 | Colour | A pastel lavender/cyan/rose accent set on blue-black (`#080910`, `#a99cff`). The adaptive mode maps Matugen M3 roles (`primary`, `surface_container_low`…). | Serpantinum (Catppuccin Mocha plus Matugen), Caelestia (M3 roles) | Both upstreams also generate from Matugen. The fallback violet sits close to Catppuccin `mauve` (`#cba6f7`). Tonantzintla even shares the token name `mantle`. |
| F7 | Motion | 50 `Easing.OutBack` and 77 `OutCubic`; no signature curve. | Caelestia's overshooting M3 Expressive curves | Overshoot bounce is the recognisable M3 Expressive gesture. |
| F8 | Joins | Opt-in `ExperimentalBlobBacking.qml` imports `Caelestia.Blobs` directly (env `TONANTZINTLA_BLOB_EXPERIMENT=1`). | Caelestia (literally its renderer) | Opt-in and GPL-compatible, but the visual is Caelestia's own signature. |
| F9 | Public names | The in-shell presets are now Expressive/Compact (`BarEditStudio.qml:578`), but `blackhole config preset` still advertises `serpantinum|caelestia` (`bin/blackhole:56, 218`). | Both | The public command describes Tonantzintla in terms of other projects. |
| F10 | Dead identity | `components/EccentricPlate.qml` promises an eccentric silhouette. It draws an ordinary rounded rectangle, and nothing instantiates it. | — | 0 consumers. |

### What is already genuinely Tonantzintla's

None of these has a counterpart in either upstream. Keep them, and use them as
the seed for everything else:

- **The Wabi-Sabi mark**: one imperfect gravitational stream around a displaced void.
- **Parallax's orbit**: wallpapers as bodies on an open orbit, not a grid.
- **Umbra**: the stacked-year lock composition and the ringed horizon with a sweeping arc.
- **The gravity material**: light paths bending around the panel edge
  (`components/shaders/gravity.frag`). It has not been seen in a recording yet.
- **Instrument names and semantic module channels** (`Theme.moduleAccent`), and
  the shared-instrument vocabulary (OrbitSeek, EventHorizon, WifiRadar, SolarTimeline).

**Diagnosis.** The unique work lives *inside* the instruments. The always-visible
layer (bar, typeface, radii, palette, easing, Settings chrome) is where a
visitor forms their first impression, and it is assembled from the same
conventions as the two references. A screenshot of the bar alone is hard to
tell from Serpantinum. Renaming presets did not change what they look like.

## 4. Proposal: one source for the identity — the Tonantzintla plate archive

This section is a proposal, not an implemented change.

The name already supplies a story neither upstream can use. The
[Tonantzintla Observatory](https://en.wikipedia.org/wiki/Tonantzintla_Observatory)
opened in 1942 around a 0.7 m Schmidt camera. Guillermo Haro used it to study
what are now called Herbig–Haro objects. Between 1948 and 1995 it produced about
15,000 direct and spectroscopic photographic plates, and UNESCO recognised them
in its Memory of the World programme
([INAOE](https://inaoep.mx/noticias/?anio=2013&noticia=82),
[La Jornada de Oriente](https://www.lajornadadeoriente.com.mx/puebla/unesco-reconocio-el-valor-historico-de-las-placas-astrofotograficas-de-la-camara-schmidt-de-tonantzintla/)).

So the visual language becomes **the observing plate**: silver-gelatin black,
spectral emission lines, the astronomer's annotation in the margin, and light
bent by mass. The black hole mark, Parallax and Umbra already fit this language.
The proposal extends it outward to the bar and chrome.

| Pillar | Proposal | Replaces | Why it cannot be mistaken for either upstream |
| --- | --- | --- | --- |
| **P1 Voice** | Three typefaces, each with one job. *Annotation*: an italic serif for instrument titles and large numerals (candidate: Instrument Serif, OFL). *Reading*: a humanist sans for labels and body (candidate: Atkinson Hyperlegible Next or IBM Plex Sans, OFL). *Measurement*: mono with tabular figures, **only** for numbers and units. Labels in sentence case. | F1, F2 | Serpantinum is all-mono; Caelestia is geometric Google Sans/Rubik. Neither uses a serif, and the result stops reading as a terminal HUD. |
| **P2 Plate silhouette** | Make `EccentricPlate` real, as a *source-aware* silhouette. The corner nearest the opening island is tight (about 4 px, where the plate is "held"). The far corners are wide (about 24 px). Two hairline fiducial marks sit outside the hit area. Qt 6.7+ `Rectangle.topLeftRadius`… handles the ordinary path. The gravity shader's `roundBox` takes a `vec4` of radii. A single `Theme.plate*` token set replaces the roughly 25 literal radii. | F5, F10 | Every panel shows where it came from. Symmetric M3 or 8 px rectangles cannot. |
| **P3 Spectral channels** | Bind module channels to named emission lines: Hβ 486 nm, [O III] 501 nm, Na D 589 nm, Hα 656 nm, [S II] 672 nm. Neutrals shift from blue-black to silver-gelatin (a warm, near-neutral black; `moon #eee9dc` already fits). The adaptive mode keeps Matugen for tone, then **snaps the accent hue to the nearest line**, so wallpapers tint the shell without leaving its palette. | F6 | Both upstreams expose raw Matugen or M3 roles. A snapped spectral set is a palette with rules of its own. |
| **P4 Keplerian motion** | One easing token derived from Kepler's equation: the fraction of true anomaly from periapsis to apoapsis for e = 0.5. Its cubic fit is `[0.2, 0.9, 0.85, 0.9, 1, 1]` (fitted in this audit). The token decelerates without overshoot. Surfaces travel a short conic arc from their anchor instead of a straight scale. `OutBack` is retired from surface geometry. | F7 | Caelestia's signature is overshoot. This is physically motivated deceleration with no bounce. |
| **P5 Tether, not blob** | Connect island to instrument with a thin, curved light stream drawn in the logo's stream geometry. It shares the gravity material's light, and blob merging is removed. Retire `ExperimentalBlobBacking` (a `Caelestia.Blobs` import) once the tether exists. | F8 | Blob merging is Caelestia's most recognisable trait. A stream of light is Tonantzintla's own mark in motion. |
| **P6 Aperture as a transit** | Workspaces become bodies on a hairline track. The active one is an open ring (an aperture), not a filled pill, and it moves with the P4 timing. Occupied workspaces show as small satellites. Telemetry stays quiet until it is notable: a single seeing-style meter that names the metric in sentence case when it crosses a threshold, with full values on hover. The clock drops seconds by default. | F3, F4, F2 | This breaks the Serpantinum bar topology and the dots-plus-pill idiom shared by both references. |
| **P7 Names** | `blackhole config preset` advertises `expressive|compact|solaris|cyberpunk|minimalist`. `serpantinum`/`caelestia` remain silent aliases so existing scripts keep working. The code comment at `Settings.qml:429` is replaced. | F9 | The public command stops describing the project through others. |

What stays exactly as is: the real logo, Parallax's orbit, expressive morphing,
solid instrument backgrounds with translucent controls, Resonance's rounded
clipping, and the absence of Chronos and the telemetry sidepanel.

## 5. Order of work, with acceptance checks

Each step can ship alone and be reverted alone. Steps 1–2 are low-risk token and
text work. Steps 3–6 touch geometry and need live visual acceptance.

1. **P7 + P1 (voice).** Add the reading and annotation typefaces with
   unavailable-font fallbacks (FontState already reports discovery). Switch the
   default profile, keep the current all-mono profile as an opt-in "Terminal"
   preset, and move labels to sentence case.
   *Accept:* a bar screenshot at 1366×768 and 1920×1080 at 1.0 and 1.25 scale.
   No label clips, and numbers stay tabular while they update.
2. **P3 (palette).** Add named line tokens beside the existing ones, then point
   `moduleAccent` at them. Contrast ≥ 4.5:1 for text on `mantle` and `void_`,
   checked by a script. Adaptive snapping lives in `palette-state.py`.
   *Accept:* bright and dark wallpapers with the adaptive palette on and off.
   Danger stays distinguishable from Hα without relying on colour alone.
3. **P4 (motion).** Add a `Theme.easeKepler` token and move `SurfaceTransition`
   and geometry to it. Reduced motion still removes travel.
   *Accept:* rapid open, switch and close, recorded, with no overshoot or
   half-deployed state.
4. **P2 (plate).** Rebuild `EccentricPlate` on the P2 radii and adopt it in
   `InstrumentGeometry`/`GravityMaterial` behind a setting first.
   *Accept:* rounded containment on the GPU path, rectangular fallback on the
   software path, and every anchor edge (top, bottom, left, right).
5. **P5 (tether)** in `preview-instruments.qml` first, as the architecture
   requires for attached-boundary experiments. Remove the Caelestia blob
   experiment only after the tether is accepted.
6. **P6 (Aperture).** Prototype the transit indicator in Bar Studio's preview.
   *Accept:* workspace targets keep stable hit areas while the ring moves.
   Keyboard focus stays visible.

## 6. Open questions for the maintainer

- Is the 1942 plate archive the right anchor, or should the identity stay purely
  about black holes and orbits? P2–P5 work under either; P1's annotation serif
  and P3's line names depend on this choice.
- The website's Avayx display face ships with a "free for personal and
  commercial use" note that does not clearly grant redistribution inside a GPL
  package. Confirm the terms before using it in the shell. The OFL candidates
  above avoid the question.
- Should the default accent move from violet (close to Catppuccin mauve) to a
  line colour such as [O III] teal? Violet can remain a choice either way.
