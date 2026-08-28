# Runtime performance audit

Audit date: 2026-08-25.

## Scope

This pass reviewed the Quickshell composition tree, singleton lifetime, timers,
external process launches, helper scripts, generated/runtime artifacts, tests,
and repository boundaries. Visual geometry and interaction behavior were kept
unchanged.

The checkout cannot see the host session's process namespace from every
sandboxed development environment, so system-wide idle RAM claims must be
measured from the actual Niri session. `astralithctl profile` now reports the
Astralith process tree from that session without estimating it.

## Changes landed

- CPU, memory, network, load, and uptime telemetry comes directly from `/proc`
  through Quickshell `FileView` objects. A short-lived Python probe refreshes
  temperatures, disk usage, kernel data, and process count every 30 seconds.
- Full PipeWire/Pulse inventory is collected only while Acoustic Array or
  Resonance is open. Lightweight output and microphone levels remain live for
  Aperture and OSD.
- The Link Array runs no command probe while closed. Its complete Wi-Fi,
  Bluetooth, and Ethernet inventory refreshes every ten seconds while open.
- CAVA runs only while Acoustic Array or Resonance is visible.
- Synced lyric lookup runs only while Resonance is visible.
- Clipboard indexing runs only while Clipboard Orbit is visible. The two
  event-driven `wl-paste`/`cliphist` watchers remain active so history is not
  lost while the panel is closed.
- Recording status is checked once at startup, while Optics is open, or while
  a recording is active instead of once every second forever.
- Brightness and power-profile command polling runs only for a visible bar
  brightness channel or an open Reactor widget.
- Expensive home-folder size scans run only while Observatory Telemetry is open
  and no more than once every five minutes.
- Wallpaper restoration is idempotent, preventing the startup probe, settings
  load, and fallback timer from applying the same wallpaper more than once.

## External launch budget

Approximate steady-state launches per minute, excluding event-driven user
actions and the two persistent clipboard watchers:

| Subsystem | Before, closed | After, closed | Open-widget behavior |
| --- | ---: | ---: | --- |
| System telemetry Python startups | 30 | 2 slow probes | same cadence |
| Full mixer Python/backend launches | about 240 | 0 | about 96 per minute |
| Full network Python/backend launches | up to 60 | 0 | original detail cadence |
| Recording status checks | 60 | 0 | 24 idle in Optics, 60 while recording |
| Clipboard index helpers | 27 | 0 | original 27 per minute |
| Brightness/profile reads | 30 | 0 on a desktop/default hidden channel | 7 to 8 per active channel |
| Folder scan helpers/`du` calls | up to 10 | 0 | up to 10 every five minutes |

The exact backend count varies with installed tools and hardware. The important
boundary is that detailed services now follow their owning surface rather than
remaining active merely because their singleton was instantiated once.

## Remaining intentional costs

- Niri, MPRIS, UPower, NetworkManager, Bluetooth, system tray, and notification
  state use event-driven Quickshell integrations.
- Audio levels use event-driven PipeWire objects; fast system samples are
  direct kernel-file reads and spawn no helper.
- Ephemeris, OSD, Quick Actions, Umbra preview, and Umbra reveal hosts are
  demand-resident. Focused surfaces instantiate only for the focused output.

## Maintainability findings

- Runtime/build output is ignored and not tracked.
- No user-specific absolute source paths are tracked.
- `SettingsPane.qml`, `MediaWidget.qml`, and `UmbraSurface.qml` are the largest
  remaining presentation files. Splitting them is useful before public API
  stabilization, but doing so during a performance pass would create broad
  import and animation risk without reducing runtime work.
- Ephemeris uses Astralith's single-Canvas morph renderer and has no optional
  Caelestia plugin process, shader module, or build bridge.

## Verification gate

1. Run `astralithctl check`.
2. Run `astralithctl profile` with all widgets closed.
3. Open Audio, Network, System, Clipboard, Media, and Capture once and verify
   each detail service wakes and settles correctly.
4. Close every surface, wait ten seconds, and run `astralithctl profile` again.
5. Record host-wide idle memory separately; do not attribute unrelated desktop
   applications or filesystem cache to Astralith.
