# Contributing to Tonantzintla

Tonantzintla is now open to contribution!

## Workflow

1. Start from a clean `main` checkout.
2. Create a focused branch for risky work.
3. Keep service, component, and surface changes in separate commits when
   practical.
4. Run `./tools/check`.
5. Confirm the live log ends in `Configuration Loaded` without a new warning.
6. Manually test open, close, keyboard focus, and the affected backend.
7. Commit only after the working state is reproducible.

Do not combine a layer-shell geometry rewrite with unrelated styling or service
polling changes. Prototype geometry and animation experiments outside the live
`EphemerisSurface.qml` first. This has been a known struggle with others who have attempted to commit.

## Commit style

I don't really care about how you write the commits. Just a small summary of what you're adding so I don't have
to read through your changes for context.

## Publication and provenance

Tonantzintla is licensed under GPL-3.0-or-later. New third-party material must
arrive with explicit source, copyright, and license records.

### Packaging an installer binary

Build from the checkout root. Cargo can include local paths in dependency panic
messages even when a release binary is stripped. The following Bash command
remaps the build directories before compiling the installer for distribution.
It preserves spaces in path names.

```bash
(
    flags=(
        "--remap-path-prefix=${HOME}=/build/home"
        "--remap-path-prefix=${PWD}=/build/tonantzintla"
        "--remap-path-prefix=${CARGO_HOME:-$HOME/.cargo}=/build/cargo"
        "--remap-path-prefix=${CARGO_TARGET_DIR:-$PWD/install/target}=/build/target"
    )
    IFS=$'\x1f'
    export CARGO_ENCODED_RUSTFLAGS="${flags[*]}"
    cargo build --release --locked --manifest-path install/Cargo.toml
)
```

The installer finds the checkout containing its executable or working directory.
Pass `--source /path/to/Tonantzintla` when distributing the binary separately.
