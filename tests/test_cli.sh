#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/astralith-cli.XXXXXX")"

cleanup() {
    if [[ -n "$test_root" && -d "$test_root" ]]; then
        rm -rf -- "$test_root"
    fi
}
trap cleanup EXIT

[[ "$("$project_root/scripts/astralithctl" path)" == "$project_root" ]]
"$project_root/scripts/astralithctl" help | grep -q 'Usage: astralithctl'
"$project_root/scripts/astralithctl" help | grep -q 'doctor'
"$project_root/scripts/astralithctl" help | grep -q 'profile'
"$project_root/scripts/astralithctl" help | grep -q 'update'
"$project_root/scripts/astralithctl" help | grep -q 'greeter'
"$project_root/scripts/umbra-greeter" help | grep -q 'preview'
"$project_root/scripts/umbra-greeter-portable" help | grep -q 'LightDM'
[[ "$("$project_root/scripts/astralithctl" version)" == "$(<"$project_root/VERSION")" ]]

if "$project_root/scripts/astralithctl" definitely-not-a-command >/dev/null 2>&1; then
    printf 'astralithctl accepted an invalid command.\n' >&2
    exit 1
fi

HOME="$test_root/home" \
XDG_CONFIG_HOME="$test_root/config" \
    "$project_root/scripts/install-user" >/dev/null

[[ "$(readlink -f -- "$test_root/config/quickshell/astralith")" == "$project_root" ]]
[[ "$(readlink -f -- "$test_root/home/.local/bin/astralithctl")" == "$project_root/scripts/astralithctl" ]]

if grep -Eq 'spawn(-at-startup)? "astralithctl"' "$project_root/niri/config.kdl"; then
    printf 'Niri config relies on session PATH for astralithctl.\n' >&2
    exit 1
fi
grep -Fq 'spawn-at-startup "~/.local/bin/astralithctl" "session-start"' "$project_root/niri/config.kdl"
grep -Fq 'Mod+D             { spawn "~/.local/bin/astralithctl" "toggle" "apps"; }' "$project_root/niri/config.kdl"

HOME="$test_root/home" \
XDG_CONFIG_HOME="$test_root/config" \
    "$project_root/scripts/uninstall-user" >/dev/null

[[ ! -e "$test_root/config/quickshell/astralith" ]]
[[ ! -e "$test_root/home/.local/bin/astralithctl" ]]
