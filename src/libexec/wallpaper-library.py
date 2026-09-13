#!/usr/bin/env python3
"""Index wallpaper-only image/video roots without ingesting screenshots."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from urllib.parse import unquote, urlsplit


IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".avif"}
VIDEO_SUFFIXES = {".mp4", ".mkv", ".mov", ".webm", ".avi", ".m4v"}


def library_home() -> Path:
    return Path.home() / "Pictures" / "Wallpapers"


def state_file() -> Path:
    return Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state") / "tonantzintla" / "parallax.json"


def read_favorites() -> set[str]:
    try:
        payload = json.loads(state_file().read_text(encoding="utf-8"))
        return {value for value in payload.get("favorites", []) if isinstance(value, str)}
    except FileNotFoundError:
        return set()
    except (ValueError, AttributeError, TypeError) as error:
        raise ValueError("Favorites could not be read; restore or remove parallax.json in the state directory") from error


def set_favorite(path: str, enabled: bool) -> dict:
    candidate = Path(path).expanduser().resolve(strict=True)
    if not candidate.is_file() or candidate.suffix.lower() not in IMAGE_SUFFIXES | VIDEO_SUFFIXES:
        raise ValueError("Choose a local image or video to favorite")
    destination = state_file()
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Serialize changes from separate shell instances and replace atomically.
    with destination.with_suffix(".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        favorites = read_favorites()
        if enabled:
            favorites.add(str(candidate))
        else:
            favorites.discard(str(candidate))
        temporary = None
        try:
            with tempfile.NamedTemporaryFile("w", dir=destination.parent, delete=False, encoding="utf-8") as handle:
                temporary = Path(handle.name)
                json.dump({"favorites": sorted(favorites)}, handle)
                handle.flush()
                os.fsync(handle.fileno())
            temporary.replace(destination)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
    return {"ok": True, "action": "favorite", "path": str(candidate), "favorite": enabled}


def local_path(value: str) -> Path:
    if value.startswith("file:"):
        url = urlsplit(value)
        if url.netloc not in {"", "localhost"} or url.query or url.fragment:
            raise ValueError("Only local files can be imported")
        return Path(unquote(url.path)).resolve(strict=True)
    if "://" in value or not Path(value).is_absolute():
        raise ValueError("Drop a local image or video file")
    return Path(value).resolve(strict=True)


def validate_import(path: Path) -> None:
    suffix = path.suffix.lower()
    if not path.is_file() or suffix not in IMAGE_SUFFIXES | VIDEO_SUFFIXES:
        raise ValueError("Unsupported file; choose an image or video")
    if suffix in IMAGE_SUFFIXES and not valid_image(path):
        raise ValueError("File does not contain a supported image")
    if not shutil.which("ffprobe"):
        raise ValueError("Install ffmpeg to validate imported images and videos")
    # Probe the first video/image stream rather than trusting the extension.
    try:
        result = subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
             "stream=width,height", "-of", "json", str(path)],
            capture_output=True, text=True, timeout=12, check=False,
        )
        streams = json.loads(result.stdout).get("streams", [])
        if result.returncode or not streams or streams[0].get("width", 0) < 1 or streams[0].get("height", 0) < 1:
            raise ValueError("File has no readable image or video stream")
    except (subprocess.TimeoutExpired, json.JSONDecodeError) as error:
        raise ValueError("File could not be validated") from error


def import_files(values: list[str]) -> dict:
    if not isinstance(values, list) or not values or len(values) > 64 or not all(isinstance(value, str) for value in values):
        raise ValueError("Import between 1 and 64 local files at a time")
    destination = library_home() / "Imported"
    imported, errors = [], []
    for value in values:
        created = None
        try:
            source = local_path(value)
            validate_import(source)
            destination.mkdir(parents=True, exist_ok=True)
            if source.is_relative_to(library_home().resolve()):
                imported.append(str(source))
                continue
            for counter in range(1, 10001):
                name = source.name if counter == 1 else f"{source.stem} ({counter}){source.suffix}"
                target = destination / name
                try:
                    output = target.open("xb")
                except FileExistsError:
                    continue
                created = target
                with output, source.open("rb") as incoming:
                    shutil.copyfileobj(incoming, output, 1024 * 1024)
                imported.append(str(target))
                break
            else:
                raise ValueError("Too many files with this name; rename the file before importing")
        except (OSError, ValueError) as error:
            if created is not None:
                created.unlink(missing_ok=True)
            errors.append({"file": value, "error": str(error)})
    return {"ok": not errors, "action": "import", "imported": imported, "errors": errors}


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
        library_home(),
        Path("/usr/share/backgrounds"),
    ]


def index_library(bundled_root: Path) -> list[dict]:
    favorites = read_favorites()
    colors = marker_colors()
    paths = list(iter_files(library_roots(bundled_root)))
    # Keep Tonantzintla's bundled worlds and video wallpapers discoverable even
    # when ~/Pictures contains more than the bounded library size.
    paths.sort(key=lambda path: (
        0 if str(path) in favorites else
        1 if path.is_relative_to(bundled_root) else
        2 if path.suffix.lower() in VIDEO_SUFFIXES else 3,
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
            "favorite": str(path) in favorites,
            "folder": str(path.parent),
        })
    return entries


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundled-root")
    parser.add_argument("--import-json", help="JSON array of local paths or file URLs")
    parser.add_argument("--favorite")
    parser.add_argument("--enabled", choices=["true", "false"], default="true")
    args = parser.parse_args()
    try:
        if args.import_json is not None:
            payload = import_files(json.loads(args.import_json))
        elif args.favorite is not None:
            payload = set_favorite(args.favorite, args.enabled == "true")
        elif args.bundled_root:
            payload = index_library(Path(args.bundled_root).resolve())
        else:
            parser.error("provide --bundled-root, --import-json, or --favorite")
    except (OSError, ValueError) as error:
        payload = {"ok": False, "error": str(error)}
    print(json.dumps(payload, separators=(",", ":")))


if __name__ == "__main__":
    main()
