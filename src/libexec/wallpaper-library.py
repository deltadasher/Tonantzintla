#!/usr/bin/env python3
"""Index wallpaper-only image/video roots without ingesting screenshots."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".avif"}
VIDEO_SUFFIXES = {".mp4", ".mkv", ".mov", ".webm", ".avi", ".m4v"}


def valid_image(path: Path) -> bool:
    """Reject HTML/error responses and truncated files disguised as images."""
    try:
        with path.open("rb") as handle:
            header = handle.read(32)
    except OSError:
        return False
    return (
        header.startswith(b"\x89PNG\r\n\x1a\n")
        or header.startswith(b"\xff\xd8\xff")
        or header.startswith((b"GIF87a", b"GIF89a"))
        or header.startswith(b"BM")
        or (header.startswith(b"RIFF") and header[8:12] == b"WEBP")
        or (len(header) >= 12 and header[4:8] == b"ftyp"
            and header[8:12] in {b"avif", b"avis", b"mif1"})
    )


def cache_home() -> Path:
    return Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))


def color_bucket(hex_color: str) -> str:
    try:
        value = hex_color.lstrip("#")[:6]
        red, green, blue = (int(value[index:index + 2], 16) / 255 for index in (0, 2, 4))
    except (ValueError, TypeError):
        return "Unsorted"
    maximum, minimum = max(red, green, blue), min(red, green, blue)
    delta = maximum - minimum
    saturation = 0 if maximum == 0 else delta / maximum
    if saturation < 0.08 or maximum < 0.10:
        return "Mono"
    if delta == 0:
        hue = 0
    elif maximum == red:
        hue = 60 * (((green - blue) / delta) % 6)
    elif maximum == green:
        hue = 60 * (((blue - red) / delta) + 2)
    else:
        hue = 60 * (((red - green) / delta) + 4)
    if hue < 15 or hue >= 345:
        return "Red"
    if hue < 45:
        return "Orange"
    if hue < 75:
        return "Yellow"
    if hue < 165:
        return "Green"
    if hue < 260:
        return "Blue"
    if hue < 315:
        return "Purple"
    return "Pink"


def marker_colors() -> dict[str, str]:
    directory = cache_home() / "quickshell" / "wallpaper_picker" / "colors_markers"
    colors: dict[str, str] = {}
    if directory.is_dir():
        try:
            markers = directory.iterdir()
            for marker in markers:
                if "_HEX_" in marker.name:
                    name, color = marker.name.rsplit("_HEX_", 1)
                    colors[name] = "#" + color[:6]
        except OSError:
            pass
    return colors


def video_preview(path: Path) -> str:
    thumb_dir = cache_home() / "tonantzintla" / "wallpaper-thumbs"
    try:
        thumb_dir.mkdir(parents=True, exist_ok=True)
        key = hashlib.sha1(f"{path}:{path.stat().st_mtime_ns}".encode()).hexdigest()[:18]
    except OSError:
        return ""
    thumb = thumb_dir / f"{key}.jpg"
    if thumb.is_file():
        return str(thumb)
    serp_thumb = cache_home() / "quickshell" / "wallpaper_picker" / "thumbs" / path.name
    if serp_thumb.is_file():
        return str(serp_thumb)
    if shutil.which("ffmpeg"):
        try:
            subprocess.run(
                ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", "2", "-i", str(path),
                 "-frames:v", "1", "-vf", "scale=640:-2", str(thumb)],
                timeout=16,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            return ""
    return str(thumb) if thumb.is_file() else ""


def iter_files(roots: list[Path]):
    seen: set[str] = set()
    for root in roots:
        if root.is_file():
            candidates = [root]
        elif root.is_dir():
            # os.walk lets an unreadable subdirectory be skipped instead of
            # aborting the whole index. A single protected folder should not
            # make the bundled library disappear.
            candidates = (
                Path(directory) / filename
                for directory, _directories, filenames in os.walk(
                    root, onerror=lambda _error: None, followlinks=False
                )
                for filename in filenames
            )
        else:
            continue
        for path in candidates:
            try:
                if not path.is_file() or path.suffix.lower() not in IMAGE_SUFFIXES | VIDEO_SUFFIXES:
                    continue
                if path.suffix.lower() in IMAGE_SUFFIXES and not valid_image(path):
                    continue
                resolved = str(path.resolve())
            except OSError:
                continue
            if resolved not in seen:
                seen.add(resolved)
                yield Path(resolved)


def source_name(path: Path, bundled_root: Path) -> str:
    value = str(path)
    if value.startswith(str(bundled_root)):
        return "Tonantzintla"
    if value.startswith("/usr/share/backgrounds"):
        return "System"
    if path.name.startswith(("ddg_", "tonantzintla-")):
        return "Downloaded"
    return "Library"


def library_roots(bundled_root: Path) -> list[Path]:
    """Return deliberate wallpaper roots; never crawl the general Pictures tree."""
    return [
        bundled_root,
        Path.home() / "Pictures" / "Wallpapers",
        Path("/usr/share/backgrounds"),
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundled-root", required=True)
    args = parser.parse_args()
    bundled_root = Path(args.bundled_root).resolve()
    colors = marker_colors()
    paths = list(iter_files(library_roots(bundled_root)))
    # Keep Tonantzintla's bundled worlds and video wallpapers discoverable even
    # when ~/Pictures contains more than the bounded library size.
    paths.sort(key=lambda path: (
        0 if str(path).startswith(str(bundled_root)) else
        1 if path.suffix.lower() in VIDEO_SUFFIXES else
        2,
        str(path).lower(),
    ))
    entries = []
    for path in paths[:320]:
        kind = "video" if path.suffix.lower() in VIDEO_SUFFIXES else "image"
        color = colors.get(path.name, "")
        entries.append({
            "path": str(path),
            "preview": video_preview(path) if kind == "video" else str(path),
            "name": path.name,
            "kind": kind,
            "source": source_name(path, bundled_root),
            "color": color,
            "bucket": color_bucket(color),
            "remoteUrl": "",
        })
    print(json.dumps(entries, separators=(",", ":")))


if __name__ == "__main__":
    main()
