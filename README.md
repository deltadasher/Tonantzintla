# TONANTZINTLA

![Tonantzintla black hole](src/assets/illustrations/wabi-sabi-black-hole.svg)

## Tonantzintla 1.5

Built with Quickshell for Niri & Hyprland (to be extended to other wayland compositors in the near future).
The installer supports Arch Linux and compatible Arch derivatives, including Obarun. On Fedora and Debian the installer can report the configuration but does not install the shell.
Highly customizable!

## ARTIX NOT SUPPORTED INTENTIONALLY

### It's modular!

Use the five public entry points to see what each part does and find its direct source:

[Aperture](https://deltadasher.github.io/Tonantzintla/suite/aperture.html) ·
[Ephemeris](https://deltadasher.github.io/Tonantzintla/suite/ephemeris.html) ·
[Parallax](https://deltadasher.github.io/Tonantzintla/suite/parallax.html) ·
[Resonance](https://deltadasher.github.io/Tonantzintla/suite/resonance.html) ·
[Umbra](https://deltadasher.github.io/Tonantzintla/suite/umbra.html)

### Install

```bash
sudo pacman -S --needed git rust base-devel &&
git clone https://github.com/deltadasher/Tonantzintla.git Tonantzintla &&
cd Tonantzintla &&
bin/blackhole install --profile recommended --niri keep --umbra lock --yes &&
~/.local/bin/blackhole start
```

The repository URL above remains valid during the rename.
On Obarun, enable its `obcommunity` repository before installing.
Use `--niri replace` only if you want the bundled Niri configuration (highly recommended).

### Productivity commands

```bash
blackhole help
blackhole version
blackhole update
blackhole restart
blackhole doctor
```

Add `~/.local/bin` to your PATH if your shell cannot find the commands.
The shell is supervised within your Wayland session on both Arch and Obarun.
`blackhole daemon logs` shows its recent log.

### KDE Plasma 6

Tonantzintla also ships as a native **KDE Plasma 6 Global Theme** (Look & Feel, Plasma Style, Dark/Light color schemes, Aurorae window decorations, wallpaper, splash screen, and four native Plasma 6 Plasmoids):

```bash
bin/blackhole plasma install
bin/blackhole plasma apply
```

See [KDE Plasma 6](docs/kde-plasma.md) for `--keep-layout`, `--mode light`, and `sync`.

### Make it yours

Choose your applications, weather location, fonts, and motion in Settings.
Put wallpapers in `~/Pictures/Wallpapers`. Screenshots stay entirely separate.

[Architecture](docs/architecture.md) · [Dependencies](docs/dependencies.md) ·
[KDE Plasma 6](docs/kde-plasma.md) · [Machines](docs/machines.md) · [Umbra](docs/umbra.md) · [Contributing](CONTRIBUTING.md)

GPL-3.0-or-later. Copyright © 2026 deltadasher.
See [LICENSE](LICENSE). Third-party work retains its own attribution and license.
