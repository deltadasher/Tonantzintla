#!/usr/bin/env python3
"""Transactional Niri entrypoint ownership guard for Tonantzintla.

This helper never rewrites a configuration as part of detection.  It records
hashes, verified snapshots, and explicit Shellswitch handoff intent so an
unexpected competing shell is visible and recoverable instead of becoming a
rewrite loop.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path


SHELL = "tonantzintla"
FOREIGN = ("serpantinum", "serpantinumd")
SCHEMA = 1


def config_path(value: str | None = None) -> Path:
    if value:
        return Path(value).expanduser().resolve()
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return (config_home / "niri/config.kdl").resolve()


def state_root() -> Path:
    return Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "tonantzintla/niri-ownership"


def state_path() -> Path:
    return state_root() / "state.json"


def load() -> dict:
    try:
        value = json.loads(state_path().read_text(encoding="utf-8"))
        if isinstance(value, dict) and value.get("schema") == SCHEMA:
            return value
    except (OSError, ValueError, TypeError):
        pass
    return {
        "schema": SCHEMA,
        "active_shell": SHELL,
        "authorized_hash": None,
        "last_good_snapshot": None,
        "snapshots": [],
        "disabled": False,
        "handoff": None,
        "last_warning_hash": None,
        "config_path": str(config_path()),
    }


def save(value: dict) -> None:
    root = state_root()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = state_path().with_suffix(".json.tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.chmod(temporary, 0o600)
    os.replace(temporary, state_path())


def digest(path: Path) -> str | None:
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None


def tracked_files(path: Path) -> list[Path]:
    """Return the entrypoint plus readable local include targets."""
    result: list[Path] = []
    queue = [path]
    seen: set[Path] = set()
    while queue:
        current = queue.pop(0).resolve()
        if current in seen or not current.is_file():
            continue
        seen.add(current)
        result.append(current)
        try:
            text = current.read_text(encoding="utf-8")
        except OSError:
            continue
        for match in re.finditer(r"^\s*include(?:\s+optional)?\s+\"([^\"]+)\"", text, re.MULTILINE):
            include = Path(match.group(1)).expanduser()
            if not include.is_absolute():
                include = current.parent / include
            queue.append(include)
    return result


def fingerprint(path: Path) -> str | None:
    files = tracked_files(path)
    if not files:
        return None
    hasher = hashlib.sha256()
    for current in files:
        value = digest(current)
        if value is None:
            continue
        hasher.update(str(current).encode())
        hasher.update(value.encode())
    return hasher.hexdigest()


def classify(path: Path) -> tuple[str, list[str]]:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return "missing", []
    lowered = text.casefold()
    reasons: list[str] = []
    all_text = lowered
    for included in tracked_files(path)[1:]:
        try:
            all_text += "\n" + included.read_text(encoding="utf-8").casefold()
        except OSError:
            pass
    if re.search(r"serpantinumd|serpantinum", all_text):
        reasons.append("Serpantinum include, autostart, or binding")
        return "serpantinum", reasons
    if re.search(r"tonantzintla|blackhole", all_text):
        reasons.append("Tonantzintla entrypoint or binding")
        return SHELL, reasons
    if re.search(r"^\s*include\b|spawn-at-startup|binds\s*\{", text, re.MULTILINE):
        reasons.append("Niri include, autostart, or binding changed")
    return "unknown", reasons


def validate(path: Path) -> tuple[bool, str]:
    niri = shutil.which("niri")
    if not niri:
        return False, "niri is unavailable; refusing to call a snapshot verified"
    result = subprocess.run([niri, "validate", "-c", str(path)], capture_output=True, text=True, timeout=15)
    if result.returncode:
        return False, (result.stderr or result.stdout).strip() or "niri validate failed"
    return True, (result.stdout or "validated").strip()


def snapshot(state: dict, path: Path, label: str) -> dict:
    current_hash = digest(path)
    current_fingerprint = fingerprint(path)
    if current_hash is None or current_fingerprint is None:
        return {"ok": False, "message": f"Niri config does not exist: {path}"}
    valid, detail = validate(path)
    if not valid:
        return {"ok": False, "message": detail}
    shell, reasons = classify(path)
    stamp = time.strftime("%Y%m%d_%H%M%S", time.localtime())
    destination = state_root() / "snapshots" / f"{stamp}_{current_hash[:12]}_{label}.kdl"
    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    shutil.copy2(path, destination)
    record = {
        "path": str(destination), "hash": current_hash, "fingerprint": current_fingerprint, "shell": shell,
        "label": label, "verified": True, "created": int(time.time()),
        "reasons": reasons,
    }
    state.setdefault("snapshots", []).append(record)
    state["snapshots"] = state["snapshots"][-20:]
    # A foreign shell is preserved as evidence, never promoted to our rollback.
    if shell in (SHELL, "unknown") and state.get("active_shell", SHELL) == SHELL:
        state["last_good_snapshot"] = record
    save(state)
    return {"ok": True, "snapshot": record, "message": f"Verified snapshot: {destination}"}


def inspection(state: dict, path: Path) -> dict:
    current = fingerprint(path)
    shell, reasons = classify(path)
    authorized = state.get("authorized_hash")
    handoff = state.get("handoff")
    if current is None:
        classification = "missing"
    elif authorized is None:
        classification = "uninitialized"
    elif current == authorized:
        classification = "unchanged"
    elif handoff and shell == handoff.get("target"):
        classification = "intentional-switch"
    elif shell == "serpantinum":
        classification = "unexpected-overwrite"
    elif shell == SHELL:
        classification = "user-edit"
    else:
        classification = "user-edit"
    return {
        "config": str(path), "hash": current, "authorized_hash": authorized,
        "active_shell": state.get("active_shell", SHELL), "detected_shell": shell,
        "classification": classification, "reasons": reasons,
        "disabled": bool(state.get("disabled")), "handoff": handoff,
        "last_good_snapshot": state.get("last_good_snapshot"),
    }


def warning(info: dict) -> str:
    actions = "inspect with 'blackhole niri status', accept with 'blackhole niri accept', or restore with 'blackhole niri restore'"
    return (f"Niri configuration changed unexpectedly: {info['config']}\n"
            f"  active shell: {info['active_shell']}; detected: {info['detected_shell']}\n"
            f"  reason: {', '.join(info['reasons']) or 'entrypoint contents differ'}\n"
            f"  action: {actions}")


def cmd_inspect(args: argparse.Namespace) -> int:
    state = load()
    path = config_path(args.config)
    info = inspection(state, path)
    if info["classification"] == "unexpected-overwrite":
        if state.get("last_warning_hash") != info.get("hash"):
            state["last_warning_hash"] = info.get("hash")
            save(state)
    print(json.dumps(info, indent=2, sort_keys=True))
    return 0


def cmd_check(args: argparse.Namespace) -> int:
    state = load()
    path = config_path(args.config)
    info = inspection(state, path)
    if info["classification"] == "unexpected-overwrite":
        if state.get("last_warning_hash") != info.get("hash"):
            state["last_warning_hash"] = info.get("hash")
            save(state)
            print(warning(info), file=os.sys.stderr)
        return 3
    if info["classification"] == "missing":
        print(warning(info), file=os.sys.stderr)
        return 3
    if info["classification"] == "user-edit" and not args.quiet:
        print("Niri configuration changed by the user; no Tonantzintla rewrite was attempted.", file=os.sys.stderr)
    if state.get("disabled"):
        if not args.quiet:
            print("Tonantzintla is disabled until an explicit shell switch.", file=os.sys.stderr)
        return 4
    return 0


def cmd_accept(args: argparse.Namespace) -> int:
    state = load()
    path = config_path(args.config)
    valid, detail = validate(path)
    if not valid:
        print(f"Cannot accept Niri configuration: {detail}", file=os.sys.stderr)
        return 1
    shell = args.shell or classify(path)[0]
    state.update({"authorized_hash": fingerprint(path), "active_shell": shell,
                  "handoff": None, "disabled": shell != SHELL,
                  "last_warning_hash": None, "config_path": str(path)})
    result = snapshot(state, path, "accepted")
    if not result["ok"]:
        return 1
    print(f"Accepted {shell} as the active Niri shell.")
    return 0


def cmd_handoff(args: argparse.Namespace) -> int:
    if args.shell not in (SHELL, "serpantinum"):
        print("Supported handoff shells: tonantzintla, serpantinum", file=os.sys.stderr)
        return 2
    state = load()
    path = config_path(args.config)
    state["handoff"] = {"target": args.shell, "created": int(time.time())}
    state["disabled"] = args.shell != SHELL
    state["config_path"] = str(path)
    save(state)
    print(f"Shellswitch handoff authorized for {args.shell}.")
    return 0


def cmd_disabled(args: argparse.Namespace) -> int:
    state = load()
    state["disabled"] = args.action == "disable"
    if args.action == "enable":
        state["handoff"] = {"target": SHELL, "created": int(time.time())}
    save(state)
    print("Tonantzintla start/resurrection is " + ("disabled." if state["disabled"] else "enabled."))
    return 0


def cmd_snapshot(args: argparse.Namespace) -> int:
    result = snapshot(load(), config_path(args.config), args.label)
    print(result["message"], file=os.sys.stderr if not result["ok"] else os.sys.stdout)
    return 0 if result["ok"] else 1


def cmd_restore(args: argparse.Namespace) -> int:
    state = load()
    record = state.get("last_good_snapshot")
    if not record or not record.get("verified"):
        print("No verified Tonantzintla snapshot is available.", file=os.sys.stderr)
        return 1
    source = Path(record["path"])
    target = config_path(args.config)
    if digest(source) != record.get("hash"):
        print("The recorded snapshot was modified; refusing restoration.", file=os.sys.stderr)
        return 1
    valid, detail = validate(source)
    if not valid:
        print(f"Snapshot no longer validates: {detail}", file=os.sys.stderr)
        return 1
    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("wb", dir=target.parent, prefix=".tonantzintla-restore-", delete=False) as staged:
        staged_path = Path(staged.name)
        staged.write_bytes(source.read_bytes())
    try:
        valid, detail = validate(staged_path)
        if not valid:
            print(f"Staged restoration failed validation: {detail}", file=os.sys.stderr)
            return 1
        os.replace(staged_path, target)
    finally:
        staged_path.unlink(missing_ok=True)
    state.update({"authorized_hash": fingerprint(target), "active_shell": SHELL,
                  "handoff": None, "disabled": False, "last_warning_hash": None})
    save(state)
    print(f"Restored verified Tonantzintla configuration from {source}.")
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    root.add_argument("action", choices=("inspect", "check", "accept", "handoff", "disable", "enable", "snapshot", "restore"))
    root.add_argument("--config")
    root.add_argument("--shell")
    root.add_argument("--label", default="manual")
    root.add_argument("--quiet", action="store_true")
    return root


def main() -> int:
    args = parser().parse_args()
    if args.action == "inspect": return cmd_inspect(args)
    if args.action == "check": return cmd_check(args)
    if args.action == "accept": return cmd_accept(args)
    if args.action == "handoff": return cmd_handoff(args)
    if args.action in ("disable", "enable"):
        args.action = args.action
        return cmd_disabled(args)
    if args.action == "snapshot": return cmd_snapshot(args)
    if args.action == "restore": return cmd_restore(args)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
