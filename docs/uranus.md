# Uranus

Uranus is Tonantzintla for people who run KDE Plasma and want to keep running it.
It installs the Plasma theme on its own: no Quickshell, no Niri, no `blackhole`
runtime, no root, nothing to compile.

You get the Global Theme, the Plasma Style, dark and light color schemes with
matching window decorations, the wallpaper, the splash screen, and five panel
widgets: the Event Horizon launcher, workspaces, media, clock and calendar, and
audio and battery status.

## Requirements

- KDE Plasma 6.3 or newer
- Python 3
- JetBrains Mono is the theme's typeface. Without it the widgets use your
  fixed-width font instead.

## Install

```bash
git clone --branch Uranus https://github.com/deltadasher/Tonantzintla.git
cd Tonantzintla
uranus/install.sh
```

The installer checks the machine, copies a small runtime to
`~/.local/share/uranus`, links `~/.local/bin/uranus`, and installs the theme
packages for your user. Your desktop does not change until you apply the theme.

```bash
uranus apply                 # the full look: top bar and dock
uranus apply --keep-layout   # colors, style and windows; your panels stay
uranus apply --mode light    # light windows with light title bars
```

`uranus/install.sh --apply` does both steps at once.

## Your panels are saved first

The full look replaces your panels. Before it does, `uranus apply` copies your
current layout to `~/.local/state/tonantzintla/plasma-layouts`, keeping the last
five. To go back:

```bash
uranus restore-layout
```

## Commands

| Command | What it does |
| --- | --- |
| `uranus doctor` | Checks Plasma, the apply tools, and the font |
| `uranus install` | Installs or refreshes the theme packages |
| `uranus apply` | Switches Plasma to the theme |
| `uranus sync` | Rebuilds the colors from a Tonantzintla palette, if you have one |
| `uranus restore-layout` | Brings back the panels saved by the last apply |
| `uranus status` | Shows what is installed |
| `uranus uninstall` | Removes the theme and hands Plasma back to Breeze |
| `uranus uninstall --purge` | Also removes Uranus itself |

Add `--json` to any command for machine-readable output.

Everything is also in **System Settings → Colors & Themes** once installed.
Applying from there works, with one difference: window borders may be 4px
instead of a hairline, because only `uranus apply` sets the border size to Tiny.

## Uranus and the full desktop

Uranus and the Quickshell desktop install the same Plasma packages, so they can
share a machine. `blackhole plasma` and `uranus` are two front ends to the same
helper. Removing one does not remove the other's runtime.
