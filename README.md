# TONANTZINTLA

![Tonantzintla black hole](src/assets/illustrations/wabi-sabi-black-hole.svg)

## Tonantzintla 1.2

Built with Quickshell for Niri & Hyprland (to be extended to other wayland compositors in the near future).
Extended distro compatibility: Arch, similar derivatives, Fedora, Debian.
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
sudo [insert package manager installation command] --needed git rust
git clone https://github.com/deltadasher/Tonantzintla.git Tonantzintla
cd Tonantzintla
bin/blackhole install --profile recommended --niri keep --umbra lock --yes
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

### Make it yours

Choose your applications, weather location, fonts, and motion in Settings.
Put wallpapers in `~/Pictures/Wallpapers`. Screenshots stay entirely separate.

[Architecture](docs/architecture.md) · [Dependencies](docs/dependencies.md) ·
[Machines](docs/machines.md) · [Umbra](docs/umbra.md) · [Contributing](CONTRIBUTING.md)

GPL-3.0-or-later. Copyright © 2026 deltadasher.
See [LICENSE](LICENSE). Third-party work retains its own attribution and license.
