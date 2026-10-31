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
    if not isinstance(payload, dict) or payload.get("ok") is not True:
        return fallback
    palette = payload.get("palette")
    colors = palette.get("colors") if isinstance(palette, dict) else None
    entry = colors.get(key) if isinstance(colors, dict) else None
    if not isinstance(entry, dict):
        return fallback
    variant = entry.get(mode) or entry.get("default")
    value = variant.get("color") if isinstance(variant, dict) else None
    return value if identity.valid_color(value) else fallback


def render(payload: dict, settings: dict | None = None) -> str:
    # Keep palette-only callers compatible; an explicit settings snapshot uses
    # the shell defaults (including adaptivePalette=false).
    palette_only = settings is None
    settings = settings if isinstance(settings, dict) else {}
    payload = payload if isinstance(payload, dict) else {}
    cache_mode = payload.get("mode")
    if not palette_only and (settings.get("adaptivePalette") is not True
            or payload.get("source", "") != settings.get("wallpaperPath", "")
            or payload.get("seed", "") != settings.get("paletteSeedColor", "")
            or cache_mode not in ("light", "dark")
            or not identity.valid_color(material_color(payload, "primary", "", cache_mode))):
        payload = {}
    source = material_color(payload, "source_color", "", cache_mode if cache_mode in ("light", "dark") else "dark")
    mark, mode = identity.resolve(dict(settings, adaptivePalette=True, themeMode="dark") if palette_only else settings, source)
    # Theme.identityColor can use the ready source across a mode change, while
    # Theme.adaptive requires the material palette to match the resolved mode.
    material = payload if palette_only or cache_mode == mode else {}
    spectral = settings.get("spectralColors")
    exact_accent = spectral.get("accent") if isinstance(spectral, dict) else None
    accent_name = settings.get("accentName", "violet")
    accents = {
        "violet": ("#6653a6", "#a99cff"), "cyan": ("#006875", "#72d9e7"),
        "rose": ("#9a4565", "#ec8eae"), "amber": ("#805613", "#e9b872"),
        "emerald": ("#236b50", "#77d6ae"), "solar": ("#99481f", "#ff9e64"),
        "silver": ("#55596a", "#d4d8e8"),
    }
    preset_accent = accents.get(accent_name, accents["violet"]) if isinstance(accent_name, str) else accents["violet"]
    lines = ["[General]"]
    for name, fallback in FALLBACKS.items():
        if mode == "light":
            fallback = {"voidColor":"#f8f7fc", "mantle":"#f0eff7", "surface":"#e7e6ef", "foreground":"#23232e", "muted":"#5b596c", "danger":"#a93649"}.get(name, fallback)
        if name == "accent" and not palette_only:
            fallback = preset_accent[0 if mode == "light" else 1]
        value = material_color(material, MATERIAL_KEYS[name], fallback, mode)
        if name == "accent" and identity.valid_color(exact_accent):
            value = exact_accent
        lines.append(f"{name}={value}")
    lock_mode = mode if settings.get("themeMode") in ("light", "dark") else ("light" if mark["lockLight"] else "dark") if "lockLight" in mark else mode
    lines += [f"lockMode={lock_mode}", f"themeIdentity={mark['id']}", f"identityColor={mark['color']}", f"themeMode={mode}",
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
    except (OSError, UnicodeError, json.JSONDecodeError):
        pass

    try:
        settings = json.loads(args.settings.read_text(encoding="utf-8"))
        if not isinstance(settings, dict): settings = {}
    except (OSError, UnicodeError, json.JSONDecodeError):
        settings = {}
    content = render(payload, settings)
    if args.output:
        args.output.write_text(content, encoding="utf-8")
    else:
        print(content, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
