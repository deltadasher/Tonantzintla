# Niri ownership and Shellswitch handoff

Tonantzintla treats `~/.config/niri/config.kdl` as a shared compositor
entrypoint, not as a file it may silently reclaim. The ownership ledger lives
at `$XDG_STATE_HOME/tonantzintla/niri-ownership/state.json` (or
`~/.local/state/...`) and keeps a hash, active shell, and verified rollback
snapshots under `snapshots/`.

## Contract

Shellswitch must announce an intentional transition before changing the Niri
entrypoint:

```sh
blackhole niri handoff serpantinum
# Shellswitch writes its validated config and starts Serpantinum.
blackhole niri accept serpantinum
```

To return control:

```sh
blackhole niri handoff tonantzintla
# Shellswitch writes/activates Tonantzintla's validated config.
blackhole niri accept tonantzintla
blackhole start
```

The handoff record is consumed by detection only when the observed config is
identified as the requested target shell. A random overwrite does not satisfy
the contract. `accept` is the explicit acknowledgement step and validates the
current file before recording its hash.

## Recovery actions

```sh
blackhole niri status    # JSON inspection: hash, detected shell, reasons
blackhole niri restore   # staged validate, atomic restore of last-good config
blackhole niri disable   # stop only Tonantzintla and block its future starts
blackhole niri enable    # explicit intent to return to Tonantzintla
```

The supervisor checks ownership before every Quickshell spawn, so a crashed
child cannot resurrect the shell after `disable` or an unexpected foreign
overwrite. The guard never kills Serpantinum, Quickshell instances belonging to
another checkout, Kitty, or unrelated applications. It only stops the
Tonantzintla supervisor when `disable` was explicitly requested.

Detection distinguishes:

- unchanged or explicitly handed-off configuration;
- a user edit (reported, never rewritten automatically);
- an unexpected Serpantinum/foreign overwrite (blocked with inspect/accept/
  restore actions);
- a missing or invalid configuration (blocked until repaired).

Installer-managed replacement validates the candidate first and records a
verified versioned snapshot of the existing Niri file before replacing it. The
transaction journal remains the immediate installer rollback path; the
ownership snapshot is the durable user-facing recovery path.
