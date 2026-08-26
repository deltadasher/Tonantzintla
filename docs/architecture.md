# Architecture

Astralith is one Quickshell application with a small number of deliberately
separated layers. Keep those boundaries intact: most past regressions came from
mixing layer-shell window ownership, UI presentation, and service lifetime.

## Runtime flow

```text
shell.qml
├── core singletons: Settings, Theme, ShellState, AdaptivePalette
├── services/: long-lived system and compositor state
├── modules/aperture/: always-visible bar
├── modules/ephemeris/: on-demand expanding instruments
├── modules/osd/: short-lived feedback surfaces
├── modules/quickactions/: on-demand edge deck
├── modules/transit/: notifications and clipboard presentation
└── modules/umbra/: preview and isolated secure lock instance
```

`shell.qml` is composition only. It should not accumulate feature behavior.

## Core

- `Settings.qml` owns user-editable defaults and JSON persistence.
- `Theme.qml` maps settings and adaptive palette values into shared visual
  tokens. Components should consume tokens instead of inventing local palettes.
- `ShellState.qml` owns transient surface visibility and routing.
- `AdaptivePalette.qml` owns the wallpaper-derived palette cache.

These files remain at the repository root because every QML layer imports them.
Moving them creates broad import churn for little organizational benefit.

## Services

Services translate external state into stable QML properties. They may invoke a
helper from `scripts/`, but should not own presentation. Examples include Niri,
MPRIS, PipeWire, NetworkManager, weather, clipboard, focus history, and system
telemetry.

Rules:

1. Missing optional commands must produce an unavailable state, not prevent the
   shell from loading.
2. A service should poll once for all consumers; widgets must not create a
   second poller for the same information. Expensive detail polling must follow
   the visibility of its owning surface and settle when that surface closes.
3. Runtime files belong in XDG config/cache/state directories, never the source
   checkout.
4. Machine-specific paths must come from environment variables or resolved
   project URLs.

## Components

`components/` contains reusable visual primitives. A component should be
independent of one complete surface and preferably consume service state through
properties. Complete screens and instrument layouts belong in `modules/`.

## Modules

Modules own Wayland surfaces or complete instrument families:

- **Aperture** owns the always-visible top bar.
- **Ephemeris** owns the full-screen transparent layer-shell host and animates
  an internal deck. Do not animate the layer-shell window geometry itself.
- **OSD** owns volume, microphone, and brightness feedback.
- **Quick Actions** owns Chronos and compact telemetry.
- **Transit** owns notification and clipboard presentation.
- **Umbra** owns the preview plus a separate secure Quickshell lock process.

## Ephemeris geometry rule

The reliable model is:

1. keep a stable transparent fullscreen `PanelWindow`;
2. map the host before beginning the transition;
3. animate the internal deck's position, scale, opacity, and clipped contents;
4. keep the loaded widget alive through its exit transition;
5. unmap only after the close animation finishes.

Resizing a layer-shell window to imitate a growing popup maps the final geometry
immediately on several compositors and removes the perceived animation. Any new
attached-boundary experiment must first live in an isolated preview harness and
remain behind a feature switch until it is proven.

## Adding a widget

1. Choose a category under `modules/ephemeris/widgets/`.
2. Add the component to that directory.
3. Register its path in `modules/ephemeris/widgets/qmldir`.
4. Add its dimensions, placement, title, code, and icon to
   `EphemerisRegistry.js`.
5. Add the component routing in `EphemerisSurface.qml`.
6. Add the entry point in Aperture, Field Tools, or another appropriate module.
7. Run `./scripts/check` and test both open and close transitions in the live
   shell.

## Safe change sequence

1. Commit a known-working checkpoint.
2. Change one architectural layer at a time.
3. Run the offline validation suite.
4. Inspect the live Quickshell log for `Configuration Loaded` and new warnings.
5. Test the affected surface manually.
6. Commit the focused change before beginning another risky pass.
