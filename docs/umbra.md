# Umbra session veil

Umbra is Astralith's Niri-native lock screen. It runs as a dedicated Quickshell
instance, uses the Wayland session-lock protocol to cover every output, and uses
PAM to authenticate the current user. The password remains in memory only for
the active prompt and is cleared after every result.

## Safe first test

Preview the complete visual surface without locking the compositor or invoking
PAM:

```sh
astralithctl preview-lock
```

Press `Escape` to leave the preview. The same preview is available under
Observatory Settings -> Lock.

## Locking

After the preview looks correct, lock with either:

```sh
astralithctl lock
```

or `Super+Alt+L` when using Astralith's example Niri configuration. Enter
submits the password; `Ctrl+U` clears it.

The default PAM service is `login`, resolved from `/etc/pam.d/login`. It can be
changed under Observatory Settings -> Lock for distributions that provide a
dedicated lock profile.

## Surface behavior

- One secure `WlSessionLockSurface` is created for every active output.
- The lock target remains engaged across QML hot reloads; the ordinary desktop
  shell and the non-locking preview are separate from the secure lock process.
- Wallpaper diffusion falls back to the bundled Umbra sky when the current wall
  is a video or unavailable.
- Umbra's Eclipse Cartography surface is intentionally asymmetric: time is a
  vertical fracture, the session state lives at the edge, and a displaced event
  horizon owns the right side of the output.
- The password is represented as a constellation trajectory rather than a text
  box. Each entered character energizes one node; authentication sends a probe
  down the curve, and rejection collapses the field into the danger spectrum.
- Network, battery, and media are rendered as orbiting bodies rather than pills
  or dashboard cards. Strong color is reserved for live state and interaction.
- Cached weather, battery, network, and safe MPRIS controls remain available
  without exposing desktop windows.
- Motion, wallpaper diffusion, media, and weather are independently configurable.
- Animated canvases are dormant while both the lock and preview are inactive,
  so the ordinary unlocked session does not pay for Umbra's motion system.

## Recovery note

A conforming Wayland compositor intentionally remains locked if the lock client
crashes. Validate the preview and PAM service before the first real lock. If a
development build fails while locked, switch to a TTY, repair or stop the broken
instance, and start a known-good locker before returning to the graphical session.

## Umbra before the session

Astralith also ships a distinct Qt 6 SDDM theme under
`modules/umbra/greeter/`. It shares Umbra's event-horizon language, but not its
runtime or authentication state: SDDM remains responsible for users, sessions,
login, and power actions.

Authentication uses a visual handoff instead of waiting for SDDM's success
signal. Submitting begins the event-horizon capture first; SDDM receives the
login request once the screen is nearly consumed. A rejected password recoils
the field. A successful Niri session starts Astralith through `session-start`,
which holds an opaque Umbra veil and opens a circular aperture onto the desktop.

Preview it safely without changing the active display manager theme:

```sh
astralithctl greeter preview
```

After inspecting the theme, install it without selecting it using
`astralithctl greeter install`, or install and select it with
`astralithctl greeter activate`. `astralithctl greeter deactivate` removes only
Astralith's selection override, allowing the previous SDDM theme configuration
to take precedence again.
