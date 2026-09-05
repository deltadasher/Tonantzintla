# TONANTZINTLA

![Tonantzintla black hole](src/assets/illustrations/wabi-sabi-black-hole.svg)

## WELCOME TO TONANTZINTLA 1.0

A desktop with a little gravitational pull.

Built with Quickshell for Niri. Tested on Arch Linux and Obarun.
Orbiting calendars, fluid surfaces, music you can bend, and a black hole
to come home to. Eccentricity belongs on the desktop.

**Aperture** is the bar. **Ephemeris** holds the instruments.
**Parallax** is your wallpaper library. **Resonance** handles media, lyrics,
audio and pitch. **Optics** captures the screen. **Umbra** locks the session.

### Install

```bash
sudo pacman -S --needed git rust
git clone https://github.com/deltadasher/Astralith.git Tonantzintla
cd Tonantzintla
bin/blackhole install --profile recommended --niri keep --umbra lock --yes
~/.local/bin/blackhole start
```

The repository URL above remains valid during the rename.
On Obarun, enable its `obcommunity` repository before installing.
Use `--niri replace` only if you want the bundled Niri configuration.

### Use it

```bash
blackhole help
blackhole version
blackhole update
blackhole restart
blackhole doctor
```

Add `~/.local/bin` to your PATH if your shell cannot find the command.
The shell is supervised within your Wayland session on both Arch and Obarun.
`blackhole daemon logs` shows its recent log.

Existing Astralith preferences are copied on install when the new preference
directory does not exist. The old runtime stays available for recovery.
Existing keybindings can continue through a migration alias; new bindings
should use `blackhole`.

### Make it yours

Choose your applications, weather location, fonts, and motion in Settings.
Put wallpapers in `~/Pictures/Wallpapers`. Captures stay separate.

[Architecture](docs/architecture.md) · [Dependencies](docs/dependencies.md) ·
[Machines](docs/machines.md) · [Umbra](docs/umbra.md) · [Contributing](CONTRIBUTING.md)

GPL-3.0-or-later. Copyright © 2026 deltadasher.
See [LICENSE](LICENSE). Third-party work retains its own attribution and license.
