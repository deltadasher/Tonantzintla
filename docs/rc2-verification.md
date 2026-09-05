# RC-2 lifecycle verification

`start`, `session-start`, and `restart` use the same portable Python session
supervisor on Arch and Obarun. Niri's existing session-start binding remains
the login entry point. No boot service or 66 database changes are needed.
`run` remains an unsupervised foreground debugging command.

The supervisor owns one child process group, retries crashes at most five
times per minute, limits its shell log to 2 MB, and exits when the session's
Wayland socket disappears or changes. `blackhole daemon status` reports
its process IDs; `blackhole daemon logs` prints the recent log.
Uninstall stops the supervisor before removing the runtime.

Version output includes the installed source revision and compares runtime
contents with the recorded checkout, including uncommitted edits. A dirty
revision is explicitly marked; it is not a unique release build identifier.

Automated checks: `python3 -m unittest discover -s tests`,
`cargo test --locked --manifest-path install/Cargo.toml`, and `tools/check`.
The lifecycle test uses a fake shell and Wayland socket to exercise duplicate
starts, crash restart, and session disappearance. A sandbox which forbids
Unix sockets skips that integration test explicitly.

Live release checks still required on an actual desktop:

- Repeated start/restart/stop leaves exactly one shell and notification owner.
- Rapid calendar/media/Parallax switching settles without overlap or flicker.
- Suspend/resume restores the UI and leaves mute, output, and Pitcher unchanged.
- Unplug/reconnect headphones and disable/re-enable network; controls recover.
- Compare `blackhole profile` before and after ten minutes of tab switching.
- Log out and back in; the old supervisor exits and a new one starts.
- Exercise install/update/uninstall and rollback in disposable Arch/Obarun homes.

These manual checks must not be reported as passed based on unit tests.
