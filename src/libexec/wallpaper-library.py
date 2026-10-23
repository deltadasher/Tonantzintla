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
                ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-threads", "1", "-filter_threads", "1", "-ss", "2", "-i", str(path),
                 "-frames:v", "1", "-vf", "scale=640:-2", "-threads", "1", str(thumb)],
                timeout=16,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            return ""
    return str(thumb) if thumb.is_file() else ""


def preview_decode_options(path: Path, extent: int = 512) -> list[str] | None:
    """Inspect bounded headers before allocating image pixels.

    Sequential JPEG supports reduced decoding. Other formats and progressive
    coefficient storage need a conservative source-pixel cap. Unknown headers
    use the unavailable-preview fallback; the original remains applicable.
    """
    with path.open("rb") as handle:
        data = handle.read(1024 * 1024)
    width = height = 0
    lowres = 0
    if data.startswith(b"\xff\xd8"):
        pos = 2
        while pos + 4 <= len(data):
            if data[pos] != 0xff:
                return None
            while pos < len(data) and data[pos] == 0xff:
                pos += 1
            if pos >= len(data):
                return None
            marker = data[pos]
            pos += 1
            if marker in (0xda, 0xd9):
                return None
            if marker == 0x01 or 0xd0 <= marker <= 0xd8:
                continue
            length = int.from_bytes(data[pos:pos + 2], "big")
            if length < 2 or pos + length > len(data):
                return None
            if marker in (0xc0, 0xc1, 0xc2):
                frame = data[pos + 2:pos + length]
                if len(frame) < 6 or frame[0] != 8 or not 1 <= frame[5] <= 4 or len(frame) < 6 + frame[5] * 3:
                    return None
                height, width = int.from_bytes(frame[1:3], "big"), int.from_bytes(frame[3:5], "big")
                if marker == 0xc2 and width * height > 16_000_000:
                    return None
                while lowres < 3 and max(width, height) // (2 ** (lowres + 1)) >= extent:
                    lowres += 1
                break
            pos += length
    elif data.startswith(b"\x89PNG\r\n\x1a\n") and data[8:16] == b"\x00\x00\x00\rIHDR" and len(data) >= 24:
        width, height = int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")
    elif data.startswith((b"GIF87a", b"GIF89a")) and len(data) >= 10:
        width, height = int.from_bytes(data[6:8], "little"), int.from_bytes(data[8:10], "little")
    elif data.startswith(b"BM") and len(data) >= 26:
        dib = int.from_bytes(data[14:18], "little")
        if dib == 12:
            width, height = int.from_bytes(data[18:20], "little"), int.from_bytes(data[20:22], "little")
        elif dib >= 40:
            width = int.from_bytes(data[18:22], "little", signed=True)
            height = abs(int.from_bytes(data[22:26], "little", signed=True))
    elif data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        pos = 12
        while pos + 8 <= len(data):
            kind, size = data[pos:pos + 4], int.from_bytes(data[pos + 4:pos + 8], "little")
            frame = data[pos + 8:pos + 18]
            if kind == b"VP8X" and size >= 10 and len(frame) >= 10:
                width, height = 1 + int.from_bytes(frame[4:7], "little"), 1 + int.from_bytes(frame[7:10], "little")
                break
            if kind == b"VP8L" and size >= 5 and len(frame) >= 5 and frame[0] == 0x2f:
                packed = int.from_bytes(frame[1:5], "little")
                width, height = 1 + (packed & 0x3fff), 1 + ((packed >> 14) & 0x3fff)
                break
            if kind == b"VP8 " and size >= 10 and len(frame) >= 10 and frame[3:6] == b"\x9d\x01\x2a":
                width, height = int.from_bytes(frame[6:8], "little") & 0x3fff, int.from_bytes(frame[8:10], "little") & 0x3fff
                break
            pos += 8 + size + size % 2
    scale = 2 ** lowres
    if width <= 0 or height <= 0 or ((width + scale - 1) // scale) * ((height + scale - 1) // scale) > 16_000_000:
        return None
    return ["-lowres", str(lowres)] if lowres else []


def prepared_dimensions(path: Path, extent: int) -> tuple[int, int] | None:
    try:
        with path.open("rb") as handle:
            header = handle.read(24)
        if len(header) != 24 or header[:16] != b"\x89PNG\r\n\x1a\n\0\0\0\rIHDR":
            return None
        width, height = int.from_bytes(header[16:20], "big"), int.from_bytes(header[20:24], "big")
        return (width, height) if 0 < width <= extent and 0 < height <= extent else None
    except OSError:
        return None


def image_preview(path: Path, extent: int = 512, *, no_upscale: bool = False) -> str:
    """Keep full wallpaper pixels out of the shell's orbital canvases.

    ffmpeg is already an optional wallpaper dependency. Without it, the picker
    displays its colour fallback; it must never silently decode the original.
    """
    if extent not in (512, 768, 2560):
        raise ValueError("Unsupported preview extent")
    temporary = None
    try:
        stamp = path.stat()
        fit = no_upscale or extent == 2560
        version = ":native-fit-v1" if fit else ""
        key = hashlib.sha256(f"{path.resolve()}:{stamp.st_mtime_ns}:{stamp.st_size}:{extent}{version}".encode()).hexdigest()[:24]
        directory = cache_home() / "tonantzintla" / "wallpaper-previews"
        target = directory / f"{key}.png"
        if target.is_file() and prepared_dimensions(target, extent):
            return str(target)
        converter = shutil.which("ffmpeg")
        if not converter:
            return ""
        decode_options = preview_decode_options(path, extent)
        if decode_options is None:
            return ""
        directory.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=directory, suffix=".png", delete=False) as pending:
            temporary = Path(pending.name)
        scale = (f"scale=w='min({extent},iw)':h='min({extent},ih)':force_original_aspect_ratio=decrease"
                 if fit else f"scale=w={extent}:h={extent}:force_original_aspect_ratio=decrease")
        result = subprocess.run(
            [converter, "-hide_banner", "-loglevel", "error", "-y", "-threads", "1", "-filter_threads", "1"] + decode_options + [
             "-i", str(path), "-frames:v", "1", "-vf",
             scale, "-threads", "1", str(temporary)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=12, check=False,
        )
        if result.returncode or not prepared_dimensions(temporary, extent):
            return ""
        os.replace(temporary, target)
        temporary = None
        return str(target)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)



def prepared_still(path: Path, extent: int, message: str) -> dict:
    """Prepare exactly one still. Never index a library or decode video."""
    result = {"ok": False, "source": str(path), "preview": "", "width": 0, "height": 0,
              "message": message}
    try:
        path = path.expanduser().resolve(strict=True)
        if not path.is_file() or path.suffix.lower() not in IMAGE_SUFFIXES:
            return result
        preview = image_preview(path, extent)
        dimensions = prepared_dimensions(Path(preview), extent) if preview else None
        if dimensions:
            result.update(ok=True, preview=preview, width=dimensions[0], height=dimensions[1], message="")
    except (OSError, ValueError):
        pass
    return result


def optical_preview(path: Path) -> dict:
    return prepared_still(path, 768, "Optical still unavailable · etched fallback")


def native_wallpaper_preview(path: Path) -> dict:
    result = prepared_still(path, 2560, "Native still unavailable · previous background retained")
    result.update(transitionPreview="", transitionWidth=0, transitionHeight=0)
    if result["ok"]:
        preview = image_preview(path, 512, no_upscale=True)
        dimensions = prepared_dimensions(Path(preview), 512) if preview else None
        if dimensions:
            result.update(transitionPreview=preview, transitionWidth=dimensions[0], transitionHeight=dimensions[1])
    return result


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
            "preview": video_preview(path) if kind == "video" else image_preview(path),
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
    parser.add_argument("--native-wallpaper-preview", help="Prepare one native wallpaper still up to 2560px without indexing")
    parser.add_argument("--optical-preview", help="Prepare one bounded optical still without indexing")
    parser.add_argument("--bundled-root")
    parser.add_argument("--import-json", help="JSON array of local paths or file URLs")
    parser.add_argument("--favorite")
    parser.add_argument("--enabled", choices=["true", "false"], default="true")
    args = parser.parse_args()
    try:
        if args.native_wallpaper_preview is not None:
            payload = native_wallpaper_preview(Path(args.native_wallpaper_preview))
            payload["source"] = args.native_wallpaper_preview
        elif args.optical_preview is not None:
            payload = optical_preview(Path(args.optical_preview))
            payload["source"] = args.optical_preview
        elif args.import_json is not None:
            payload = import_files(json.loads(args.import_json))
        elif args.favorite is not None:
            payload = set_favorite(args.favorite, args.enabled == "true")
        elif args.bundled_root:
            payload = index_library(Path(args.bundled_root).resolve())
        else:
            parser.error("provide --optical-preview, --bundled-root, --import-json, or --favorite")
    except (OSError, ValueError) as error:
        payload = {"ok": False, "error": str(error)}
    print(json.dumps(payload, separators=(",", ":")))


if __name__ == "__main__":
    main()
