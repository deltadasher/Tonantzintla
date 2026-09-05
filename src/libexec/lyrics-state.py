#!/usr/bin/env python3
"""Resolve and cache lyrics for Tonantzintla's Resonance console."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import sys
import urllib.error
import urllib.parse
import urllib.request


def cache_root() -> pathlib.Path:
    base = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    path = pathlib.Path(base) / "tonantzintla" / "lyrics"
    path.mkdir(parents=True, exist_ok=True)
    return path


def signature(title: str, artist: str, album: str, duration: int) -> str:
    normalized = "\x1f".join((title.strip().lower(), artist.strip().lower(),
                                album.strip().lower(), str(duration)))
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def emit(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--title", required=True)
    parser.add_argument("--artist", required=True)
    parser.add_argument("--album", default="")
    parser.add_argument("--duration", type=int, default=0)
    parser.add_argument("--refresh", action="store_true")
    args = parser.parse_args()

    cache_file = cache_root() / f"{signature(args.title, args.artist, args.album, args.duration)}.json"
    if cache_file.exists() and not args.refresh:
        try:
            payload = json.loads(cache_file.read_text(encoding="utf-8"))
            payload["source"] = "CACHE"
            emit(payload)
            return 0
        except (OSError, json.JSONDecodeError):
            pass

    params = {
        "track_name": args.title,
        "artist_name": args.artist,
    }
    if args.album:
        params["album_name"] = args.album
    if 1 <= args.duration <= 3600:
        params["duration"] = str(args.duration)

    url = "https://lrclib.net/api/get?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "Tonantzintla/0.1 (Quickshell lyrics client)"},
    )

    try:
        with urllib.request.urlopen(request, timeout=9) as response:
            result = json.loads(response.read().decode("utf-8"))
        payload = {
            "status": "instrumental" if result.get("instrumental") else "ready",
            "plain": result.get("plainLyrics") or "",
            "synced": result.get("syncedLyrics") or "",
            "instrumental": bool(result.get("instrumental")),
            "source": "LRCLIB",
            "trackId": result.get("id", 0),
        }
        cache_file.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
        emit(payload)
        return 0
    except urllib.error.HTTPError as error:
        if error.code == 404:
            emit({"status": "missing", "plain": "", "synced": "",
                  "instrumental": False, "source": "LRCLIB"})
            return 0
        message = f"LRCLIB HTTP {error.code}"
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as error:
        message = str(error)

    if cache_file.exists():
        try:
            payload = json.loads(cache_file.read_text(encoding="utf-8"))
            payload["source"] = "STALE CACHE"
            emit(payload)
            return 0
        except (OSError, json.JSONDecodeError):
            pass

    emit({"status": "offline", "plain": "", "synced": "",
          "instrumental": False, "source": "OFFLINE", "error": message})
    return 0


if __name__ == "__main__":
    sys.exit(main())
