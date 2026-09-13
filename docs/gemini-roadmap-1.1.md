# Gemini handoff: finish 1.1 with intent

Prepared 2026-09-06. This is an implementation specification, not a release
announcement. Read AGENTS.md, agent-design-guide.md and architecture.md first.
Paths below are relative to the repository root. Work on `1.1-Gemini`; verify the
checkout and dirty tree before editing. Do not replace Gemini's settings overhaul.

## Progress checkpoint — 2026-09-09

Completed in the follow-through commit:

- **P0 sync sequencing:** dirty/unreadable source stops before pull; pull errors
  propagate; installer failure cannot restart; successful install reaches one
  restart. Git worktree `.git` files are supported. Tests use fake git, installer
  and lifecycle endpoints; no real update or desktop restart was performed.
- **P1-D preferences and presentation:** Settings → Panels now has independent
  volume, microphone and brightness feedback switches and a duration choice.
  Existing 1450 ms behavior remains the default. Disabling the visible kind
  dismisses it. Repeated updates reuse the popup without resetting its entrance.
  Muted is labelled separately from zero volume; long device labels elide.
  Spatial motion follows the global/instant profile.
- Popup content is now `modules/osd/OsdBody.qml`, shared by the real window and
  offscreen verification, with a solid rounded backing and inset contents.
  Out-of-bounds decoration was removed; the popup does not require a GPU mask.
  Bottom-bar
  clearance is applied by OsdPopup. The layer-shell window cannot run under the
  offscreen backend; content rendering and service tests do not establish live
  compositor placement acceptance.

**Still open:** P0 preset unification, geometry integration and greeter lifecycle;
P1-A/B/C; P1-D brightness write/readback/error handling and live multi-output
acceptance; all P2 work. DeviceState still displays requested brightness before
hardware confirmation. Do not mark all of P1-D complete.

Separate UmbraEventHorizon/shader edits from another work stream were preserved
and excluded from this checkpoint's commit.

## Direction and evidence

The next improvement should make familiar actions more dependable and easier to
read. Keep the real black hole, orbital Parallax, expressive blobs, solid panel
backs, translucent controls and rounded Resonance. Keep the manual's Overview,
Keys and Lock tabs. A profile page is still undecided; do not add one implicitly.
Do not restore Tools, Chronos, the diamond telemetry rail, or a wallpaper grid.

Sources checked on the date above:

- **Serpantinum:** its changelog records edge-aware launcher/clipboard input,
  grouped-notification icons, microphone feedback, DDC brightness fallback,
  blue-light scheduling fixes, and stale artwork corrections. These are upstream
  changelog claims, not our live tests or a claim that we inspected every backend.
  [Changelog](https://raw.githubusercontent.com/ilyamiro/serpantinum/master/CHANGELOG.md).
- **Caelestia:** its README documents per-monitor overrides with explicit global
  exceptions, tray hiding, notification grouping/expiry options, OSD switches and
  duration, and device-change feedback. Those configuration contracts are useful
  references, not evidence that our Niri implementation can reuse Hyprland code.
  [Configuration reference](https://raw.githubusercontent.com/caelestia-dots/shell/main/README.md).
- Serpantinum's README identifies an AGPL-3.0-or-later license. Implement original
  code from these behavioral ideas; review licenses separately before copying any
  upstream implementation or asset.
  [Serpantinum README](https://raw.githubusercontent.com/ilyamiro/serpantinum/master/README.md).

These are moving branch URLs; fetch and record the upstream revision before any
source reuse. A cached Caelestia UtilitiesPanel search result could not be opened
at its reported path; it is deliberately not used as implementation evidence.
Neither shell was installed for this research. The designs below are OUR proposals.

## Existing work to preserve

- Name-first local launcher search: exact name, prefix, word prefix, contiguous
  substring; metadata only when no name matches. No scattered-letter fuzziness.
  A new query selects the best result; a background refresh preserves identity.
- The bar arranger has stable selected IDs, placement/reorder controls, separate
  orientation layouts and guarded one-step Undo. Meta+Alt+click opens Bar settings.
- Five bar icon opening animations respect per-feature and global motion settings.
  Their button rectangles stay stationary. Do not replace these with moving targets.
- Compact manual/launcher/clipboard sizing, cursor revision checks, media seek
  guards and lyrics request identity handling are in this checkpoint.
- Scale preview is SESSION-ONLY, with an independent rollback helper. Do not
  silently turn it into persistent monitor editing.
- `setup` was intentionally removed; `bin/blackhole install` remains the installer.

There is already notification grouping, DND, microphone OSD and audio routing.
Improve those consumers; do not create a second service for each proposal.

## Delivery order

1. P0 integration audit and greeter correctness. Obtain host acceptance separately.
2. P1 edge-aware launcher and bar/tray refinement, in separate commits.
3. P1 notification presentation and OSD preferences, in separate commits.
4. P2 optional hardware work only after the 1.1 gate; suitable for 1.5 compatibility.

Stop after each package to show screenshots, tests, limitations and changed files.
Do not batch a redesign of every surface into one patch. A roadmap is not authority
to install, restart, activate a greeter, suspend, publish, or rewrite Git history.

## P0 — Close integration gaps before new features

### Geometry and settings truthfulness

Inspect `components/InstrumentGeometry.qml`, `InstrumentBridge.qml`,
`preview-instruments.qml`, `modules/ephemeris/EphemerisSurface.qml`, and
`components/SurfaceTransition.qml`. The geometry/bridge components currently have
preview consumers only; the live host does not use them. Earlier documentation
overstated integration. The inert joined-surfaces toggle has been removed from
the settings UI; its stored key and prototype are retained for follow-up.

Keep the bridge default-off. First wire one tested source of body bounds into the
live backing AND rounded mask, with fixed-size content revealed by the mask.
Use the existing transition progress; no second timer or layer-shell resize
animation. Prove ordinary rounded containment before exposing the experimental
attachment toggle. The toggle must visibly affect a real consumer before return.
Parallax's intentionally open orbit is an explicit exception to panel backing.

Acceptance: compile the actual host; render entrance/midpoint/exit frames; test
rapid tab changes and close-during-load at all four bar edges; verify no bright
artwork escapes Resonance corners. Test motion-off and fractional scale on-host.
A preview render alone does not close this item.

### CLI consistency

Inspect `bin/blackhole`'s `sync`, `run_installer`, and preset implementations against
`Settings.qml`. The sync sequencing bug is fixed using an installer subshell.
Preserve the tests: pull failure must stop; install failure must not restart; success
must restart exactly once. Keep local install independent of network updates.
Do not automatically stash, switch branches or discard source edits.

Make UI and CLI presets produce the same supported values from one maintained
contract. Test all presets against a temporary config, preserve unrelated keys,
and reject unsupported values with an actionable error. Do not claim a config
write confirms that a desktop process reloaded it.

### Greeter handoff — distinct from session locking

Files: `modules/umbra/greeter/lightdm/index.js`, `style.css`, `Main.qml` (SDDM),
`umbra-lock.qml`, and `docs/umbra.md`. The current LightDM patch is a timer-based
prototype: success waits 1120 ms before session start. Its prompt lifecycle and
failure/retry handling are NOT established by existing tests. SDDM completes a
pre-auth animation before submitting login; it cannot promise visible animation
after the display manager has already started the session.

Build explicit states: idle → authenticating → capture → starting → error/idle.
Use the installed LightDM web-greeter API's actual prompt signals: do not assume
`respond()` immediately after `authenticate()` is correct. Capture the selected
user/session per attempt. Disable duplicate submissions and user changes during
an attempt; clear passwords; invalidate old callbacks on cancellation/failure.
Gate session start on authenticated state AND capture completion. Use a bounded
timeout fallback for missing animation events; reduced motion completes promptly.
Handle session-start failure and allow a new attempt. Never log credentials.

Acceptance: mocked API tests for rejection, delayed prompts, duplicate completion,
cancel/retry, failed session launch, animation completion, absent animation events
and reduced motion. Then explicit user-approved LightDM host testing with a known
working fallback/TTY route. Do not activate `/etc` changes yourself. For the Niri
locker, verify secure acquisition, wrong-password recovery, idle expiry and output
hotplug separately. No IPC unlock command or authentication bypass is acceptable.

## P1-A — Launcher and clipboard that respect the bar edge

Inspiration: Serpantinum's edge-aware input. Files: `LauncherWidget.qml`,
`ClipboardWidget.qml`, `modules/transit/ClipboardPane.qml`, `EphemerisSurface.qml`,
`EphemerisRegistry.js`; discover their full paths before editing.

- Top bar: search field above results. Bottom bar: field below results, close to
  the invoking edge. Left/right: keep a normal top field in an adjacent panel.
- Preserve result order; do not reverse the model for bottom placement. Up/Down
  follow visible list direction, Enter activates the selected identity, Escape
  dismisses. Input keeps focus while result count changes.
- Use content-driven height bounded by screen work area. Animate the panel
  reveal, not a continuously resizing layer-shell window. Keep search height and
  click targets fixed; lengthy descriptions elide rather than shuffle rows.
- Preserve the new search algorithm. No new web API, telemetry, network search,
  fuzzy description matching or automatic shell execution for ordinary text.
- Start with automatic edge behavior, not another preference. If a preference
  becomes necessary, default to follow-bar and expose it once under Panels.

Acceptance: top/bottom/left/right, 0/1/80 results, long names, keyboard selection,
desktop-entry refresh, 1366×768 and 125%/150% scaling. Add a QML interaction test
for focus and selection after query change; pure model tests alone are insufficient.

## P1-B — Deliberate bar density, monitor scope and tray overflow

Inspiration: Caelestia's per-monitor configuration and tray controls. Original
Tonantzintla design: retain our island editor and put overflow into one small,
anchored tray disclosure, not a new sidepanel.

Files: `Settings.qml`, `ApertureBar.qml`, `ApertureContents.qml`, `BarLayout.js`,
`IslandArrangementEditor.qml`, `TrayStrip.qml`, `islands/TrayIsland.qml`.

1. Add an optional per-output override map, versioned and keyed by compositor
   output name. Missing fields inherit global values; disconnected entries remain
   editable/removable but never become the defaults of a different output.
2. First scope ONLY bar visibility, position and island layout. Palette, fonts,
   motion and device settings remain global. The editor gets an explicit
   All displays/current display selector and Reset to inherited action.
3. Resolve an effective configuration per bar instance and pass it downward.
   Audit direct global Settings reads in child islands and buttons; do not mutate
   the global bar position to render a secondary output or preview.
4. Tray preferences: default all visible; explicit pinned and hidden identities.
   Match stable exported item IDs, not dynamic titles, PIDs or array indices.
   If no durable identity exists, keep its preference session-only and say so.
5. On narrow bars, shorten the window-title/media text first, then place unpinned
   tray items behind one disclosure. Keep launcher and settings reachable. Do not
   overlap the center zone or silently drop workspaces. Preserve native tray
   activation/context menus; keyboard-opened menus must stay usable.

Visual specification: reuse existing island radii, Theme tokens and 34–42 px
control targets. Expanded tray sits on a solid rounded backing with stable rows;
no full-screen modal, rainbow borders or perpetual icon movement. Highlight the
selected monitor scope, not every tile. Editor Undo applies only to its scope.

Acceptance: two outputs with different edges; disconnect/reconnect; long media
title; 15 tray items; tray item replacement while a menu is open; malformed saved
overrides; all-hidden tray recovery; keyboard and pointer operation. Preview must
match the effective configuration of the selected output without another service.

## P1-C — Notification groups with useful hierarchy

Inspiration: Serpantinum's group icons and Caelestia's group/expiry configuration.
Files: `services/Notifications.qml`, `modules/transit/NotificationHistoryPane.qml`,
`NotificationPopups.qml`, their shared card component, and Settings.

Keep the existing notification service and fusion behavior. Audit replacement IDs,
member actions and dismissal before restyling. Group header: actual application
icon, app name, count, newest timestamp and an explicit expand control. Expanded
groups show individual messages and their own valid actions. A group-level click
must never execute the wrong member's default action. Invalidated actions become
unavailable, not decorative buttons that silently fail.

Default collapsed preview: at most two lines from the newest message. Critical
messages stay visually distinct and must not disappear into an ordinary group.
Keep DND and deep-focus policy unchanged; any change to critical suppression needs
an explicit decision. Keep history separate from transient popup expiry.

Add only justified settings: collapsed/expanded by default (collapsed), popup
duration (retain existing behavior as migration default; validate 2–10 seconds),
and preview body visibility (on). No persistent notification-body archive in this
pass; it is a privacy/storage feature requiring separate scope.

Acceptance: replacement message, 30-message burst, two apps with the same display
name, expired actions, dismissal of a single member and full group, DND/deep focus,
long text and missing icons. Bound history growth; verify virtualized scrolling.

## P1-D — Consistent device feedback without noise

Inspiration: upstream OSD configuration; microphone OSD already exists here.
Files: `services/Osd.qml`, `Audio.qml`, `DeviceState.qml`, `modules/osd/OsdPopup.qml`,
and `SettingsPane.qml`.

Expose volume/brightness/microphone feedback switches and a duration choice of
1.0/1.5/2.5 seconds; preserve the current 1450 ms duration for existing configs
unless explicitly changed. Keep switches independent of bar icon visibility.
Coalesce repeated keypresses into the existing popup and restart its deadline;
do not queue a stack or allocate a new process per keypress.

Distinguish mute from zero volume. Label the actual device when useful. A pending
brightness request must not look like confirmed hardware state; reconcile after
readback and surface failures. Do not add polling just to animate meters.
Use one accent channel per kind and solid backing, stable icon/number placement,
short entrance and fade exit. Motion-off uses no spatial travel. Keep OSD clear of
the bar on every edge and within the focused output's work area.

Acceptance: rapid volume presses, mute toggle, absent source/backlight, hotplug,
write failure, global motion-off, per-kind disabled, and expiry during replacement.
UI tests must prove each new preference changes its intended consumer.

## P2 — Hardware/1.5 candidates, not 1.1 blockers

**External-monitor brightness (DDC):** extend DeviceState behind a bounded helper.
Discover support on demand; cache capabilities; serialize writes per monitor;
read back results. Default disabled until the user selects a supported output.
Never send DDC to every display, change permissions automatically or add sudo
prompts to the bar. Handle permission errors, unsupported VCP and disconnected
monitors. Test the helper with a fake backend before approved hardware testing.

**Night color:** separate manual enable/temperature from optional scheduling.
Require an available backend and one owned instance, preserve external ownership,
and keep geolocation off by default. Manual location must survive updates. Show
unsupported on compositors lacking the required protocol. Do not add it until
startup, reload, disable/restore and existing-owner behavior are tested.

Do not implement keep-awake or automatic suspend as a casual utility toggle; that
changes the idle-lock security contract and needs its own approved design.

## Verification and handoff contract

Run `git diff --check`, `python3 -m unittest discover -s tests -q`,
`bash tests/test_cli.sh`, and `./tools/check`. Inspect skips and warnings rather
than reporting a blanket pass. Tests using fake hardware do not prove real hardware.
The current suite skips a host-socket-dependent check in this sandbox.

For each package, record: files changed; defaults/migrations; tests and exact
results; wide/narrow screenshots; which host checks remain; how to revert just
that package. Capture light artwork on dark panels to expose clipping bugs.
Use isolated XDG directories for tests so previews cannot overwrite user settings.

Keep 1.1 unreleased until P0 is resolved and the user accepts the desktop. P2 is
optional future work. Do not make a large feature list a condition for shipping.
No push/install/restart is implied by this document. Ask for the appropriate
action when the user is ready; retain a known-working installed runtime.
