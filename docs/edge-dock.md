# Aperture edge dock

The dock is an Aperture island with an auto-hidden application-strip host. It uses
one non-exclusive, non-keyboard-grabbing layer-shell surface per chosen output.
A masked 3-pixel edge strip admits pointer input while hidden. Entry dwell and
delayed dismissal prevent accidental activation and flicker; timers only run
while needed. The input mask expands with reveal, not before it. No global mouse
poller, duplicate compositor connection, or persistent animation loop is added.

Bar Studio → Islands enables the Dock. Its single Tonantzintla-logo handle participates in
the same drag/drop system as other islands: four edges, each with start, center
and end alignment. Click without dragging to open its dedicated settings panel.
The Apps page supports searching installed apps, pinning, ordering, and theme-icon
overrides. Appearance controls size, output and hover lift; Behavior controls
entry/dismissal timing, running apps and the launcher shortcut. Settings use
sliders instead of banks of timing buttons.
While editing, the auto-hidden host yields to the draggable logo handle. It does
not duplicate the application icons or wrap as applications open and close.
Outside editing, the island yields to the host without reserving empty bar space.
Both consume the same saved placement; legacy edge/alignment settings supply the
initial placement until the user moves it. The visible host is 30px shallower.
Settings persist through the existing Settings adapter. Default: enabled on the
first display, bottom center. If a named output disappears, it falls back to the
first available display. Pinned apps begin empty; a launcher button remains
available when the dock is otherwise empty. The searchable app list scrolls
through all matches and never executes app names as shell commands.

Click a running app to focus it; subsequent clicks cycle its windows. Middle-click
or Shift-click opens a new instance through DesktopEntry.execute(). Apps are
grouped by normalized desktop ID or declared startup class; missing desktop
entries retain window focusing but cannot launch a new instance. Pin order is
explicit; running groups are ordered by window ID, not recent focus. Many apps
fit in a scrollable strip rather than extending offscreen. Reduced motion removes
the reveal animation and hover interpolation. A same-edge bar and dock can compete
for the chosen activation strip: choose an unused edge or a different alignment.

## Design and upstream reference

Reviewed Serpantinum's [Dock.qml](https://github.com/ilyamiro/serpantinum/blob/master/src/quickshell/dock/Dock.qml)
on 2026-09-18: per-output layer-shell windows, auto-hide timing, bounded icon sizing,
and separate input/exclusion behavior. This implementation is original code; no
AGPL source was copied. Tonantzintla's contour grows directly from the physical
screen edge, with a solid theme-colored fill and curved attachment feet. App hit
targets do not move when their icons enlarge. It integrates with the existing bar
placement model without altering Niri configuration, shell lifecycle, or application
preferences. This is not a KDE backend or compatibility implementation.

## Checks

- `node tests/test_dock_model.cjs`: ID matching, missing apps, focus cycling,
  stable ordering, pin validation, icon overrides and reorder boundaries.
- `python3 -m unittest discover -s tests -p test_surface_compile.py -q`:
  reusable dock controls compile offscreen.
- `preview-dock.qml`: isolated still-render harness; set
  `TONANTZINTLA_DOCK_PREVIEW` to an output PNG path.
- `preview-dock-check.qml`: invisible Wayland-backed construction test for input
  depth, all twelve shared drop placements and disabling. Use disposable
  HOME/XDG config/state directories.

Actual pointer feel, fractional scaling, multi-monitor transitions and application
launch/focus behavior need host acceptance. The dock is mouse-oriented; keyboard
application access remains available through the existing launcher. This version
uses explicit up/down controls for pinned ordering, not drag-and-drop pinning.
