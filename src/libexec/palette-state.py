#!/usr/bin/env python3
"""Generate and cache an Tonantzintla Matugen palette for an image or video."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import time


VIDEO_SUFFIXES = {".mp4", ".mkv", ".mov", ".webm", ".avi", ".m4v"}


def cache_root() -> Path:
    return Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "tonantzintla"


def cached_palette() -> Path:
    return cache_root() / "palette.json"


def read_cached() -> dict[str, object]:
    try:
        return json.loads(cached_palette().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"ok": False, "error": "No cached spectrum"}


def matugen_source(path: Path) -> Path:
    if path.suffix.lower() not in VIDEO_SUFFIXES:
        return path
    frame = cache_root() / "palette-frame.jpg"
    frame.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", "3", "-i", str(path),
         "-frames:v", "1", "-vf", "scale=960:-2", str(frame)],
        capture_output=True,
        text=True,
        timeout=20,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "Unable to sample video frame")
    return frame


def generate(path: Path) -> dict[str, object]:
    if not shutil.which("matugen"):
        return {"ok": False, "error": "Matugen is not installed"}
    if not path.is_file():
        return {"ok": False, "error": "Wallpaper source is missing", "source": str(path)}
    try:
        source = matugen_source(path)
        result = subprocess.run(
            ["matugen", "image", str(source), "--dry-run", "--json", "hex", "--mode", "dark",
             "--type", "scheme-tonal-spot", "--source-color-index", "0"],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or "Matugen exited unsuccessfully")
        palette = json.loads(result.stdout)
        payload: dict[str, object] = {
            "ok": True,
            "source": str(path),
            "sample": str(source),
            "generatedAt": int(time.time()),
            "palette": palette,
        }
        cache_root().mkdir(parents=True, exist_ok=True)
        temp = cached_palette().with_suffix(".tmp")
        temp.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
        temp.replace(cached_palette())
        return payload
    except (OSError, subprocess.TimeoutExpired, RuntimeError, json.JSONDecodeError) as error:
        return {"ok": False, "error": str(error), "source": str(path)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", nargs="?")
    parser.add_argument("--cached", action="store_true")
    args = parser.parse_args()
    payload = read_cached() if args.cached else generate(Path(args.source or ""))
    print(json.dumps(payload, separators=(",", ":")))
    if not payload.get("ok"):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
