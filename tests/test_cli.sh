#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/tonantzintla-cli.XXXXXX")"

cleanup() {
    if [[ -n "$test_root" && -d "$test_root" ]]; then
        rm -rf -- "$test_root"
    fi
}
trap cleanup EXIT

[[ "$("$project_root/bin/blackhole" path)" == "$project_root" ]]
"$project_root/bin/blackhole" help | grep -q 'Usage: blackhole'
"$project_root/bin/blackhole" help | grep -q 'doctor'
"$project_root/bin/blackhole" help | grep -q 'install'
"$project_root/bin/blackhole" help | grep -q 'profile'
"$project_root/bin/blackhole" help | grep -q 'update'
"$project_root/bin/blackhole" help | grep -q 'greeter'
"$project_root/bin/blackhole" help | grep -q 'terminal'
"$project_root/bin/blackhole" help | grep -q 'browser'
"$project_root/bin/blackhole" help | grep -q 'files'
"$project_root/bin/blackhole" obarun-audit --help | grep -q 'read-only Obarun'
"$project_root/src/libexec/umbra-greeter" help | grep -q 'preview'
"$project_root/src/libexec/umbra-greeter-portable" help | grep -q 'LightDM'
version_output="$("$project_root/bin/blackhole" version)"
[[ "${version_output%%$'\n'*}" == "$(<"$project_root/VERSION")" ]]

if "$project_root/bin/blackhole" definitely-not-a-command >/dev/null 2>&1; then
    printf 'blackhole accepted an invalid command.\n' >&2
    exit 1
fi

# Linking is the installer's job. blackhole must not carry a second
# implementation, and no user-facing scripts/ directory may come back.
if [[ -d "$project_root/scripts" ]]; then
    printf 'scripts/ was reintroduced; blackhole is the only command.\n' >&2
    exit 1
fi

grep -Fq 'spawn-at-startup "sh" "-lc" "exec \"$HOME/.local/bin/blackhole\" session-start"' "$project_root/compositors/niri/config.kdl"
grep -Fq 'spawn-at-startup "sh" "-lc" "exec \"$HOME/.local/bin/blackhole\" session-environment"' "$project_root/compositors/niri/config.kdl"
grep -Fq 'Mod+D             { spawn "sh" "-lc" "exec \"$HOME/.local/bin/blackhole\" toggle apps"; }' "$project_root/compositors/niri/config.kdl"

fake_bin="$test_root/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/qs" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-p" && "${3:-}" == "list" ]]; then
    exit 0
fi
if [[ "${1:-}" == "list" && "${2:-}" == "--all" ]]; then
    printf 'Instance dev-instance:\n  Config path: /tmp/dev/tonantzintla/shell.qml\n'
    exit 0
fi
printf '%s\n' "$*" >"$QS_CAPTURE"
EOF
chmod +x "$fake_bin/qs"

QS_CAPTURE="$test_root/notify-call" PATH="$fake_bin:$PATH" \
    "$project_root/bin/blackhole" notify "Hello" "World"
[[ "$(<"$test_root/notify-call")" == "-p $project_root/src/quickshell ipc call transit preview Hello World" ]]

cat >"$fake_bin/xdg-terminal-exec" <<'EOF'
#!/usr/bin/env bash
printf 'terminal\n' >"$LAUNCH_CAPTURE"
EOF
cat >"$fake_bin/xdg-open" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$LAUNCH_CAPTURE"
EOF
chmod +x "$fake_bin/xdg-terminal-exec" "$fake_bin/xdg-open"

LAUNCH_CAPTURE="$test_root/terminal-launch" HOME="$test_root/home" \
XDG_CONFIG_HOME="$test_root/config" PATH="$fake_bin:$PATH" \
    "$project_root/bin/blackhole" terminal
[[ "$(<"$test_root/terminal-launch")" == "terminal" ]]

LAUNCH_CAPTURE="$test_root/browser-launch" HOME="$test_root/home" \
XDG_CONFIG_HOME="$test_root/config" PATH="$fake_bin:$PATH" \
    "$project_root/bin/blackhole" browser
[[ "$(<"$test_root/browser-launch")" == "about:blank" ]]

LAUNCH_CAPTURE="$test_root/files-launch" HOME="$test_root/home" \
XDG_CONFIG_HOME="$test_root/config" PATH="$fake_bin:$PATH" \
    "$project_root/bin/blackhole" files
[[ "$(<"$test_root/files-launch")" == "$test_root/home" ]]

cat >"$fake_bin/dbus-update-activation-environment" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$DBUS_CAPTURE"
EOF
cat >"$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
exit "${SYSTEMCTL_STATUS:-0}"
EOF
chmod +x "$fake_bin/dbus-update-activation-environment" "$fake_bin/systemctl"

DBUS_CAPTURE="$test_root/dbus-systemd" PATH="$fake_bin:$PATH" \
    "$project_root/bin/blackhole" session-environment
[[ "$(<"$test_root/dbus-systemd")" == "--systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS DISPLAY" ]]

DBUS_CAPTURE="$test_root/dbus-standalone" SYSTEMCTL_STATUS=1 PATH="$fake_bin:$PATH" \
    "$project_root/bin/blackhole" session-environment
[[ "$(<"$test_root/dbus-standalone")" == "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS DISPLAY" ]]

mkdir -p "$test_root/proc/1"
printf 's6-svscan\n' >"$test_root/proc/1/comm"
cat >"$test_root/os-release" <<'EOF'
NAME=Obarun
ID=obarun
ID_LIKE=arch
PRETTY_NAME=Obarun
EOF
cat >"$fake_bin/66" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    version) printf '66 version 0.test\n' ;;
    tree) printf 'Name: session\n' ;;
    status) printf 'tonantzintla: not registered\n' ;;
esac
EOF
chmod +x "$fake_bin/66"
audit_output="$(
    TONANTZINTLA_OS_RELEASE="$test_root/os-release" \
    TONANTZINTLA_PROC_ROOT="$test_root/proc" \
    TONANTZINTLA_AUDIT_SKIP_INSTALLER=1 \
    PATH="$fake_bin:$PATH" \
        "$project_root/bin/blackhole" obarun-audit
)"
grep -q 'ID:                      obarun' <<<"$audit_output"
grep -q 'PID 1 command:           s6-svscan' <<<"$audit_output"
grep -q '66 version 0.test' <<<"$audit_output"
grep -q 'This command made no system changes' <<<"$audit_output"

QS_CAPTURE="$test_root/ipc-call" PATH="$fake_bin:$PATH" \
    "$project_root/bin/blackhole" toggle apps
[[ "$(<"$test_root/ipc-call")" == "ipc -i dev-instance call ephemeris toggle apps" ]]

# Removal is a subcommand of the installer, surfaced through the one CLI.
"$project_root/bin/blackhole" help | grep -q 'uninstall'
