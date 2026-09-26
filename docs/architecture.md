# Architecture

Agents should first read [the design and research guide](agent-design-guide.md).

Tonantzintla is one Quickshell application with a small number of deliberately
separated layers. Keep those boundaries intact: most past regressions came from
mixing layer-shell window ownership, UI presentation, and service lifetime.

The public suite is described through five focused Pages entry points:
[Aperture](suite/aperture.html), [Ephemeris](suite/ephemeris.html),
[Parallax](suite/parallax.html), [Resonance](suite/resonance.html), and
[Umbra](suite/umbra.html). These pages are user-facing contracts and source
maps; they do not duplicate the shared runtime services or visual components.

## Runtime flow

```text
src/quickshell/shell.qml
├── core singletons: Settings, Theme, ShellState, AdaptivePalette
├── src/quickshell/services/: long-lived system and compositor state
├── src/quickshell/modules/aperture/: always-visible bar
├── src/quickshell/modules/ephemeris/: on-demand expanding instruments
├── src/quickshell/modules/osd/: short-lived feedback surfaces
├── legacy quick-action commands: routed to the System instrument
├── src/quickshell/modules/transit/: notifications and clipboard presentation
└── src/quickshell/modules/umbra/: preview and isolated secure lock instance
```

`shell.qml` is composition only. It should not accumulate feature behavior.

## Core

- `Settings.qml` owns user-editable defaults and JSON persistence.
- `Theme.qml` maps settings and adaptive palette values into shared visual
  tokens. Components should consume tokens instead of inventing local palettes.
- `ShellState.qml` owns transient surface visibility and routing.
- `AdaptivePalette.qml` owns the wallpaper-derived palette cache.

These files live at the Quickshell source root because every QML layer imports
them. Repository-level packaging and compositor files stay outside the runtime.

## Services

Services translate external state into stable QML properties. They may invoke a
helper from `src/libexec/`, but should not own presentation. Examples include compositor,
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

## Platform boundary

UI code consumes `services/Compositor.qml`; it must not speak a compositor IPC
protocol directly. The 1.0 implementation uses Niri's socket. Later releases can
add backends under `compositors/` while keeping modules, components, and most
services unchanged.

`compositors/` contains only adapters that are actually supported. Do not add
placeholder Hyprland, Sway, labwc, X11, or other trees before they can be run and
maintained.

## Components

`src/quickshell/components/` contains reusable visual primitives. A component should be
independent of one complete surface and preferably consume service state through
properties. Complete screens and instrument layouts belong in `src/quickshell/modules/`.

## Modules

Aperture's arrangement editor keeps selection by island ID, with separate saved
horizontal and vertical layouts. `components/BarLayout.js` sanitizes persisted
layouts and transfers islands without duplication. Placement and ordering apply
immediately; Undo restores the preceding layout only while no outside edit has
superseded it. Meta+Alt+click an island opens Settings → Bar directly.
`BarButton.qml` animates its icon contents when its target panel opens, leaving
the button's hit area stationary. The Bar icon-motion toggle, global motion
switch, and instant motion profile all disable these opening animations.

Modules own Wayland surfaces or complete instrument families:

- **Aperture** owns the always-visible top bar.
- **Ephemeris** owns the full-screen transparent layer-shell host and animates
  an internal deck. Do not animate the layer-shell window geometry itself.
- **OSD** owns volume, microphone, and brightness feedback.
- **System** owns telemetry; legacy quick-action commands open this page instead of a separate rail. Cursor settings discover installed Xcursor themes and validate Niri configuration edits before saving a backup and applying them.

Settings → Niri settings → Cursor lists installed Xcursor themes (including Bibata
Modern variants), reads the current Niri theme and size, and applies explicit
selections. The helper preserves other cursor options and the rest of the config,
validates a staged file with `niri validate`, and creates a timestamped
`config.kdl.before-cursor-*` backup beside the configuration before replacement.
Included configs and disabled KDL nodes are reported as unsupported instead of
being rewritten unsafely. Theme installation is separate; Refresh discovers new
themes. Existing applications may need reopening. No compositor restart is forced.
Cursor behavior also offers hide-while-typing and an idle-hide delay. These options
are staged with the theme and applied together using the same validated transaction.

Automatic idle locking is owned by `IdleLock` in the main shell, not by an
installer-only Niri autostart entry. It starts an owned swayidle process after
settings load, defaults to five minutes, and invokes the installed `blackhole lock`
command. Lock screen settings expose enable, timeout and process/error status.
Changing settings restarts the owned watcher; disabling stops it. Existing external
idle daemons are not killed. swayidle's compositor idle inhibitors still apply.
This fixes installs using `--niri keep` whose existing configuration has no idle
hook. It does not establish suspend-before-lock readiness. The real PAM/session-lock
and idle-inhibition behavior must still be tested on the host Wayland session.
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

Launcher search is local and name-first: exact names, leading prefixes, word
prefixes, then contiguous name substrings. Metadata/aliases are a fallback only
when no names match; scattered-letter matches are deliberately excluded. Empty
searches and equally ranked results retain stable discovery order. A changed query
or category selects the best available result, while background model refreshes
preserve the selected identity. Short astronomy abbreviations do not inject facts
into ordinary app searches; full fact queries and calculator expressions remain.

1. Choose a category under `src/quickshell/modules/ephemeris/widgets/`.
2. Add the component to that directory.
3. Register its path in `src/quickshell/modules/ephemeris/widgets/qmldir`.
4. Add its unique id, relative source path, dimensions, placement, title, and
   code to `EphemerisRegistry.js`. This is the local widget contract, version 1.
5. The host loads that source asynchronously and the command palette discovers
   the same entry. Do not add a second routing table to the host.
6. Optionally add an entry point in Aperture or Field Tools.
7. Run `./tools/check` and test both open and close transitions in the live
   shell.

Widget roots are `Item`s, never their own layer-shell window. They may expose
`focusPrimary()` to receive keyboard focus and `beginDeployment()` to begin an
internal entrance. Both hooks are optional. Keep data in services; a widget must
survive being unloaded between visits. This is a local source-level contract,
not an installer for untrusted third-party extensions.

`SurfaceTransition.qml` owns displayed-tab state separately from the requested
tab. Content leaves before a source swap, the new component must finish loading
before entrance, and rapid requests coalesce. Closing cancels outstanding
entrances. Loader failures show an actionable state without taking down the bar.

`InstrumentGeometry.qml` and `InstrumentBridge.qml` are isolated prototypes in
src/quickshell/preview-instruments.qml; neither currently has a live host consumer.
The intended contract is shared bounds for backing and rounded masking with
fixed-size content. Integrate and validate that contract before restoring the
experimental settings toggle. It is not a general SDF metaball renderer.
Compact widgets may expose `preferredSurfaceHeight`; the live host clamps it to
the registry's screen bounds. See gemini-roadmap-1.1.md for the integration gate.

`output-preview.py` owns session-only Niri scaling previews. Its independent
watchdog has a runtime-directory lock and per-preview confirmation token. It
queries actual output scale before confirming or restoring it. No Niri config
files are edited; persistent mode/scale changes need a separate proven recovery
design. `OutputSettings.qml` reads display state only while its page exists.

`ApertureContents.qml` is shared by the real bar and its read-only settings
miniature. The preview must not create a second `PanelWindow` or fake telemetry.

## Safe change sequence

1. Commit a known-working checkpoint.
2. Change one architectural layer at a time.
3. Run the offline validation suite.
4. Inspect the live Quickshell log for `Configuration Loaded` and new warnings.
5. Test the affected surface manually.
6. Commit the focused change before beginning another risky pass.

## September 2026 interaction refinement

- Ephemeris now uses shared entry/exit/effect timings, including the resident
  lifetime. Geometry follows surface reveal independently of content swaps.
  Bar-launched audio/media open compact controls; Expand uses the same transition
  controller to enter the full instrument. Parallax retains its open orbit.
- Transit retains at most 100 individual notification records. App groups are
  derived presentation with independently readable/actionable members. History
  remains memory-only; no notification content is newly persisted to disk.
- Network actions are bounded helpers. `network-action.py` uses libnm and accepts
  credentials only through stdin. SSIDs and saved profile UUIDs remain separate.
  Enterprise/WEP/unsupported security requires Advanced settings. Saved VPN and
  WireGuard profiles can activate/deactivate; interactive VPN-specific secret
  acquisition still depends on the system's NetworkManager secret agent.
- `bluetooth-pair.py` registers a temporary, non-default BlueZ agent for the
  selected device only. PIN, passkey, confirmation, display and cancellation
  use newline-delimited JSON on the owned process pipes. It never silently
  trusts devices or becomes the global agent.
- Optional network dependencies: Python GObject (`python-gobject` on Arch),
  libnm introspection (`libnm`), and Python D-Bus (`python-dbus`) for pairing.
  Missing bindings produce unavailable/error states and retain external tools.
- AuthenticationPrompt uses Quickshell's PolkitAgent. It does not displace an
  existing agent. `auth-agent-bootstrap.py` waits briefly for verified native
  registration on session startup, then executes an external agent if necessary.
  Its fallback is bounded, not a new supervisor. Existing autostart configurations
  require an explicit ownership handoff; do not kill arbitrary authentication
  processes. Quickshell builds without the Polkit module can still load the shell
  because this module is loaded by URL.
- Settings search indexes ordinary terms and routes to the existing sections.
  Appearance Undo survives the shell's own atomic writes but is invalidated by
  external appearance edits. Cursor/output transactions retain their existing
  independent validation and rollback behavior.
- FeatureRegistry describes built-in capabilities, not third-party extensions.
  PluginRegistry is a compatibility adapter. `quickstats`/`telemetry` normalize
  to System; the duplicate catalog entry and duplicate overview action are gone.
- SpectrumConsumer explicitly acquires/releases the shared spectrum service.
  Audio analysis runs only for active consumers while media is playing.

API references used for the original adapters:
[NetworkManager](https://www.networkmanager.dev/docs/libnm/latest/NMClient.html),
[BlueZ](https://bluez.readthedocs.io/en/latest/agent-api/),
[Quickshell Polkit](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Polkit/AuthFlow/).

### Aperture clearance invariant

Ephemeris reserves every occupied Aperture edge on its target output.
`components/ApertureMetrics.js` supplies the same body thickness and margins
used by the actual bar, including compact, vertical, tall, and docked profiles.
Attachment placement and animation origins fit inside that safe rectangle;
negative attachment gaps no longer permit overlap. The entire composition
(including dimming and experimental backings) is clipped to it, and the Wayland
pointer mask uses the same rectangle. Clearance changes take effect immediately
even while panel geometry is animating. Aperture remains visible and clickable.

### Procedural gravity material

`components/GravityMaterial.qml` optionally replaces the ordinary Ephemeris
backing with a directly drawn Qt Quick shader. `Settings.panelMaterial` selects
`gravity` or `classic`; the appearance undo includes it. It consumes existing
transition progress rather than running an independent animation. No texture
capture or additional offscreen layer is introduced by this renderer. The
existing safe viewport clips both the panel and its light field outside Aperture.
Parallax retains its existing composition. Software rendering or shader errors
use the classic backing; `TONANTZINTLA_DISABLE_GRAVITY=1` is a startup override.
The old decorative atmosphere is suppressed while this material is available.
See `components/shaders/README.md` for compilation and resource boundaries.
