#!/usr/bin/env python3

"""Render an SDDM-safe Umbra palette from Tonantzintla's cached Matugen data."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


FALLBACKS = {
    "voidColor": "#080910",
    "mantle": "#10121d",
    "surface": "#171a28",
    "foreground": "#eee9dc",
    "muted": "#8e94aa",
    "accent": "#a99cff",
    "secondary": "#72d9e7",
    "danger": "#ed7d8f",
}

MATERIAL_KEYS = {
    "voidColor": "surface_container_lowest",
    "mantle": "surface_container_low",
    "surface": "surface_container",
    "foreground": "on_surface",
    "muted": "on_surface_variant",
    "accent": "primary",
    "secondary": "secondary",
    "danger": "error",
}


def cached_palette_path() -> Path:
    cache = Path.home() / ".cache"
    return Path(__import__("os").environ.get("XDG_CACHE_HOME", cache)) / "tonantzintla" / "palette.json"


def material_color(payload: dict, key: str, fallback: str) -> str:
    palette = payload.get("palette", {}) if payload.get("ok") is True else {}
    entry = palette.get("colors", {}).get(key, {})
    variant = entry.get("default") or entry.get("dark") or {}
    value = variant.get("color")
    if isinstance(value, str) and value.startswith("#"):
        return value
    return fallback


def render(payload: dict) -> str:
    lines = ["[General]"]
    for name, fallback in FALLBACKS.items():
        value = material_color(payload, MATERIAL_KEYS[name], fallback)
        lines.append(f"{name}={value}")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--palette", type=Path, default=cached_palette_path())
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    payload: dict = {}
    try:
        payload = json.loads(args.palette.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        pass

    content = render(payload)
    if args.output:
        args.output.write_text(content, encoding="utf-8")
    else:
        print(content, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
