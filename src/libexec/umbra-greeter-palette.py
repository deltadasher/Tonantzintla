#!/usr/bin/env python3

"""Render an SDDM-safe Umbra palette from Tonantzintla's cached Matugen data."""

from __future__ import annotations

import argparse
import json
import os
import importlib.util
from pathlib import Path


_spec = importlib.util.spec_from_file_location("theme_identity", Path(__file__).with_name("theme-identity.py"))
identity = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(identity)

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


def material_color(payload: dict, key: str, fallback: str, mode="dark") -> str:
    palette = payload.get("palette", {}) if payload.get("ok") is True else {}
    entry = palette.get("colors", {}).get(key, {})
    variant = entry.get(mode) or entry.get("default") or {}
    value = variant.get("color")
    if identity.valid_color(value):
        return value
    return fallback


def render(payload: dict, settings: dict | None = None) -> str:
    settings = settings or {}
    # Ignore palettes from another wallpaper or explicit seed.
    if settings and (payload.get("source", "") != settings.get("wallpaperPath", "")
                     or payload.get("seed", "") != settings.get("paletteSeedColor", "")):
        payload = {}
    source = material_color(payload, "source_color", "")
    mark, mode = identity.resolve(settings, source)
    lines = ["[General]"]
    for name, fallback in FALLBACKS.items():
        if mode == "light":
            fallback = {"voidColor":"#f8f7fc", "mantle":"#f0eff7", "surface":"#e7e6ef", "foreground":"#23232e", "muted":"#5b596c", "danger":"#a93649"}.get(name, fallback)
        value = material_color(payload, MATERIAL_KEYS[name], fallback, mode)
        lines.append(f"{name}={value}")
    lines += [f"themeIdentity={mark['id']}", f"identityColor={mark['color']}", f"themeMode={mode}",
              "motion=" + ("false" if settings.get("motion") is False or settings.get("umbraMotion") is False else "true")]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--palette", type=Path, default=cached_palette_path())
    parser.add_argument("--output", type=Path)
    parser.add_argument("--settings", type=Path, default=Path(os.environ.get("XDG_CONFIG_HOME", Path.home()/".config"))/"tonantzintla/settings.json")
    args = parser.parse_args()

    payload: dict = {}
    try:
        payload = json.loads(args.palette.read_text(encoding="utf-8"))
        if not isinstance(payload, dict): payload = {}
    except (OSError, json.JSONDecodeError):
        pass

    try:
        settings = json.loads(args.settings.read_text(encoding="utf-8"))
        if not isinstance(settings, dict): settings = {}
    except (OSError, json.JSONDecodeError):
        settings = {}
    content = render(payload, settings)
    if args.output:
        args.output.write_text(content, encoding="utf-8")
    else:
        print(content, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
