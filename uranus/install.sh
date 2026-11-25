#!/usr/bin/env bash
# Install Uranus, the KDE Plasma 6 edition of Tonantzintla, for the current user.
#
# This copies a small self-contained runtime (the prebuilt theme and its helper)
# and installs the theme packages. It does not install Quickshell, Niri, or the
# blackhole runtime, needs no root, and builds nothing.

set -euo pipefail

source_root="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/.." && pwd)"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
runtime_root="$data_home/uranus"
bin_dir="${URANUS_BIN_DIR:-$HOME/.local/bin}"
apply=0
link=1
checks=1
apply_arguments=()

usage() {
    cat <<'USAGE'
Usage: uranus/install.sh [OPTIONS]

  --apply             Switch Plasma to the theme once it is installed
  --mode dark|light   Color scheme to apply (with --apply; default dark)
  --keep-layout       Keep your current panels (with --apply)
  --prefix DIR        Install the runtime into DIR instead of ~/.local/share/uranus
  --no-link           Do not create ~/.local/bin/uranus
  --skip-checks       Install even if 'doctor' reports something missing
  -h, --help          Show this help
USAGE
}

fail() {
    printf 'uranus install: %s\n' "$1" >&2
    exit 1
}

while (($#)); do
    case "$1" in
        --apply) apply=1 ;;
        --mode)
            [[ "${2:-}" == "dark" || "${2:-}" == "light" ]] || fail "--mode takes dark or light."
            apply_arguments+=(--mode "$2")
            shift
            ;;
        --keep-layout) apply_arguments+=(--keep-layout) ;;
        --prefix)
            [[ -n "${2:-}" ]] || fail "--prefix takes a directory."
            runtime_root="$2"
            shift
            ;;
        --no-link) link=0 ;;
        --skip-checks) checks=0 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
    shift
done

command -v python3 >/dev/null 2>&1 || fail "python3 is required."
[[ "$runtime_root" == /* ]] || fail "the install location must be an absolute path."
for required in bin/uranus src/libexec/plasma-theme.py src/libexec/plasma_plasmoids.py \
    src/libexec/plasma_shaders.py plasma/look-and-feel/org.tonantzintla.desktop/metadata.json; do
    [[ -f "$source_root/$required" ]] || fail "this checkout is incomplete: $required is missing."
done

if (( checks )); then
    printf 'Checking this machine:\n'
    python3 "$source_root/src/libexec/plasma-theme.py" doctor --human \
        || fail "fix the missing items above, or rerun with --skip-checks."
fi

# An existing directory is only replaced when a previous run of this script made it.
if [[ -e "$runtime_root" && ! -f "$runtime_root/.uranus-runtime" ]]; then
    fail "$runtime_root exists and was not created by this installer. Move it or pick another --prefix."
fi

mkdir -p -- "$(dirname -- "$runtime_root")"
staging="$(mktemp -d -- "$runtime_root.staging.XXXXXX")"
previous=""
cleanup() {
    rm -rf -- "$staging"
    [[ -z "$previous" ]] || rm -rf -- "$previous"
}
trap cleanup EXIT

mkdir -p -- "$staging/bin" "$staging/src/libexec"
cp -- "$source_root/bin/uranus" "$staging/bin/uranus"
chmod 755 -- "$staging/bin/uranus"
cp -- "$source_root/src/libexec/plasma-theme.py" "$source_root/src/libexec/plasma_plasmoids.py" \
    "$source_root/src/libexec/plasma_shaders.py" "$staging/src/libexec/"
cp -R -- "$source_root/plasma" "$staging/plasma"
for extra in LICENSE VERSION; do
    [[ ! -f "$source_root/$extra" ]] || cp -- "$source_root/$extra" "$staging/$extra"
done
printf 'Created by uranus/install.sh. Safe to remove with: uranus uninstall --purge\n' > "$staging/.uranus-runtime"

if [[ -e "$runtime_root" ]]; then
    previous="$runtime_root.previous.$$"
    mv -- "$runtime_root" "$previous"
fi
if ! mv -- "$staging" "$runtime_root"; then
    [[ -z "$previous" ]] || mv -- "$previous" "$runtime_root"
    previous=""
    fail "could not move the runtime into place."
fi
printf 'Runtime installed in %s.\n' "$runtime_root"

if (( link )); then
    target="$bin_dir/uranus"
    if [[ -e "$target" && ! -L "$target" ]]; then
        printf 'Left %s alone because it is not a link this installer made. Run %s/bin/uranus directly.\n' "$target" "$runtime_root" >&2
    else
        mkdir -p -- "$bin_dir"
        ln -sfn -- "$runtime_root/bin/uranus" "$target"
        case ":$PATH:" in
            *":$bin_dir:"*) ;;
            *) printf 'Add %s to your PATH to run "uranus" by name.\n' "$bin_dir" ;;
        esac
    fi
fi

"$runtime_root/bin/uranus" install

if (( apply )); then
    "$runtime_root/bin/uranus" apply "${apply_arguments[@]}"
else
    printf '\nNothing on your desktop has changed yet. When you are ready:\n'
    printf '  uranus apply                 the full look, with the top bar and dock (your panels are saved first)\n'
    printf '  uranus apply --keep-layout   colors, style, and windows only\n'
fi
