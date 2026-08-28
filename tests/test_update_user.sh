#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/astralith-update.XXXXXX")"

cleanup() {
    if [[ -n "$test_root" && -d "$test_root" ]]; then
        rm -rf -- "$test_root"
    fi
}
trap cleanup EXIT

runtime="$test_root/runtime"
source_root="$test_root/source"
fake_bin="$test_root/bin"
log="$test_root/update.log"
mkdir -p "$runtime/scripts" "$runtime/.astralith-install" \
    "$source_root/.git" "$source_root/scripts" "$fake_bin"
cp -- "$project_root/scripts/update-user" "$runtime/scripts/update-user"

printf '%s\n' "$source_root" > "$runtime/.astralith-install/source"
printf '%s\n' full > "$runtime/.astralith-install/profile"
printf '%s\n' replace > "$runtime/.astralith-install/niri"
printf '%s\n' greeter-preview > "$runtime/.astralith-install/umbra"

cat > "$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *'status --porcelain' ]]; then
    exit 0
fi
if [[ "$*" == *'pull --ff-only' ]]; then
    printf 'pull:%s\n' "$*" >> "$ASTRALITH_UPDATE_TEST_LOG"
    exit 0
fi
exit 64
EOF

cat > "$fake_bin/qs" <<'EOF'
#!/usr/bin/env sh
exit 0
EOF

cat > "$source_root/scripts/install" <<'EOF'
#!/usr/bin/env bash
printf 'install:' >> "$ASTRALITH_UPDATE_TEST_LOG"
printf ' <%s>' "$@" >> "$ASTRALITH_UPDATE_TEST_LOG"
printf '\n' >> "$ASTRALITH_UPDATE_TEST_LOG"
EOF

chmod +x "$runtime/scripts/update-user" "$fake_bin/git" "$fake_bin/qs" \
    "$source_root/scripts/install"

ASTRALITH_UPDATE_TEST_LOG="$log" \
PATH="$fake_bin:/usr/bin:/bin" \
    "$runtime/scripts/update-user" >/dev/null

grep -Fq "pull:-C $source_root pull --ff-only" "$log"
grep -Fq 'install: <apply> <--profile> <full> <--niri> <replace> <--umbra> <greeter-preview> <--yes>' "$log"
