# Changelog

## 1.0.0 - 2026-09-05

WELCOME TO TONANTZINTLA 1.0.

- Rename the shell, public command, and runtime to Tonantzintla.
- Consolidate RC, Obarun, and orbital interface work into one mainline release.
- Keep one transactional installer and one public command surface.
- Preserve existing preferences during the Astralith migration.
- Add session supervision, crash limits, bounded logs, and build-drift reporting.
- Repair relocated helper paths, wallpaper previews, and RC runtime upgrades.
- Add explicit audio restoration and visible library/forecast retry states.

## 1.0.0-rc.1 - 2026-08-31

- Added Resonance Pitcher: an orbital semitone instrument, fine-cent control,
  wet mix, and musical jumps backed by EasyEffects' live PipeWire output graph.
- Consolidated the Obarun work into one release candidate with a bounded
  `blackhole obarun-audit` report for distribution, 66, session, installer,
  network, and audio readiness.
- Made Niri session startup import a complete Wayland/D-Bus environment without
  requiring systemd and conservatively recover silent SOF speaker routes.
- Recognized wireless interfaces through procfs, sysfs, and `iw`, preventing
  externally managed Wi-Fi devices from being mislabeled as Ethernet.
- Made post-install commands usable even when `~/.local/bin` is absent from the
  invoking shell's `PATH`.
- Warn Obarun users before dependency resolution that `[obcommunity]` and its
  following configuration line must be enabled in `/etc/pacman.conf`.
- Report a missing `~/.local/bin` PATH entry during planning and after install,
  while always printing an immediately usable absolute command.
- Repair the portable greeter dispatcher, keep non-SDDM adapters out of the
  SDDM stage, and remove the unreferenced legacy Niri configuration.
- Keep Parallax inside deliberate wallpaper roots so Optics screenshots can
  never appear in the wallpaper catalog.
- Removed the original machine's terminal, browser, file-manager, and weather
  defaults; `blackhole terminal`, `browser`, and `files` now resolve user or
  system choices through the single installed command.

## 0.9.1 - 2026-08-29

- Accepted Obarun and other compatible Arch derivatives through `ID_LIKE`,
  kept Artix outside the support boundary, skipped unavailable repository
  packages without aborting the whole install, and made Niri's session
  environment import work without a systemd user manager.
- Made the network indicator recognize externally managed Wi-Fi and Ethernet
  through kernel and `iw` state when NetworkManager is not running, and made
  volume controls adopt a usable PipeWire node when no default metadata exists.
- Added `blackhole audio-recover` for SOF laptops whose hardware speaker
  switch or PipeWire card profile remains silent despite normal volume state.
- Recast the Manual overview as an animated gravitational launcher and replaced
  its generic lock card with an interactive Umbra event-horizon instrument.
- Made online wallpaper searches fetch six previews at once, reduced preview
  payload size, and cached recent queries so reopening a search is immediate.
- Replaced the Manual wiring diagram with a direct Umbra page, removed its
  floating launch/status copy, and made Ephemeris bodies fully opaque so text
  from applications underneath cannot leak into an instrument.
- Added a five-minute Niri idle lock through `swayidle`, display sleep after
  another five minutes, wake-on-input, and a lock-before-suspend safeguard.
- Reduced Resonance spectrum work to 20 FPS, scheduled CAVA below the audio
  stack, and removed redundant captions from the media controls.

- Rewrote every user-facing string in plain language. Status readouts, setting
  names, empty states, and button labels now say what they do instead of
  leaning on spaceflight metaphors, so the shell reads correctly to someone
  who has never seen it before.
- Renamed the extension entries and their codes after what they control, gave
  their counters correct singular and plural forms, and let the descriptions
  wrap to two lines so none of them are cut off.
- Shortened the settings section names and page headings to match the plain
  vocabulary used everywhere else.

## 0.9.0 - 2026-08-29

- Licensed Tonantzintla's project-owned work under GPL-3.0-or-later and restored
  the Wabi-Sabi Black Hole across the repository and Flight Manual identity.
- Rebuilt Ephemeris Calendar as an interactive astronomical watch with
  independently spinnable date layers, live orbital time, lunar telemetry,
  restart-safe mode choreography, and an animated forecast procession.
  Telemetry pours through a reversible GPU metaball field as its exclusive celestial
  faces replace the calendar with either all eight planets positioned from JPL J2000
  orbital data or a location-centered Earth with a smooth live day/night
  terminator and local sunrise/sunset timing.
- Established the first known-working Git checkpoint.
- Organized Ephemeris widgets by catalog, desktop, media, productivity, and
  system responsibilities.
- Added multi-machine installation, update, uninstall, and dependency doctor
  workflows.
- Rewrote repository documentation around safe Niri deployment and architectural
  ownership.
- Made detailed mixer, network, clipboard, spectrum, lyrics, recording, device,
  and folder telemetry follow their owning surfaces instead of polling at idle.
- Replaced repeated system-telemetry Python startups with one streaming helper,
  made wallpaper restoration idempotent, and added `blackhole profile`.
- Reassigned `Meta+Up/Down` to workspace travel, retired wheel-based workspace
  switching, and enlarged notification dismissal into a full-height close rail.
- Routed `Meta+Shift+S` through Niri's native interactive screenshot UI after
  the detached Slurp handoff began exiting before presenting its selector.
- Made Niri autostart and every Tonantzintla hotkey resolve the installed
  controller through `$HOME`, and taught that controller to find an active
  development shell when it differs from the installed checkout.
- Rebuilt Umbra as the original Eclipse Cartography instrument: a displaced
  event horizon, gravitational streamlines, constellation password trajectory,
  fractured clock, and orbital network, battery, and media telemetry replace
  the conventional centered authentication card.
- Replaced the remaining unlicensed adaptation points with Tonantzintla's binary
  forecast array, original interpolated equalizer profiles, and a documented
  Wikimedia Commons wallpaper provider.
- Removed the unused bundled GNOME AdwaitaLegacy PNG controls and their dead
  Ephemeris registry metadata.
- Removed redundant Ephemeris close glyphs and prevented hidden module geometry
  and the native spectral seam from flashing ahead of the fluid surface.
- Made Parallax's uncovered field dismiss the surface and added an original
  static accretion-disk illustration to the Flight Manual.
- Collapsed six-fold settings persistence onto a single adapter, moved the
  audio mixer onto PipeWire's node registry in place of the polling helper
  process, and reduced repeated helper-path and settings-toggle markup to
  shared definitions.
