#!/usr/bin/env python3
"""Generate and cache a Tonantzintla Matugen palette for an image or video."""

from __future__ import annotations

import argparse
import hashlib
import re
import signal
import tempfile
import json
import os
from pathlib import Path
import shutil
import subprocess
import time


VIDEO_SUFFIXES = {".mp4", ".mkv", ".mov", ".webm", ".avi", ".m4v"}


def cache_root() -> Path:
    return Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "tonantzintla"


def cached_palette(mode: str = "dark") -> Path:
    return cache_root() / ("palette.json" if mode == "dark" else "palette-light.json")


def read_cached(mode: str = "dark") -> dict[str, object]:
    try:
        payload = json.loads(cached_palette(mode).read_text(encoding="utf-8"))
        if isinstance(payload, dict) and payload.get("ok") is True:
            preserve_source_accent(payload.get("palette"), payload.get("seed", ""))
        return payload
    except (OSError, json.JSONDecodeError):
        return {"ok": False, "error": "No cached spectrum"}



def preserve_source_accent(palette: object, seed: str) -> object:
    """Adapt Matugen's tonal primary to an explicitly selected shell accent.

    Automatic wallpaper generation keeps Material's derived primary. Explicit
    choices keep their exact RGB values; only the primary/foreground pair is
    adapted, leaving Matugen's supporting palette intact.
    """
    if not isinstance(seed, str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", seed):
        return palette
    colors = palette.get("colors") if isinstance(palette, dict) else None
    primary = colors.get("primary") if isinstance(colors, dict) else None
    if not isinstance(primary, dict):
        return palette
    seed = seed.lower()
    channels = [int(seed[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in channels]
    luminance = sum(c * weight for c, weight in zip(linear, (.2126, .7152, .0722)))
    ink = "#000000" if (luminance + .05) / .05 >= 1.05 / (luminance + .05) else "#ffffff"
    for variant in ("dark", "light", "default"):
        entry = primary.get(variant)
        if not isinstance(entry, dict) or not re.fullmatch(r"#[0-9a-fA-F]{6}", str(entry.get("color", ""))):
            continue
        entry["color"] = seed
        foreground = colors.setdefault("on_primary", {})
        if isinstance(foreground, dict):
            foreground[variant] = {"color": ink}
    return palette


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


def generate(path: Path, seed: str = "", mode: str = "dark") -> dict[str, object]:
    if mode not in {"dark", "light"}:
        return {"ok": False, "error": "Invalid theme mode"}
    if not shutil.which("matugen"):
        return {"ok": False, "error": "Matugen is not installed"}
    if seed and not re.fullmatch(r"#[0-9a-fA-F]{6}", seed):
        return {"ok": False, "error": "Invalid source color"}
    if not seed and not path.is_file():
        return {"ok": False, "error": "Wallpaper source is missing", "source": str(path)}
    try:
        source = path if seed else matugen_source(path)
        result = subprocess.run(
            (["matugen", "color", "hex", seed] if seed else ["matugen", "image", str(source), "--source-color-index", "0"])
            + ["--dry-run", "--json", "hex", "--mode", mode, "--type", "scheme-tonal-spot"],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or "Matugen exited unsuccessfully")
        palette = preserve_source_accent(json.loads(result.stdout), seed)
        payload: dict[str, object] = {
            "ok": True,
            "source": str(path),
            "sample": str(source),
            "seed": seed.lower(),
            "mode": mode,
            "generatedAt": int(time.time()),
            "palette": palette,
        }
        cache_root().mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile("w", dir=cache_root(), suffix=".tmp", delete=False) as handle:
            temp = Path(handle.name)
            json.dump(payload, handle, separators=(",", ":"))
        temp.replace(cached_palette(mode))
        return payload
    except (OSError, subprocess.TimeoutExpired, RuntimeError, json.JSONDecodeError) as error:
        return {"ok": False, "error": str(error), "source": str(path)}



# Preview extraction has its own bounded cache and never writes palette.json or
# palette-frame.jpg. Inputs are the picker's already prepared local thumbnails.
_preview_child = None


def preview_swatches(data: object, mode: str = "dark") -> list[dict[str, str]]:
    if not isinstance(data, dict) or not isinstance(data.get("colors"), dict):
        return []
    roles = [("primary", "Accent"), ("secondary", "Secondary"),
             ("tertiary", "Tertiary"), ("surface_container", "Surface"),
             ("on_surface", "Text")]
    result, seen = [], set()
    for role, label in roles:
        entry = data["colors"].get(role, {})
        if not isinstance(entry, dict):
            continue
        variant = entry.get(mode) or entry.get("default") or {}
        color = variant.get("color", "") if isinstance(variant, dict) else ""
        if not isinstance(color, str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", color):
            continue
        color = color.lower()
        if color not in seen:
            result.append({"role": role, "name": label, "color": color})
            seen.add(color)
    return result


def terminate_preview(_signal, _frame):
    child = _preview_child
    if child is not None and child.poll() is None:
        child.terminate()
        try:
            child.wait(timeout=1)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
    raise SystemExit(128 + _signal)


def preview(path: Path, seed: str = "", mode: str = "dark") -> dict[str, object]:
    global _preview_child
    source = str(path)
    failure = {"ok": False, "source": source, "mode": mode, "swatches": []}
    temporary = None
    try:
        if mode not in {"dark", "light"}:
            return dict(failure, error="Invalid theme mode")
        if seed and not re.fullmatch(r"#[0-9a-fA-F]{6}", seed):
            return dict(failure, error="Invalid source color.")
        if not path.is_absolute() or not path.is_file() or path.suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp"}:
            return dict(failure, error="No local wallpaper preview is available.")
        stamp = path.stat()
        if stamp.st_size > 8 * 1024 * 1024:
            return dict(failure, error="Wallpaper preview is too large to sample.")
        key = hashlib.sha256(f"preview-v4-exact:{mode}:{seed.lower()}:{path.resolve()}:{stamp.st_mtime_ns}:{stamp.st_size}".encode()).hexdigest()[:24]
        directory = cache_root() / "palette-previews"
        target = directory / (key + ".json")
        try:
            cached = json.loads(target.read_text())
            rows = cached.get("swatches", [])
            if cached.get("mode") == mode and cached.get("ok") is True and cached.get("source") == source and cached.get("choices") and 3 <= len(rows) <= 5 and all(
                isinstance(row, dict) and isinstance(row.get("name"), str) and isinstance(row.get("role"), str)
                and re.fullmatch(r"#[0-9a-f]{6}", str(row.get("color", ""))) for row in rows):
                return cached
        except (OSError, ValueError, AttributeError, TypeError):
            pass
        if not shutil.which("matugen"):
            return dict(failure, error="Install Matugen to preview wallpaper colors.")
        _preview_child = subprocess.Popen(
            ["matugen", "image", source, "--show-source-colors", "--dry-run"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        try:
            candidates, _ = _preview_child.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            _preview_child.kill(); _preview_child.communicate()
            return dict(failure, error="Wallpaper color sampling timed out.")
        choices = list(dict.fromkeys(line.strip().lower() for line in candidates.splitlines()
                       if re.fullmatch(r"#[0-9a-fA-F]{6}", line.strip())))[:5]
        if _preview_child.returncode or not choices:
            return dict(failure, error="Matugen could not list source colors. Check its version.")
        selected = seed.lower() or choices[0]
        _preview_child = subprocess.Popen(
            ["matugen", "color", "hex", selected, "--dry-run", "--json", "hex", "--mode", mode,
             "--type", "scheme-tonal-spot"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        try:
            stdout, _stderr = _preview_child.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            _preview_child.kill()
            _preview_child.communicate()
            return dict(failure, error="Wallpaper color sampling timed out.")
        if _preview_child.returncode:
            return dict(failure, error="Could not sample this wallpaper preview.")
        rows = preview_swatches(preserve_source_accent(json.loads(stdout), selected), mode)
        if len(rows) < 3:
            return dict(failure, error="This preview did not produce a usable theme palette.")
        payload = {"ok": True, "source": source, "swatches": rows, "choices": choices, "seed": selected, "mode": mode, "error": ""}
        try:
            directory.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile("w", dir=directory, suffix=".tmp", delete=False) as handle:
                temporary = Path(handle.name)
                json.dump(payload, handle, separators=(",", ":"))
            temporary.replace(target)
            temporary = None
            for old in sorted(directory.glob("*.json"), key=lambda item: item.stat().st_mtime, reverse=True)[64:]:
                old.unlink(missing_ok=True)
        except OSError:
            pass  # A read-only cache must not discard a successfully sampled palette.
        return payload
    except (OSError, ValueError, TypeError) as error:
        return dict(failure, error="Could not read this wallpaper's colors.")
    finally:
        _preview_child = None
        if temporary:
            temporary.unlink(missing_ok=True)

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", nargs="?")
    parser.add_argument("--cached", action="store_true")
    parser.add_argument("--preview", action="store_true", help="Sample a prepared thumbnail without changing the applied palette")
    parser.add_argument("--seed", default="", help="Generate from an explicit hex source color")
    parser.add_argument("--mode", choices=("dark", "light"), default="dark")
    args = parser.parse_args()
    if args.preview:
        signal.signal(signal.SIGTERM, terminate_preview)
        payload = preview(Path(args.source or ""), args.seed, args.mode)
    else:
        payload = read_cached(args.mode) if args.cached else generate(Path(args.source or ""), args.seed, args.mode)
    print(json.dumps(payload, separators=(",", ":")))
    if not payload.get("ok"):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
