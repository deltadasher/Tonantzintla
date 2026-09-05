# Using Tonantzintla on multiple machines

Tonantzintla separates shared source from local machine state. The Git checkout is
portable; monitor names, hardware capabilities, personal settings, downloaded
wallpapers, and caches are not committed.

## What Git synchronizes

- QML source and motion behavior
- default settings and theme tokens
- original bundled assets
- internal helpers and validation
- the portable Niri starting configuration
- documentation and tests

## What stays local

| State | Default location |
| --- | --- |
| Tonantzintla settings | `$XDG_CONFIG_HOME/tonantzintla/settings.json` |
| Focus history | `$XDG_CONFIG_HOME/tonantzintla/focus.json` |
| Palette and helper caches | `$XDG_CACHE_HOME/tonantzintla/` |
| Wallpaper stills | `~/Pictures/Wallpapers/Tonantzintla/Stills/` |
| Video wallpapers | `~/Pictures/Wallpapers/Tonantzintla/Videos/` |
| Screenshots | `~/Pictures/Screenshots/` |
| Niri's active configuration | `$XDG_CONFIG_HOME/niri/config.kdl` |

The precise location falls back to `~/.config` or `~/.cache` when the matching
XDG variable is unset.

## First installation

```bash
git clone git@github.com:deltadasher/Tonantzintla.git
cd Tonantzintla
./bin/blackhole doctor
./bin/blackhole install
```

### Bringing a second machine onto a work branch

On Arch and its derivatives, `blackhole install` plans the transaction,
installs the packages each selected capability needs, stages the runtime, and
links it. Contributor tooling (`cargo`, `qmllint` from `qt6-declarative`) is not
part of the runtime; install it separately to run `./tools/check`:

```bash
git clone git@github.com:deltadasher/Tonantzintla.git
cd Tonantzintla
git switch 1.0-RC
./bin/blackhole install
```

Machine state is local, so a second machine starts with default settings and an
empty wallpaper library. Nothing needs to be copied across; only the checkout
is shared.

To validate a branch without installing it, run the checks alone:

```bash
./tools/check             # everything; fails listing any missing tool
./tools/check --partial   # run what this machine has, naming what it skipped
```

`--partial` exists for machines that cannot run the whole suite. It is not a
release gate: a branch is only validated once plain `./tools/check` passes on
a machine with `qmllint`, `cargo`, and `niri` present.

Review the doctor output before installing optional packages. A desktop without
a backlight, battery, Bluetooth adapter, or power-profile service is valid; its
corresponding widgets simply remain unavailable.

Run Tonantzintla from a terminal once before enabling Niri autostart:

```bash
~/.local/bin/blackhole run
```

After the bar and widgets load cleanly, install the Niri configuration or add
this line to the machine's existing config:

```kdl
spawn-at-startup "sh" "-lc" "exec \"$HOME/.local/bin/blackhole\" session-start"
```

Use the explicit installed path in Niri bindings too. Display-manager sessions
do not consistently inherit `~/.local/bin` in `PATH`; invoking a shell lets
`$HOME` resolve reliably without depending on tilde expansion.

## Monitor configuration

The bundled Niri config has no explicit `output` blocks. Niri automatically
selects safe modes on unfamiliar hardware. If a machine needs rotation, scale,
or a fixed mode, obtain the exact connector and mode strings with:

```bash
niri msg outputs
```

Put those output blocks only in that machine's active Niri configuration unless
every Tonantzintla machine shares the same hardware.

## Settings strategy

Use Observatory Settings for normal preferences. Keep `Settings.qml` defaults
conservative and portable; do not encode one monitor, hostname, username, or
home directory into source.

If you want identical preferences everywhere, copy
`~/.config/tonantzintla/settings.json` between machines after Tonantzintla has been
installed. Do not commit it: local application paths and future hardware flags
may diverge.

## Updating

```bash
~/.local/bin/blackhole update
```

The updater requires a clean checkout, pulls with `--ff-only`, validates the new
source, and restarts only a running shell. This prevents a failed update from
silently replacing the working process.

Before a large visual or architectural change, create a branch and preserve the
known-good machine:

```bash
git switch -c experiment/name
```

Merge the branch into `main` only after `./tools/check` and live testing pass.

## Removing the user install

```bash
~/.local/bin/blackhole uninstall
```

The uninstaller removes only symlinks that point into the current checkout. It
preserves unrelated files, settings, caches, screenshots, and wallpapers.
