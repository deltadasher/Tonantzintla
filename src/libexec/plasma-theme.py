#!/usr/bin/env python3
"""Build, sync, validate, install, and apply Tonantzintla as a native KDE Plasma 6 theme."""
from __future__ import annotations

import argparse
import gzip
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

LIBEXEC_DIR = Path(__file__).resolve().parent
if str(LIBEXEC_DIR) not in sys.path:
    sys.path.insert(0, str(LIBEXEC_DIR))
from plasma_plasmoids import PLASMOID_IDS, build_plasmoids, render_splash_qml  # noqa: E402
from plasma_shaders import SHADERS as PLASMA_SHADERS, compile_shaders, find_qsb  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
PLASMA_SRC = ROOT / "plasma"

THEME_ID = "tonantzintla"
LOOK_AND_FEEL_ID = "org.tonantzintla.desktop"
AURORAE_NAME = "Tonantzintla"
AURORAE_LIGHT_NAME = "TonantzintlaLight"
AURORAE_THEMES = (AURORAE_NAME, AURORAE_LIGHT_NAME)
WALLPAPER_NAME = "Tonantzintla"
COLOR_SCHEMES = ("TonantzintlaDark", "TonantzintlaLight")
# Plasma keeps the whole panel and widget arrangement in these two files.
LAYOUT_FILES = ("plasma-org.kde.plasma.desktop-appletsrc", "plasmashellrc")
LAYOUT_BACKUPS_KEPT = 5


def _first_file(*candidates: Path) -> Path:
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return candidates[0]


# A standalone Uranus runtime ships only the prebuilt plasma/ tree, so the two
# source assets fall back to the copies that tree already contains.
WALLPAPER_SRC = _first_file(
    ROOT / "src/assets/wallpapers/astral-observatory.png",
    PLASMA_SRC / "wallpapers" / WALLPAPER_NAME / "contents/images/3840x2160.png",
)
MARK_SRC = _first_file(
    ROOT / "src/quickshell/assets/theme-marks/wabi-sabi.svg",
    PLASMA_SRC / "icons/hicolor/scalable/apps/tonantzintla-mark.svg",
)

DARK_DEFAULTS = {
    "void_": "#111116",
    "mantle": "#16161d",
    "elevated": "#20202a",
    "border": "#2a2a37",
    "foreground": "#eceaf2",
    "muted": "#8c8e9e",
    "accent": "#c4b5ff",
    "selection": "#7e6cd4",
    "secondary": "#7cd8e6",
    "positive": "#7cd9b0",
    "neutral": "#ecc078",
    "negative": "#f08094",
    "visited": "#d896e8",
}

LIGHT_DEFAULTS = {
    "void_": "#f6f5fa",
    "mantle": "#eeedf5",
    "elevated": "#e4e2ee",
    "border": "#cbc9da",
    "foreground": "#1c1c28",
    "muted": "#5a586e",
    "accent": "#6350a8",
    "selection": "#6350a8",
    "secondary": "#006875",
    "positive": "#236b50",
    "neutral": "#8a5a10",
    "negative": "#b3384c",
    "visited": "#83429a",
}

HEX_RE = re.compile(r"^#[0-9a-fA-F]{6}$")


def valid_hex(value: object) -> bool:
    return isinstance(value, str) and bool(HEX_RE.fullmatch(value))


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    cleaned = value.lstrip("#")
    return int(cleaned[0:2], 16), int(cleaned[2:4], 16), int(cleaned[4:6], 16)


def rgb_csv(value: str) -> str:
    r, g, b = hex_to_rgb(value)
    return f"{r},{g},{b}"


def blend_hex(first: str, second: str, ratio: float) -> str:
    r1, g1, b1 = hex_to_rgb(first)
    r2, g2, b2 = hex_to_rgb(second)
    r = round(r1 * (1.0 - ratio) + r2 * ratio)
    g = round(g1 * (1.0 - ratio) + g2 * ratio)
    b = round(b1 * (1.0 - ratio) + b2 * ratio)
    return f"#{r:02x}{g:02x}{b:02x}"


def on_color(bg_hex: str) -> str:
    r, g, b = (c / 255.0 for c in hex_to_rgb(bg_hex))
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in (r, g, b)]
    lum = 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]
    return "#101016" if lum > 0.34 else "#f8f7fc"


def xdg_data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME") or (Path.home() / ".local/share")).expanduser()


def xdg_config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME") or (Path.home() / ".config")).expanduser()


def xdg_cache_home() -> Path:
    return Path(os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache")).expanduser()


def xdg_state_home() -> Path:
    return Path(os.environ.get("XDG_STATE_HOME") or (Path.home() / ".local/state")).expanduser()


def load_json_dict(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def resolve_palette(mode: str = "dark", settings: dict | None = None, matugen: dict | None = None) -> dict[str, str]:
    base = dict(LIGHT_DEFAULTS if mode == "light" else DARK_DEFAULTS)
    settings = settings if isinstance(settings, dict) else {}
    matugen = matugen if isinstance(matugen, dict) else {}

    accents = {
        "violet": ("#6350a8", "#c4b5ff"),
        "cyan": ("#006875", "#7cd8e6"),
        "rose": ("#9a4565", "#ec8eae"),
        "amber": ("#8a5a10", "#ecc078"),
        "emerald": ("#236b50", "#7cd9b0"),
        "solar": ("#99481f", "#ff9e64"),
        "silver": ("#55596a", "#d4d8e8"),
    }
    accent_name = settings.get("accentName", "violet")
    if isinstance(accent_name, str) and accent_name in accents:
        base["accent"] = accents[accent_name][0 if mode == "light" else 1]

    if settings.get("adaptivePalette") is True and matugen.get("ok") is True and matugen.get("mode") == mode:
        colors = (matugen.get("palette") or {}).get("colors") or {}
        mapping = {
            "void_": "surface_container_lowest",
            "mantle": "surface_container_low",
            "elevated": "surface_container",
            "border": "outline_variant",
            "foreground": "on_surface",
            "muted": "on_surface_variant",
            "accent": "primary",
            "secondary": "secondary",
            "negative": "error",
        }
        for role, key in mapping.items():
            entry = colors.get(key)
            if isinstance(entry, dict):
                variant = entry.get(mode) or entry.get("default")
                color = variant.get("color") if isinstance(variant, dict) else None
                if valid_hex(color):
                    base[role] = color.lower()

    spectral = settings.get("spectralColors")
    if isinstance(spectral, dict):
        for role, key in (("accent", "accent"), ("secondary", "cyan"), ("negative", "danger"),
                          ("neutral", "warning"), ("positive", "success"), ("visited", "rose")):
            value = spectral.get(key)
            if valid_hex(value):
                base[role] = value.lower()

    base["onAccent"] = on_color(base["accent"])
    # Keep Selection fills rich mid-tone in dark mode so both Plasma and third-party
    # Qt/GTK apps that force light text on selections stay crisp and legible (WCAG AA).
    if mode == "dark":
        r, g, b = (c / 255.0 for c in hex_to_rgb(base["accent"]))
        lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        if base["accent"].lower() == DARK_DEFAULTS["accent"].lower():
            base["selection"] = "#6d5bc2"
        elif lum > 0.48:
            # Darken toward a deeper saturated tone rather than muddy gray
            dr = max(24, round(r * 255 * 0.56))
            dg = max(24, round(g * 255 * 0.56))
            db = max(36, round(b * 255 * 0.72))
            base["selection"] = f"#{dr:02x}{dg:02x}{db:02x}"
        else:
            base["selection"] = base["accent"]
    else:
        base["selection"] = base["accent"]
    base["onSelection"] = on_color(base["selection"])
    base["hover"] = blend_hex(base["elevated"], base["accent"], 0.14)
    base["inactiveHeader"] = blend_hex(base["void_"], base["mantle"], 0.45)
    return base


def render_color_scheme(scheme_id: str, display_name: str, palette: dict[str, str], mode: str = "dark") -> str:
    bg_view = rgb_csv(palette["void_"])
    bg_window = rgb_csv(palette["mantle"])
    bg_elevated = rgb_csv(palette["elevated"])
    bg_hover = rgb_csv(palette["hover"])
    bg_inactive = rgb_csv(palette["inactiveHeader"])
    fg = rgb_csv(palette["foreground"])
    muted = rgb_csv(palette["muted"])
    accent = rgb_csv(palette["accent"])
    selection = rgb_csv(palette.get("selection", palette["accent"]))
    on_selection = rgb_csv(palette.get("onSelection", palette["onAccent"]))
    secondary = rgb_csv(palette["secondary"])
    pos = rgb_csv(palette["positive"])
    neu = rgb_csv(palette["neutral"])
    neg = rgb_csv(palette["negative"])
    vis = rgb_csv(palette["visited"])
    sel_alt = rgb_csv(blend_hex(palette.get("selection", palette["accent"]), palette["void_"], 0.26))
    dis_color = "56,56,64" if mode == "dark" else "195,193,206"

    def group(
        name: str,
        bg_norm: str,
        bg_alt: str,
        fg_norm: str = fg,
        fg_inact: str = muted,
        fg_act: str = accent,
    ) -> str:
        return (
            f"[Colors:{name}]\n"
            f"BackgroundAlternate={bg_alt}\n"
            f"BackgroundNormal={bg_norm}\n"
            f"DecorationFocus={accent}\n"
            f"DecorationHover={accent}\n"
            f"ForegroundActive={fg_act}\n"
            f"ForegroundInactive={fg_inact}\n"
            f"ForegroundLink={secondary}\n"
            f"ForegroundNegative={neg}\n"
            f"ForegroundNeutral={neu}\n"
            f"ForegroundNormal={fg_norm}\n"
            f"ForegroundPositive={pos}\n"
            f"ForegroundVisited={vis}\n"
        )

    sections = [
        "# Tonantzintla KDE Plasma 6 color scheme (Serpantinum matte palette)\n"
        "# SPDX-License-Identifier: GPL-3.0-or-later\n",
        f"[ColorEffects:Disabled]\nColor={dis_color}\nColorAmount=0\nColorEffect=0\n"
        f"ContrastAmount=0.6\nContrastEffect=1\nIntensityAmount=0.1\nIntensityEffect=2\n",
        f"[ColorEffects:Inactive]\nChangeSelectionColor=true\nColor={rgb_csv(palette['border'])}\n"
        f"ColorAmount=0.025\nColorEffect=2\nContrastAmount=0.1\nContrastEffect=2\n"
        f"Enable=false\nIntensityAmount=0\nIntensityEffect=0\n",
        group("Button", bg_elevated, bg_hover),
        group("Complementary", bg_view, bg_window),
        group("Header", bg_window, bg_elevated),
        group("Header][Inactive", bg_inactive, bg_window),
        group("Selection", selection, sel_alt, fg_norm=on_selection, fg_inact=on_selection, fg_act=on_selection),
        group("Tooltip", bg_window, bg_elevated),
        group("View", bg_view, bg_window),
        group("Window", bg_window, bg_elevated),
        f"[General]\nColorScheme={scheme_id}\nName={display_name}\nshadeSortColumn=true\n",
        "[KDE]\ncontrast=4\nframeContrast=0.14\n",
        f"[WM]\nactiveBackground={bg_window}\nactiveBlend={fg}\nactiveForeground={fg}\n"
        f"inactiveBackground={bg_inactive}\ninactiveBlend={muted}\ninactiveForeground={muted}\n",
    ]
    return "\n".join(sections)


def _svg_style(palette: dict[str, str]) -> str:
    return (
        "<style id=\"current-color-scheme\" type=\"text/css\">\n"
        f"  .ColorScheme-Text {{ color:{palette['foreground']}; }}\n"
        f"  .ColorScheme-Background {{ color:{palette['mantle']}; }}\n"
        f"  .ColorScheme-Highlight {{ color:{palette['accent']}; }}\n"
        f"  .ColorScheme-ViewText {{ color:{palette['foreground']}; }}\n"
        f"  .ColorScheme-ViewBackground {{ color:{palette['void_']}; }}\n"
        f"  .ColorScheme-ViewHover {{ color:{palette['accent']}; }}\n"
        f"  .ColorScheme-ViewFocus {{ color:{palette['accent']}; }}\n"
        f"  .ColorScheme-ButtonText {{ color:{palette['foreground']}; }}\n"
        f"  .ColorScheme-ButtonBackground {{ color:{palette['elevated']}; }}\n"
        f"  .ColorScheme-ButtonHover {{ color:{palette['accent']}; }}\n"
        f"  .ColorScheme-ButtonFocus {{ color:{palette['accent']}; }}\n"
        f"  .ColorScheme-PositiveText {{ color:{palette['positive']}; }}\n"
        f"  .ColorScheme-NeutralText {{ color:{palette['neutral']}; }}\n"
        f"  .ColorScheme-NegativeText {{ color:{palette['negative']}; }}\n"
        "</style>"
    )


def build_frame_svg(
    palette: dict[str, str],
    *,
    radius: int = 12,
    fill_opacity: float = 0.96,
    margin_v: int = 6,
    margin_h: int = 10,
    include_shadow: bool = True,
    include_thick: bool = False,
    border_opacity: float = 0.085,
    fill_class: str = "ColorScheme-Background",
    prefix: str = "",
) -> str:
    """Build a seam-free Plasma 6 9-slice SVG using pure filled geometry and corner-hugging shadows.

    Every 9-slice tile uses exact integer bounding boxes with zero strokes (strokes
    expand KSvg's elementRect and cause 1px overlap seams). Shadow corner tiles use
    a quarter-annulus radial gradient tucked cleanly under the rounded corner curve
    with zero opacity inside the frame so shadows follow the corner smoothly without
    square halos or interior bleed.
    """
    r = radius
    ri = max(1, r - 1)
    c = 24
    x0, y0 = 16, 16
    p = f"{prefix}-" if prefix else ""
    s = 12
    sr = s + r
    inner_pct = f"{(r / sr) * 100.0:.2f}%"
    mid_pct = f"{((r + s * 0.45) / sr) * 100.0:.2f}%"

    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="220" height="196" viewBox="0 0 220 196">',
        "  <defs>",
        f"    {_svg_style(palette)}",
        '    <linearGradient id="shTop" x1="0" y1="1" x2="0" y2="0"><stop offset="0%" stop-color="#000000" stop-opacity="0.22"/><stop offset="45%" stop-color="#000000" stop-opacity="0.08"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></linearGradient>',
        '    <linearGradient id="shBottom" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#000000" stop-opacity="0.30"/><stop offset="45%" stop-color="#000000" stop-opacity="0.11"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></linearGradient>',
        '    <linearGradient id="shLeft" x1="1" y1="0" x2="0" y2="0"><stop offset="0%" stop-color="#000000" stop-opacity="0.24"/><stop offset="45%" stop-color="#000000" stop-opacity="0.09"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></linearGradient>',
        '    <linearGradient id="shRight" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stop-color="#000000" stop-opacity="0.24"/><stop offset="45%" stop-color="#000000" stop-opacity="0.09"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></linearGradient>',
        f'    <radialGradient id="shTL" cx="1" cy="1" r="1"><stop offset="0%" stop-color="#000000" stop-opacity="0"/><stop offset="{inner_pct}" stop-color="#000000" stop-opacity="0.23"/><stop offset="{mid_pct}" stop-color="#000000" stop-opacity="0.08"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></radialGradient>',
        f'    <radialGradient id="shTR" cx="0" cy="1" r="1"><stop offset="0%" stop-color="#000000" stop-opacity="0"/><stop offset="{inner_pct}" stop-color="#000000" stop-opacity="0.23"/><stop offset="{mid_pct}" stop-color="#000000" stop-opacity="0.08"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></radialGradient>',
        f'    <radialGradient id="shBL" cx="1" cy="0" r="1"><stop offset="0%" stop-color="#000000" stop-opacity="0"/><stop offset="{inner_pct}" stop-color="#000000" stop-opacity="0.28"/><stop offset="{mid_pct}" stop-color="#000000" stop-opacity="0.10"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></radialGradient>',
        f'    <radialGradient id="shBR" cx="0" cy="0" r="1"><stop offset="0%" stop-color="#000000" stop-opacity="0"/><stop offset="{inner_pct}" stop-color="#000000" stop-opacity="0.28"/><stop offset="{mid_pct}" stop-color="#000000" stop-opacity="0.10"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></radialGradient>',
        "  </defs>",
    ]

    # Core 9-slice frame: pure filled shapes, exact integer bounding boxes, zero strokes
    parts.append(f'  <rect id="{p}center" class="{fill_class}" x="{x0+r}" y="{y0+r}" width="{c}" height="{c}" fill="currentColor" fill-opacity="{fill_opacity}"/>')
    parts.append(
        f'  <g id="{p}top">'
        f'<rect class="{fill_class}" x="{x0+r}" y="{y0}" width="{c}" height="{r}" fill="currentColor" fill-opacity="{fill_opacity}"/>'
        f'<rect class="ColorScheme-Text" x="{x0+r}" y="{y0}" width="{c}" height="1" fill="currentColor" fill-opacity="{border_opacity}"/>'
        f'</g>'
    )
    parts.append(
        f'  <g id="{p}bottom">'
        f'<rect class="{fill_class}" x="{x0+r}" y="{y0+r+c}" width="{c}" height="{r}" fill="currentColor" fill-opacity="{fill_opacity}"/>'
        f'<rect class="ColorScheme-Text" x="{x0+r}" y="{y0+2*r+c-1}" width="{c}" height="1" fill="currentColor" fill-opacity="{border_opacity}"/>'
        f'</g>'
    )
    parts.append(
        f'  <g id="{p}left">'
        f'<rect class="{fill_class}" x="{x0}" y="{y0+r}" width="{r}" height="{c}" fill="currentColor" fill-opacity="{fill_opacity}"/>'
        f'<rect class="ColorScheme-Text" x="{x0}" y="{y0+r}" width="1" height="{c}" fill="currentColor" fill-opacity="{border_opacity}"/>'
        f'</g>'
    )
    parts.append(
        f'  <g id="{p}right">'
        f'<rect class="{fill_class}" x="{x0+r+c}" y="{y0+r}" width="{r}" height="{c}" fill="currentColor" fill-opacity="{fill_opacity}"/>'
        f'<rect class="ColorScheme-Text" x="{x0+2*r+c-1}" y="{y0+r}" width="1" height="{c}" fill="currentColor" fill-opacity="{border_opacity}"/>'
        f'</g>'
    )

    # Rounded corners with pure filled 1px border ring (exact r x r bounding box!)
    parts.append(
        f'  <g id="{p}topleft">'
        f'<path class="{fill_class}" d="M {x0},{y0+r} A {r},{r} 0 0 1 {x0+r},{y0} L {x0+r},{y0+r} Z" fill="currentColor" fill-opacity="{fill_opacity}"/>'
        f'<path class="ColorScheme-Text" d="M {x0},{y0+r} A {r},{r} 0 0 1 {x0+r},{y0} L {x0+r},{y0+1} A {ri},{ri} 0 0 0 {x0+1},{y0+r} Z" fill="currentColor" fill-opacity="{border_opacity}"/>'
        f'</g>'
    )
    parts.append(
        f'  <g id="{p}topright">'
        f'<path class="{fill_class}" d="M {x0+r+c},{y0} A {r},{r} 0 0 1 {x0+2*r+c},{y0+r} L {x0+r+c},{y0+r} Z" fill="currentColor" fill-opacity="{fill_opacity}"/>'
        f'<path class="ColorScheme-Text" d="M {x0+r+c},{y0} A {r},{r} 0 0 1 {x0+2*r+c},{y0+r} L {x0+2*r+c-1},{y0+r} A {ri},{ri} 0 0 0 {x0+r+c},{y0+1} Z" fill="currentColor" fill-opacity="{border_opacity}"/>'
        f'</g>'
    )
    parts.append(
        f'  <g id="{p}bottomleft">'
        f'<path class="{fill_class}" d="M {x0+r},{y0+2*r+c} A {r},{r} 0 0 1 {x0},{y0+r+c} L {x0+r},{y0+r+c} Z" fill="currentColor" fill-opacity="{fill_opacity}"/>'
        f'<path class="ColorScheme-Text" d="M {x0+r},{y0+2*r+c} A {r},{r} 0 0 1 {x0},{y0+r+c} L {x0+1},{y0+r+c} A {ri},{ri} 0 0 0 {x0+r},{y0+2*r+c-1} Z" fill="currentColor" fill-opacity="{border_opacity}"/>'
        f'</g>'
    )
    parts.append(
        f'  <g id="{p}bottomright">'
        f'<path class="{fill_class}" d="M {x0+2*r+c},{y0+r+c} A {r},{r} 0 0 1 {x0+r+c},{y0+2*r+c} L {x0+r+c},{y0+r+c} Z" fill="currentColor" fill-opacity="{fill_opacity}"/>'
        f'<path class="ColorScheme-Text" d="M {x0+2*r+c},{y0+r+c} A {r},{r} 0 0 1 {x0+r+c},{y0+2*r+c} L {x0+r+c},{y0+2*r+c-1} A {ri},{ri} 0 0 0 {x0+2*r+c-1},{y0+r+c} Z" fill="currentColor" fill-opacity="{border_opacity}"/>'
        f'</g>'
    )

    # Blur/window shape mask matching exact outer radius
    mx, my = 112, 16
    parts.append(f'  <rect id="mask-center" x="{mx+r}" y="{my+r}" width="{c}" height="{c}" fill="#000000"/>')
    parts.append(f'  <rect id="mask-top" x="{mx+r}" y="{my}" width="{c}" height="{r}" fill="#000000"/>')
    parts.append(f'  <rect id="mask-bottom" x="{mx+r}" y="{my+r+c}" width="{c}" height="{r}" fill="#000000"/>')
    parts.append(f'  <rect id="mask-left" x="{mx}" y="{my+r}" width="{r}" height="{c}" fill="#000000"/>')
    parts.append(f'  <rect id="mask-right" x="{mx+r+c}" y="{my+r}" width="{r}" height="{c}" fill="#000000"/>')
    parts.append(f'  <path id="mask-topleft" d="M {mx},{my+r} A {r},{r} 0 0 1 {mx+r},{my} L {mx+r},{my+r} Z" fill="#000000"/>')
    parts.append(f'  <path id="mask-topright" d="M {mx+r+c},{my} A {r},{r} 0 0 1 {mx+2*r+c},{my+r} L {mx+r+c},{my+r} Z" fill="#000000"/>')
    parts.append(f'  <path id="mask-bottomleft" d="M {mx+r},{my+2*r+c} A {r},{r} 0 0 1 {mx},{my+r+c} L {mx+r},{my+r+c} Z" fill="#000000"/>')
    parts.append(f'  <path id="mask-bottomright" d="M {mx+2*r+c},{my+r+c} A {r},{r} 0 0 1 {mx+r+c},{my+2*r+c} L {mx+r+c},{my+r+c} Z" fill="#000000"/>')

    # Content margins + explicit zero-inset markers (matching Breeze Plasma 6)
    parts.append(f'  <rect id="{p}hint-top-margin" x="4" y="4" width="2" height="{margin_v}" fill="#ff00ff"/>')
    parts.append(f'  <rect id="{p}hint-bottom-margin" x="8" y="4" width="2" height="{margin_v}" fill="#ff00ff"/>')
    parts.append(f'  <rect id="{p}hint-left-margin" x="4" y="20" width="{margin_h}" height="2" fill="#ff00ff"/>')
    parts.append(f'  <rect id="{p}hint-right-margin" x="4" y="24" width="{margin_h}" height="2" fill="#ff00ff"/>')
    parts.append('  <rect id="hint-top-inset" x="4" y="34" width="2" height="0.001" fill="#00ffff"/>')
    parts.append('  <rect id="hint-bottom-inset" x="8" y="34" width="2" height="0.001" fill="#00ffff"/>')
    parts.append('  <rect id="hint-left-inset" x="4" y="38" width="0.001" height="2" fill="#00ffff"/>')
    parts.append('  <rect id="hint-right-inset" x="8" y="38" width="0.001" height="2" fill="#00ffff"/>')
    parts.append('  <rect id="hint-tile-center" x="2" y="2" width="2" height="2" fill="#00ff00"/>')

    if include_thick:
        parts.append(f'  <rect id="thick-center" class="{fill_class}" x="148" y="102" width="24" height="24" fill="currentColor" fill-opacity="{fill_opacity}"/>')
        parts.append(f'  <rect id="thick-hint-top-margin" x="148" y="90" width="2" height="{margin_v + 2}" fill="#ff00ff"/>')
        parts.append(f'  <rect id="thick-hint-bottom-margin" x="154" y="90" width="2" height="{margin_v + 2}" fill="#ff00ff"/>')
        parts.append(f'  <rect id="thick-hint-left-margin" x="148" y="132" width="{margin_h}" height="2" fill="#ff00ff"/>')
        parts.append(f'  <rect id="thick-hint-right-margin" x="148" y="136" width="{margin_h}" height="2" fill="#ff00ff"/>')

    if include_shadow:
        sx, sy, sc = 16, 94, 16
        # Shadow edge tiles have depth s+r: outer s px gradient, inner r px transparent spacer
        parts.append(f'  <rect id="shadow-center" x="{sx+sr}" y="{sy+sr}" width="{sc}" height="{sc}" fill="none"/>')
        parts.append(
            f'  <g id="shadow-top">'
            f'<rect x="{sx+sr}" y="{sy}" width="{sc}" height="{s}" fill="url(#shTop)"/>'
            f'<rect x="{sx+sr}" y="{sy+s}" width="{sc}" height="{r}" fill="none"/>'
            f'</g>'
        )
        parts.append(
            f'  <g id="shadow-bottom">'
            f'<rect x="{sx+sr}" y="{sy+sr+sc}" width="{sc}" height="{r}" fill="none"/>'
            f'<rect x="{sx+sr}" y="{sy+sr+sc+r}" width="{sc}" height="{s}" fill="url(#shBottom)"/>'
            f'</g>'
        )
        parts.append(
            f'  <g id="shadow-left">'
            f'<rect x="{sx}" y="{sy+sr}" width="{s}" height="{sc}" fill="url(#shLeft)"/>'
            f'<rect x="{sx+s}" y="{sy+sr}" width="{r}" height="{sc}" fill="none"/>'
            f'</g>'
        )
        parts.append(
            f'  <g id="shadow-right">'
            f'<rect x="{sx+sr+sc}" y="{sy+sr}" width="{r}" height="{sc}" fill="none"/>'
            f'<rect x="{sx+sr+sc+r}" y="{sy+sr}" width="{s}" height="{sc}" fill="url(#shRight)"/>'
            f'</g>'
        )
        # Quarter-annulus corner shadows: exact (s+r) x (s+r) bbox, zero fill inside radius r!
        parts.append(
            f'  <g id="shadow-topleft">'
            f'<rect x="{sx}" y="{sy}" width="{sr}" height="{sr}" fill="none"/>'
            f'<path d="M {sx},{sy+sr} A {sr},{sr} 0 0 1 {sx+sr},{sy} L {sx+sr},{sy+s} A {r},{r} 0 0 0 {sx+s},{sy+sr} Z" fill="url(#shTL)"/>'
            f'</g>'
        )
        parts.append(
            f'  <g id="shadow-topright">'
            f'<rect x="{sx+sr+sc}" y="{sy}" width="{sr}" height="{sr}" fill="none"/>'
            f'<path d="M {sx+sr+sc},{sy} A {sr},{sr} 0 0 1 {sx+2*sr+sc},{sy+sr} L {sx+sr+sc+r},{sy+sr} A {r},{r} 0 0 0 {sx+sr+sc},{sy+s} Z" fill="url(#shTR)"/>'
            f'</g>'
        )
        parts.append(
            f'  <g id="shadow-bottomleft">'
            f'<rect x="{sx}" y="{sy+sr+sc}" width="{sr}" height="{sr}" fill="none"/>'
            f'<path d="M {sx+sr},{sy+2*sr+sc} A {sr},{sr} 0 0 1 {sx},{sy+sr+sc} L {sx+s},{sy+sr+sc} A {r},{r} 0 0 0 {sx+sr},{sy+sr+sc+r} Z" fill="url(#shBL)"/>'
            f'</g>'
        )
        parts.append(
            f'  <g id="shadow-bottomright">'
            f'<rect x="{sx+sr+sc}" y="{sy+sr+sc}" width="{sr}" height="{sr}" fill="none"/>'
            f'<path d="M {sx+2*sr+sc},{sy+sr+sc} A {sr},{sr} 0 0 1 {sx+sr+sc},{sy+2*sr+sc} L {sx+sr+sc},{sy+sr+sc+r} A {r},{r} 0 0 0 {sx+sr+sc+r},{sy+sr+sc} Z" fill="url(#shBR)"/>'
            f'</g>'
        )
        # Shadow margins & insets strictly equal s so shadow overhang is exact and curves around corners
        parts.append(f'  <rect id="shadow-hint-top-margin" x="96" y="94" width="2" height="{s}" fill="#ff00ff"/>')
        parts.append(f'  <rect id="shadow-hint-bottom-margin" x="100" y="94" width="2" height="{s}" fill="#ff00ff"/>')
        parts.append(f'  <rect id="shadow-hint-left-margin" x="96" y="114" width="{s}" height="2" fill="#ff00ff"/>')
        parts.append(f'  <rect id="shadow-hint-right-margin" x="96" y="118" width="{s}" height="2" fill="#ff00ff"/>')
        parts.append(f'  <rect id="shadow-hint-top-inset" x="116" y="94" width="2" height="{s}" fill="#00ffff"/>')
        parts.append(f'  <rect id="shadow-hint-bottom-inset" x="120" y="94" width="2" height="{s}" fill="#00ffff"/>')
        parts.append(f'  <rect id="shadow-hint-left-inset" x="116" y="114" width="{s}" height="2" fill="#00ffff"/>')
        parts.append(f'  <rect id="shadow-hint-right-inset" x="116" y="118" width="{s}" height="2" fill="#00ffff"/>')

    parts.append("</svg>\n")
    return "\n".join(parts)


def build_tasks_svg(palette: dict[str, str]) -> str:
    """Serpantinum dock tasks: invisible rest state, soft hover pill, single crisp indicator bar.

    Uses hint-stretch-borders so the indicator stretches cleanly as ONE single centered
    bar instead of tiling into duplicate dots across wide icon-task items, and provides
    all directional prefixes (south/default, north, east, west) plus progress state.
    """
    def state_block(prefix: str, x0: int, y: int, edge: str, bg_op: float, dot_class: str, dot_op: float) -> str:
        # 28x28 total tile: corners 6x6, center 16x16
        # Indicator sits centered along the panel's outer edge with subtle inset padding
        ind_top = (
            f'<rect class="{dot_class}" x="{x0+9}" y="{y+1}" width="10" height="2.5" rx="1.25" fill="currentColor" fill-opacity="{dot_op}"/>'
            if edge == "north" and dot_op > 0 else ""
        )
        ind_bot = (
            f'<rect class="{dot_class}" x="{x0+9}" y="{y+24.5}" width="10" height="2.5" rx="1.25" fill="currentColor" fill-opacity="{dot_op}"/>'
            if edge == "south" and dot_op > 0 else ""
        )
        ind_left = (
            f'<rect class="{dot_class}" x="{x0+1}" y="{y+9}" width="2.5" height="10" rx="1.25" fill="currentColor" fill-opacity="{dot_op}"/>'
            if edge == "west" and dot_op > 0 else ""
        )
        ind_right = (
            f'<rect class="{dot_class}" x="{x0+24.5}" y="{y+9}" width="2.5" height="10" rx="1.25" fill="currentColor" fill-opacity="{dot_op}"/>'
            if edge == "east" and dot_op > 0 else ""
        )
        return (
            f'  <rect id="{prefix}-center" class="ColorScheme-Text" x="{x0+6}" y="{y+6}" width="16" height="16" fill="currentColor" fill-opacity="{bg_op}"/>\n'
            f'  <g id="{prefix}-top"><rect class="ColorScheme-Text" x="{x0+6}" y="{y}" width="16" height="6" fill="currentColor" fill-opacity="{bg_op}"/>{ind_top}</g>\n'
            f'  <g id="{prefix}-bottom"><rect class="ColorScheme-Text" x="{x0+6}" y="{y+22}" width="16" height="6" fill="currentColor" fill-opacity="{bg_op}"/>{ind_bot}</g>\n'
            f'  <g id="{prefix}-left"><rect class="ColorScheme-Text" x="{x0}" y="{y+6}" width="6" height="16" fill="currentColor" fill-opacity="{bg_op}"/>{ind_left}</g>\n'
            f'  <g id="{prefix}-right"><rect class="ColorScheme-Text" x="{x0+22}" y="{y+6}" width="6" height="16" fill="currentColor" fill-opacity="{bg_op}"/>{ind_right}</g>\n'
            f'  <path id="{prefix}-topleft" class="ColorScheme-Text" d="M {x0},{y+6} A 6,6 0 0 1 {x0+6},{y} L {x0+6},{y+6} Z" fill="currentColor" fill-opacity="{bg_op}"/>\n'
            f'  <path id="{prefix}-topright" class="ColorScheme-Text" d="M {x0+22},{y} A 6,6 0 0 1 {x0+28},{y+6} L {x0+22},{y+6} Z" fill="currentColor" fill-opacity="{bg_op}"/>\n'
            f'  <path id="{prefix}-bottomleft" class="ColorScheme-Text" d="M {x0+6},{y+28} A 6,6 0 0 1 {x0},{y+22} L {x0+6},{y+22} Z" fill="currentColor" fill-opacity="{bg_op}"/>\n'
            f'  <path id="{prefix}-bottomright" class="ColorScheme-Text" d="M {x0+28},{y+22} A 6,6 0 0 1 {x0+22},{y+28} L {x0+22},{y+22} Z" fill="currentColor" fill-opacity="{bg_op}"/>'
        )

    states = [
        ("normal", 0.0, "ColorScheme-Text", 0.45),
        ("hover", 0.08, "ColorScheme-Highlight", 0.85),
        ("focus", 0.11, "ColorScheme-Highlight", 1.0),
        ("minimized", 0.0, "ColorScheme-Text", 0.22),
        ("attention", 0.14, "ColorScheme-NegativeText", 1.0),
        ("progress", 0.10, "ColorScheme-PositiveText", 0.95),
    ]
    blocks = []
    for col_idx, (dir_prefix, edge) in enumerate((("", "south"), ("north-", "north"), ("west-", "west"), ("east-", "east"))):
        x0 = 8 + col_idx * 40
        for row_idx, (name, bg_op, dot_cls, dot_op) in enumerate(states):
            blocks.append(state_block(f"{dir_prefix}{name}", x0, 8 + row_idx * 36, edge, bg_op, dot_cls, dot_op))

    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="184" height="236" viewBox="0 0 184 236">\n'
        f'  <defs>{_svg_style(palette)}</defs>\n'
        + "\n".join(blocks) + "\n"
        + '  <rect id="hint-stretch-borders" x="170" y="8" width="2" height="2" fill="#00ff00"/>\n'
        + '  <rect id="normal-hint-top-margin" x="170" y="16" width="2" height="4" fill="#ff00ff"/>\n'
        + '  <rect id="normal-hint-bottom-margin" x="174" y="16" width="2" height="5" fill="#ff00ff"/>\n'
        + '  <rect id="normal-hint-left-margin" x="170" y="26" width="5" height="2" fill="#ff00ff"/>\n'
        + '  <rect id="normal-hint-right-margin" x="170" y="30" width="5" height="2" fill="#ff00ff"/>\n'
        + '</svg>\n'
    )


def build_clock_svg(palette: dict[str, str]) -> str:
    """Serpantinum-inspired 12-lobed matte scalloped clock face with crisp pill hands."""
    import math
    points = []
    cx, cy = 64.0, 64.0
    for i in range(72):
        angle = (i / 72.0) * 2.0 * math.pi
        radius = 52.0 + 4.2 * math.cos(12.0 * angle)
        points.append(f"{cx + radius * math.cos(angle):.2f},{cy + radius * math.sin(angle):.2f}")
    scallop = "M " + " L ".join(points) + " Z"
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="160" height="128" viewBox="0 0 160 128">\n'
        f'  <defs>{_svg_style(palette)}</defs>\n'
        f'  <g id="ClockFace"><path class="ColorScheme-Background" d="{scallop}" fill="currentColor" stroke="{palette["border"]}" stroke-width="1.5"/></g>\n'
        '  <g id="HourHand"><rect class="ColorScheme-Highlight" x="136" y="24" width="6" height="32" rx="3" fill="currentColor"/></g>\n'
        '  <g id="MinuteHand"><rect class="ColorScheme-Text" x="146" y="14" width="5" height="42" rx="2.5" fill="currentColor"/></g>\n'
        f'  <g id="SecondHand"><circle cx="155" cy="22" r="3" fill="{palette["secondary"]}"/></g>\n'
        '  <g id="HandCenterScrew"><circle class="ColorScheme-Highlight" cx="139" cy="64" r="4" fill="currentColor"/></g>\n'
        '</svg>\n'
    )


def build_aurorae_decoration_svg(palette: dict[str, str]) -> str:
    """Pixel-exact KWin Aurorae window frame with soft shadow strictly in Padding*=12,
    razor-crisp 1px hairline border, r=10 rounded top corners, and flat maximized header."""
    bg = palette["mantle"]
    inactive = palette["inactiveHeader"]
    rim_active = blend_hex(palette["border"], palette["foreground"], 0.10)
    rim_inactive = blend_hex(palette["border"], inactive, 0.40)
    div_active = blend_hex(bg, palette["border"], 0.65)
    div_inactive = blend_hex(inactive, palette["border"], 0.40)

    s = 12   # Exact match for PaddingTop/Left/Right/Bottom=12
    r = 10   # Top corner radius inside the 32px titlebar
    ri = r - 1
    th = 32  # Exact match for TitleEdgeTop(4)+TitleHeight(24)+TitleEdgeBottom(4)
    sw = s + r   # 22px left/right tile width (12px shadow + 1px border + 9px behind client)
    top_h = s + th  # 44px top tile height (12px shadow + 32px titlebar)
    bot_h = s + 1   # 13px bottom tile height (1px hairline border + 12px shadow)
    cw, ch = 36, 36
    inner_pct = f"{(r / sw) * 100.0:.2f}%"
    mid_pct = f"{((r + s * 0.45) / sw) * 100.0:.2f}%"

    defs = (
        "  <defs>\n"
        '    <linearGradient id="aShTop" x1="0" y1="1" x2="0" y2="0"><stop offset="0%" stop-color="#000000" stop-opacity="0.26"/><stop offset="45%" stop-color="#000000" stop-opacity="0.09"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></linearGradient>\n'
        '    <linearGradient id="aShBot" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#000000" stop-opacity="0.38"/><stop offset="45%" stop-color="#000000" stop-opacity="0.14"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></linearGradient>\n'
        '    <linearGradient id="aShLeft" x1="1" y1="0" x2="0" y2="0"><stop offset="0%" stop-color="#000000" stop-opacity="0.28"/><stop offset="45%" stop-color="#000000" stop-opacity="0.10"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></linearGradient>\n'
        '    <linearGradient id="aShRight" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stop-color="#000000" stop-opacity="0.28"/><stop offset="45%" stop-color="#000000" stop-opacity="0.10"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></linearGradient>\n'
        f'    <radialGradient id="aShTL" cx="1" cy="1" r="1"><stop offset="0%" stop-color="#000000" stop-opacity="0"/><stop offset="{inner_pct}" stop-color="#000000" stop-opacity="0.26"/><stop offset="{mid_pct}" stop-color="#000000" stop-opacity="0.09"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></radialGradient>\n'
        f'    <radialGradient id="aShTR" cx="0" cy="1" r="1"><stop offset="0%" stop-color="#000000" stop-opacity="0"/><stop offset="{inner_pct}" stop-color="#000000" stop-opacity="0.26"/><stop offset="{mid_pct}" stop-color="#000000" stop-opacity="0.09"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></radialGradient>\n'
        '    <radialGradient id="aShBL" cx="1" cy="0" r="1"><stop offset="0%" stop-color="#000000" stop-opacity="0.34"/><stop offset="45%" stop-color="#000000" stop-opacity="0.12"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></radialGradient>\n'
        '    <radialGradient id="aShBR" cx="0" cy="0" r="1"><stop offset="0%" stop-color="#000000" stop-opacity="0.34"/><stop offset="45%" stop-color="#000000" stop-opacity="0.12"/><stop offset="100%" stop-color="#000000" stop-opacity="0"/></radialGradient>\n'
        "  </defs>"
    )

    def frame(prefix: str, ox: int, oy: int, fill: str, rim: str, div: str, *, is_mask: bool = False, shadow_op: float = 1.0) -> str:
        # Layout coordinates:
        # Left column: [ox, ox+sw], Center: [ox+sw, ox+sw+cw], Right: [ox+sw+cw, ox+2*sw+cw]
        # Top row: [oy, oy+top_h], Middle: [oy+top_h, oy+top_h+ch], Bottom: [oy+top_h+ch, oy+top_h+ch+bot_h]
        x_c = ox + sw
        x_r = ox + sw + cw
        y_m = oy + top_h
        y_b = oy + top_h + ch
        sh_attr = f' opacity="{shadow_op}"' if shadow_op < 1.0 else ""

        if is_mask:
            return (
                f'  <rect id="{prefix}-center" x="{x_c}" y="{y_m}" width="{cw}" height="{ch}" fill="#000000"/>\n'
                f'  <g id="{prefix}-top"><rect x="{x_c}" y="{oy}" width="{cw}" height="{top_h}" fill="none"/><rect x="{x_c}" y="{oy+s}" width="{cw}" height="{th}" fill="#000000"/></g>\n'
                f'  <g id="{prefix}-bottom"><rect x="{x_c}" y="{y_b}" width="{cw}" height="{bot_h}" fill="none"/><rect x="{x_c}" y="{y_b}" width="{cw}" height="1" fill="#000000"/></g>\n'
                f'  <g id="{prefix}-left"><rect x="{ox}" y="{y_m}" width="{sw}" height="{ch}" fill="none"/><rect x="{ox+s}" y="{y_m}" width="{r}" height="{ch}" fill="#000000"/></g>\n'
                f'  <g id="{prefix}-right"><rect x="{x_r}" y="{y_m}" width="{sw}" height="{ch}" fill="none"/><rect x="{x_r}" y="{y_m}" width="{r}" height="{ch}" fill="#000000"/></g>\n'
                f'  <g id="{prefix}-topleft"><rect x="{ox}" y="{oy}" width="{sw}" height="{top_h}" fill="none"/><path d="M {ox+s},{oy+s+r} A {r},{r} 0 0 1 {ox+sw},{oy+s} L {ox+sw},{y_m} L {ox+s},{y_m} Z" fill="#000000"/></g>\n'
                f'  <g id="{prefix}-topright"><rect x="{x_r}" y="{oy}" width="{sw}" height="{top_h}" fill="none"/><path d="M {x_r},{oy+s} A {r},{r} 0 0 1 {x_r+r},{oy+s+r} L {x_r+r},{y_m} L {x_r},{y_m} Z" fill="#000000"/></g>\n'
                f'  <g id="{prefix}-bottomleft"><rect x="{ox}" y="{y_b}" width="{sw}" height="{bot_h}" fill="none"/><rect x="{ox+s}" y="{y_b}" width="{r}" height="1" fill="#000000"/></g>\n'
                f'  <g id="{prefix}-bottomright"><rect x="{x_r}" y="{y_b}" width="{sw}" height="{bot_h}" fill="none"/><rect x="{x_r}" y="{y_b}" width="{r}" height="1" fill="#000000"/></g>'
            )

        return (
            f'  <rect id="{prefix}-center" x="{x_c}" y="{y_m}" width="{cw}" height="{ch}" fill="{fill}"/>\n'
            f'  <g id="{prefix}-top">'
            f'<rect x="{x_c}" y="{oy}" width="{cw}" height="{s}" fill="url(#aShTop)"{sh_attr}/>'
            f'<rect x="{x_c}" y="{oy+s}" width="{cw}" height="{th}" fill="{fill}"/>'
            f'<rect x="{x_c}" y="{oy+s}" width="{cw}" height="1" fill="{rim}"/>'
            f'<rect x="{x_c}" y="{y_m-1}" width="{cw}" height="1" fill="{div}"/>'
            f'</g>\n'
            f'  <g id="{prefix}-bottom">'
            f'<rect x="{x_c}" y="{y_b}" width="{cw}" height="1" fill="{rim}"/>'
            f'<rect x="{x_c}" y="{y_b+1}" width="{cw}" height="{s}" fill="url(#aShBot)"{sh_attr}/>'
            f'</g>\n'
            f'  <g id="{prefix}-left">'
            f'<rect x="{ox}" y="{y_m}" width="{s}" height="{ch}" fill="url(#aShLeft)"{sh_attr}/>'
            f'<rect x="{ox+s}" y="{y_m}" width="{r}" height="{ch}" fill="{fill}"/>'
            f'<rect x="{ox+s}" y="{y_m}" width="1" height="{ch}" fill="{rim}"/>'
            f'</g>\n'
            f'  <g id="{prefix}-right">'
            f'<rect x="{x_r}" y="{y_m}" width="{r}" height="{ch}" fill="{fill}"/>'
            f'<rect x="{x_r+r-1}" y="{y_m}" width="1" height="{ch}" fill="{rim}"/>'
            f'<rect x="{x_r+r}" y="{y_m}" width="{s}" height="{ch}" fill="url(#aShRight)"{sh_attr}/>'
            f'</g>\n'
            f'  <g id="{prefix}-topleft">'
            f'<rect x="{ox}" y="{oy}" width="{sw}" height="{top_h}" fill="none"/>'
            f'<path d="M {ox},{oy+sw} A {sw},{sw} 0 0 1 {ox+sw},{oy} L {ox+sw},{oy+s} A {r},{r} 0 0 0 {ox+s},{oy+sw} Z" fill="url(#aShTL)"{sh_attr}/>'
            f'<rect x="{ox}" y="{oy+sw}" width="{s}" height="{th-r}" fill="url(#aShLeft)"{sh_attr}/>'
            f'<path d="M {ox+s},{oy+sw} A {r},{r} 0 0 1 {ox+sw},{oy+s} L {ox+sw},{y_m} L {ox+s},{y_m} Z" fill="{fill}"/>'
            f'<path d="M {ox+s},{oy+sw} A {r},{r} 0 0 1 {ox+sw},{oy+s} L {ox+sw},{oy+s+1} A {ri},{ri} 0 0 0 {ox+s+1},{oy+sw} Z" fill="{rim}"/>'
            f'<rect x="{ox+s}" y="{oy+sw}" width="1" height="{th-r}" fill="{rim}"/>'
            f'<rect x="{ox+s+1}" y="{y_m-1}" width="{r-1}" height="1" fill="{div}"/>'
            f'</g>\n'
            f'  <g id="{prefix}-topright">'
            f'<rect x="{x_r}" y="{oy}" width="{sw}" height="{top_h}" fill="none"/>'
            f'<path d="M {x_r},{oy} A {sw},{sw} 0 0 1 {x_r+sw},{oy+sw} L {x_r+r},{oy+sw} A {r},{r} 0 0 0 {x_r},{oy+s} Z" fill="url(#aShTR)"{sh_attr}/>'
            f'<rect x="{x_r+r}" y="{oy+sw}" width="{s}" height="{th-r}" fill="url(#aShRight)"{sh_attr}/>'
            f'<path d="M {x_r},{oy+s} A {r},{r} 0 0 1 {x_r+r},{oy+sw} L {x_r+r},{y_m} L {x_r},{y_m} Z" fill="{fill}"/>'
            f'<path d="M {x_r},{oy+s} A {r},{r} 0 0 1 {x_r+r},{oy+sw} L {x_r+r-1},{oy+sw} A {ri},{ri} 0 0 0 {x_r},{oy+s+1} Z" fill="{rim}"/>'
            f'<rect x="{x_r+r-1}" y="{oy+sw}" width="1" height="{th-r}" fill="{rim}"/>'
            f'<rect x="{x_r}" y="{y_m-1}" width="{r-1}" height="1" fill="{div}"/>'
            f'</g>\n'
            f'  <g id="{prefix}-bottomleft">'
            f'<rect x="{ox}" y="{y_b}" width="{sw}" height="{bot_h}" fill="none"/>'
            f'<rect x="{ox}" y="{y_b}" width="{s}" height="{s}" fill="url(#aShBL)"{sh_attr}/>'
            f'<rect x="{ox+s}" y="{y_b}" width="{r}" height="1" fill="{rim}"/>'
            f'<rect x="{ox+s}" y="{y_b+1}" width="{r}" height="{s}" fill="url(#aShBot)"{sh_attr}/>'
            f'</g>\n'
            f'  <g id="{prefix}-bottomright">'
            f'<rect x="{x_r}" y="{y_b}" width="{sw}" height="{bot_h}" fill="none"/>'
            f'<rect x="{x_r+r}" y="{y_b}" width="{s}" height="{s}" fill="url(#aShBR)"{sh_attr}/>'
            f'<rect x="{x_r}" y="{y_b}" width="{r}" height="1" fill="{rim}"/>'
            f'<rect x="{x_r}" y="{y_b+1}" width="{r}" height="{s}" fill="url(#aShBot)"{sh_attr}/>'
            f'</g>'
        )

    # Maximized flat header frames (no outer padding, crisp bottom divider)
    max_active = (
        f'  <g id="decoration-maximized-center">'
        f'<rect x="12" y="116" width="48" height="{th}" fill="{bg}"/>'
        f'<rect x="12" y="{116+th-1}" width="48" height="1" fill="{div_active}"/>'
        f'</g>'
    )
    max_inactive = (
        f'  <g id="decoration-maximized-inactive-center">'
        f'<rect x="76" y="116" width="48" height="{th}" fill="{inactive}"/>'
        f'<rect x="76" y="{116+th-1}" width="48" height="1" fill="{div_inactive}"/>'
        f'</g>'
    )

    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="160" viewBox="0 0 320 160">\n'
        + defs + "\n"
        + frame("decoration", 12, 8, bg, rim_active, div_active, shadow_op=1.0) + "\n"
        + frame("decoration-inactive", 112, 8, inactive, rim_inactive, div_inactive, shadow_op=0.60) + "\n"
        + frame("mask", 212, 8, "#000000", "#000000", "#000000", is_mask=True) + "\n"
        + max_active + "\n"
        + max_inactive + "\n"
        + "</svg>\n"
    )


def build_aurorae_button_svg(kind: str, palette: dict[str, str]) -> str:
    """Minimalist Serpantinum-style window control buttons."""
    fg = palette["foreground"]
    muted = palette["muted"]
    hover_bg = palette["negative"] if kind == "close" else palette["accent"]
    hover_fg = on_color(hover_bg)
    press_bg = blend_hex(hover_bg, palette["void_"], 0.2)

    def glyph(cx: int, cy: int, color: str) -> str:
        if kind == "close":
            return f'<path d="M {cx-3.5},{cy-3.5} L {cx+3.5},{cy+3.5} M {cx+3.5},{cy-3.5} L {cx-3.5},{cy+3.5}" stroke="{color}" stroke-width="1.6" stroke-linecap="round"/>'
        if kind == "maximize":
            return f'<rect x="{cx-3.5}" y="{cy-3.5}" width="7" height="7" rx="1.6" fill="none" stroke="{color}" stroke-width="1.5"/>'
        if kind == "restore":
            return f'<rect x="{cx-4}" y="{cy-2}" width="5.5" height="5.5" rx="1.2" fill="none" stroke="{color}" stroke-width="1.4"/><path d="M {cx-1.5},{cy-4} H {cx+3.5} V {cy+1}" fill="none" stroke="{color}" stroke-width="1.4" stroke-linecap="round"/>'
        if kind == "minimize":
            return f'<path d="M {cx-4},{cy+1} H {cx+4}" stroke="{color}" stroke-width="1.6" stroke-linecap="round"/>'
        if kind == "keepabove":
            return f'<path d="M {cx-3.5},{cy+1.5} L {cx},{cy-2.5} L {cx+3.5},{cy+1.5}" fill="none" stroke="{color}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>'
        if kind == "keepbelow":
            return f'<path d="M {cx-3.5},{cy-1.5} L {cx},{cy+2.5} L {cx+3.5},{cy-1.5}" fill="none" stroke="{color}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>'
        return f'<circle cx="{cx}" cy="{cy}" r="3" fill="none" stroke="{color}" stroke-width="1.5"/>'

    states = [
        ("active-center", 12, "transparent", 0.0, fg),
        ("hover-center", 36, hover_bg, 0.96, hover_fg),
        ("pressed-center", 60, press_bg, 1.0, hover_fg),
        ("inactive-center", 84, "transparent", 0.0, muted),
        ("deactivated-center", 108, "transparent", 0.0, muted),
    ]
    rows = ['<svg xmlns="http://www.w3.org/2000/svg" width="120" height="24" viewBox="0 0 120 24">']
    for sid, cx, bg_col, bg_op, icon_col in states:
        rows.append(
            f'  <g id="{sid}">'
            f'<rect x="{cx-9}" y="3" width="18" height="18" rx="6" fill="{bg_col}" fill-opacity="{bg_op}"/>'
            f'{glyph(cx, 12, icon_col)}'
            f'</g>'
        )
    rows.append("</svg>\n")
    return "\n".join(rows)


def write_svgz(path: Path, svg_text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as stream:
            stream.write(svg_text.encode("utf-8"))


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def write_json(path: Path, payload: dict) -> None:
    write_text(path, json.dumps(payload, indent=4) + "\n")


def copy_asset(src: Path, dst: Path) -> None:
    """Copy a build input, tolerating a rebuild whose input already is the output."""
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() and src.resolve() == dst.resolve():
        return
    shutil.copy2(src, dst)


def install_file(src: Path, dst: Path) -> None:
    """Replace one installed file atomically, never writing through a symlink."""
    if dst.is_symlink():
        raise RuntimeError(f"Refusing to overwrite symlink: {dst}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    handle, staged = tempfile.mkstemp(dir=dst.parent, prefix=f".{dst.name}.")
    os.close(handle)
    try:
        shutil.copyfile(src, staged)
        os.chmod(staged, 0o644)
        os.replace(staged, dst)
    except BaseException:
        Path(staged).unlink(missing_ok=True)
        raise


def render_preview_images(target_dir: Path, palette: dict[str, str]) -> None:
    """Render genuine preview.png and fullscreenpreview.jpg for KDE System Settings."""
    target_dir.mkdir(parents=True, exist_ok=True)
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        if WALLPAPER_SRC.is_file():
            shutil.copy2(WALLPAPER_SRC, target_dir / "preview.png")
            shutil.copy2(WALLPAPER_SRC, target_dir / "fullscreenpreview.jpg")
        return

    w, h = 960, 540
    if WALLPAPER_SRC.is_file():
        bg = Image.open(WALLPAPER_SRC).convert("RGB").resize((w, h), Image.Resampling.LANCZOS)
    else:
        bg = Image.new("RGB", (w, h), hex_to_rgb(palette["void_"]))

    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    mantle = hex_to_rgb(palette["mantle"])
    void_ = hex_to_rgb(palette["void_"])
    elevated = hex_to_rgb(palette["elevated"])
    border = hex_to_rgb(palette["border"])
    accent = hex_to_rgb(palette["accent"])
    fg = hex_to_rgb(palette["foreground"])
    muted = hex_to_rgb(palette["muted"])

    # Top Serpantinum-inspired floating Aperture bar (unboxed widgets + inverted accent pills)
    draw.rounded_rectangle([16, 12, w - 16, 44], radius=10, fill=(*mantle, 242), outline=(*border, 180), width=1)
    # Wabi Sabi gold mark + workspace dots + active accent pill
    draw.ellipse([28, 22, 40, 34], fill=(233, 184, 114, 255))
    draw.ellipse([31, 24, 37, 30], fill=(16, 16, 22, 255))
    for idx in range(4):
        cx = 58 + idx * 14
        if idx == 0:
            draw.rounded_rectangle([cx - 6, 24, cx + 16, 32], radius=4, fill=(*accent, 255))
        else:
            x = cx + 12
            draw.ellipse([x - 3, 25, x + 3, 31], fill=(*muted, 140))
    # Center unboxed monospace clock indicator (time bar + accent dot + date bar)
    draw.rounded_rectangle([w // 2 - 52, 25, w // 2 - 8, 31], radius=3, fill=(*fg, 220))
    draw.ellipse([w // 2 - 2, 26, w // 2 + 2, 30], fill=(*accent, 255))
    draw.rounded_rectangle([w // 2 + 8, 25, w // 2 + 52, 31], radius=3, fill=(*muted, 180))
    # Right subtle tray dots + signature inverted accent VOL pill
    for idx in range(4):
        tx = w - 160 + idx * 16
        draw.ellipse([tx, 24, tx + 8, 32], fill=(*fg, 185))
    draw.rounded_rectangle([w - 92, 19, w - 26, 37], radius=7, fill=(*accent, 255))

    # Center Settings/Instrument matte window (matches Aurorae 1px hairline + 32px titlebar)
    wx0, wy0, wx1, wy1 = 150, 92, w - 150, h - 104
    draw.rounded_rectangle([wx0, wy0, wx1, wy1], radius=10, fill=(*void_, 248), outline=(*border, 235), width=1)
    # 32px matte titlebar + window control glyphs
    draw.rounded_rectangle([wx0 + 1, wy0 + 1, wx1 - 1, wy0 + 30], radius=9, fill=(*mantle, 255))
    draw.line([wx0 + 1, wy0 + 30, wx1 - 1, wy0 + 30], fill=(*border, 190), width=1)
    for idx, col in enumerate((muted, muted, palette["negative"])):
        bx = wx1 - 62 + idx * 18
        rgb_b = hex_to_rgb(col) if isinstance(col, str) else col
        draw.rounded_rectangle([bx, wy0 + 11, bx + 10, wy0 + 21], radius=3, fill=(*rgb_b, 200))
    # Sidebar
    draw.rectangle([wx0 + 1, wy0 + 31, wx0 + 148, wy1 - 1], fill=(*mantle, 245))
    draw.rounded_rectangle([wx0 + 14, wy0 + 48, wx0 + 134, wy0 + 76], radius=8, fill=(*accent, 255))
    for row in range(4):
        y = wy0 + 90 + row * 34
        draw.rounded_rectangle([wx0 + 14, y, wx0 + 134, y + 24], radius=7, fill=(*elevated, 140))
    # Main content cards
    draw.rounded_rectangle([wx0 + 166, wy0 + 46, wx1 - 24, wy0 + 136], radius=10, fill=(*mantle, 235), outline=(*border, 180), width=1)
    for idx, swatch in enumerate((palette["accent"], palette["secondary"], palette["positive"], palette["neutral"], palette["negative"], palette["visited"])):
        sx = wx0 + 188 + idx * 28
        draw.ellipse([sx, wy0 + 102, sx + 16, wy0 + 118], fill=(*hex_to_rgb(swatch), 255))
    for card in range(3):
        cy0 = wy0 + 150 + card * 54
        draw.rounded_rectangle([wx0 + 166, cy0, wx1 - 24, cy0 + 42], radius=10, fill=(*elevated, 210), outline=(*border, 175), width=1)
        draw.rounded_rectangle([wx1 - 92, cy0 + 9, wx1 - 38, cy0 + 33], radius=8, fill=(*(accent if card == 0 else void_), 240))

    # Bottom Serpantinum floating dock with single crisp indicator bars
    dw = 296
    dx0 = (w - dw) // 2
    draw.rounded_rectangle([dx0, h - 58, dx0 + dw, h - 14], radius=10, fill=(*mantle, 240), outline=(*border, 185), width=1)
    dock_colors = [palette["accent"], palette["secondary"], palette["positive"], palette["neutral"], palette["negative"], palette["visited"], palette["foreground"]]
    for idx, col in enumerate(dock_colors):
        ix = dx0 + 18 + idx * 38
        draw.rounded_rectangle([ix, h - 49, ix + 28, h - 25], radius=7, fill=(*hex_to_rgb(col), 232))
        if idx == 1:
            draw.rounded_rectangle([ix + 8, h - 20, ix + 20, h - 17], radius=1, fill=(*accent, 255))
        elif idx == 3:
            draw.rounded_rectangle([ix + 10, h - 20, ix + 18, h - 17], radius=1, fill=(*muted, 200))

    composed = Image.alpha_composite(bg.convert("RGBA"), overlay).convert("RGB")
    composed.save(target_dir / "fullscreenpreview.jpg", "JPEG", quality=92)
    composed.resize((480, 270), Image.Resampling.LANCZOS).save(target_dir / "preview.png", "PNG")


def write_aurorae_theme(output_root: Path, name: str, display_name: str, tone: str, palette: dict[str, str]) -> None:
    aur = output_root / "aurorae/themes" / name
    write_json(aur / "metadata.json", {
        "KPackageStructure": "aurorae",
        "KPlugin": {
            "Authors": [{"Name": "Tonantzintla Contributors"}],
            "Category": "Plasma 6 Window Decorations",
            "Description": f"Serpantinum-refined matte {tone} window decoration for Tonantzintla",
            "EnabledByDefault": True,
            "Id": name,
            "License": "GPL-3.0-or-later",
            "Name": display_name,
            "ServiceTypes": ["aurorae"],
            "Version": "1.2.0",
        },
    })
    write_text(
        aur / f"{name}rc",
        "[General]\n"
        f"ActiveTextColor={rgb_csv(palette['foreground'])}\n"
        f"InactiveTextColor={rgb_csv(palette['muted'])}\n"
        "Animation=140\n"
        "LeftButtons=\n"
        "RightButtons=IAX\n"
        "Shadow=true\n"
        "TitleAlignment=Center\n"
        "TitleVerticalAlignment=Center\n"
        "UseTextShadow=false\n\n"
        "[Layout]\n"
        "BorderBottom=1\n"
        "BorderLeft=1\n"
        "BorderRight=1\n"
        "ButtonHeight=20\n"
        "ButtonWidth=20\n"
        "ButtonMarginTop=4\n"
        "ButtonMarginBottom=4\n"
        "ButtonMarginLeft=4\n"
        "ButtonMarginRight=4\n"
        "ButtonSpacing=6\n"
        "ExplicitButtonSpacer=8\n"
        "PaddingBottom=12\n"
        "PaddingLeft=12\n"
        "PaddingRight=12\n"
        "PaddingTop=12\n"
        # Aurorae centers the caption in the space left of the buttons. Reserving most of a
        # three-button group on the left puts it within a few pixels of the window's center,
        # for full windows and for single-button dialogs alike.
        "TitleBorderLeft=58\n"
        "TitleBorderRight=12\n"
        "TitleEdgeBottom=4\n"
        "TitleEdgeBottomMaximized=4\n"
        "TitleEdgeLeft=10\n"
        "TitleEdgeLeftMaximized=10\n"
        "TitleEdgeRight=10\n"
        "TitleEdgeRightMaximized=10\n"
        "TitleEdgeTop=4\n"
        "TitleEdgeTopMaximized=4\n"
        "TitleHeight=24\n",
    )
    write_text(aur / "decoration.svg", build_aurorae_decoration_svg(palette))
    for btn in ("close", "maximize", "restore", "minimize", "keepabove", "keepbelow", "alldesktops"):
        write_text(aur / f"{btn}.svg", build_aurorae_button_svg(btn, palette))


def build_tree(output_root: Path, settings: dict | None = None, matugen: dict | None = None) -> None:
    """Materialize the complete native KDE Plasma 6 Global Theme tree under output_root."""
    dark = resolve_palette("dark", settings, matugen)
    light = resolve_palette("light", settings, matugen)

    # 0. Native Plasma 6 Plasmoids (Serpantinum bar widgets) + GLSL .frag.qsb shaders + real Wabi Sabi app icon
    build_plasmoids(output_root, dark)
    compile_shaders(output_root, fallback_root=PLASMA_SRC)
    if MARK_SRC.is_file():
        copy_asset(MARK_SRC, output_root / "icons/hicolor/scalable/apps/tonantzintla-mark.svg")

    # 1. Color schemes
    write_text(
        output_root / "color-schemes/TonantzintlaDark.colors",
        render_color_scheme("TonantzintlaDark", "Tonantzintla Dark", dark, "dark"),
    )
    write_text(
        output_root / "color-schemes/TonantzintlaLight.colors",
        render_color_scheme("TonantzintlaLight", "Tonantzintla Light", light, "light"),
    )

    # 2. Plasma Desktop Theme (Plasma Style)
    dt = output_root / "desktoptheme" / THEME_ID
    write_json(dt / "metadata.json", {
        "KPackageStructure": "Plasma/Theme",
        "KPlugin": {
            "Authors": [{"Name": "Tonantzintla Contributors"}],
            "Description": "Serpantinum-refined matte obsidian Plasma 6 desktop style for Tonantzintla",
            "EnabledByDefault": True,
            "Id": THEME_ID,
            "License": "GPL-3.0-or-later",
            "Name": "Tonantzintla",
            "Version": "1.2.0",
            "Website": "https://github.com/deltadasher/Tonantzintla",
        },
        "X-Plasma-API": "5.0",
    })
    write_text(dt / "colors", render_color_scheme("TonantzintlaDark", "Tonantzintla Dark", dark, "dark"))
    # Omit ContrastEffect (matching Plasma 6 Breeze) to avoid washed-out halos behind matte dark panels
    write_text(
        dt / "plasmarc",
        "[Wallpaper]\n"
        f"defaultWallpaperTheme={WALLPAPER_NAME}\n"
        "defaultFileSuffix=.png\n"
        "defaultWidth=3840\n"
        "defaultHeight=2160\n\n"
        "[AdaptiveTransparency]\n"
        "enabled=true\n",
    )

    # Remove any legacy partial widget overrides so Plasma 6 cleanly inherits complete
    # state-aware Breeze widget SVGs (hover/pressed/focus/south-tab) recolored with our palette.
    for obsolete in (
        "widgets/button.svgz",
        "widgets/lineedit.svgz",
        "widgets/tabbar.svgz",
        "widgets/slider.svgz",
        "widgets/bar_meter_horizontal.svgz",
        "widgets/bar_meter_vertical.svgz",
        "widgets/switch.svgz",
        "widgets/scrollbar.svgz",
    ):
        stale = dt / obsolete
        if stale.exists() and not stale.is_symlink():
            stale.unlink()

    # 9-slice frames (standard, translucent, opaque) — pure filled geometry, corner-hugging gradient shadows
    panel_std = build_frame_svg(dark, radius=10, fill_opacity=0.96, margin_v=4, margin_h=12, include_shadow=True, include_thick=True, border_opacity=0.085)
    panel_tr = build_frame_svg(dark, radius=10, fill_opacity=0.92, margin_v=4, margin_h=12, include_shadow=True, include_thick=True, border_opacity=0.095)
    panel_op = build_frame_svg(dark, radius=10, fill_opacity=1.0, margin_v=4, margin_h=12, include_shadow=True, include_thick=True, border_opacity=0.085)
    dialog_std = build_frame_svg(dark, radius=14, fill_opacity=0.97, margin_v=12, margin_h=12, include_shadow=True, border_opacity=0.095)
    dialog_tr = build_frame_svg(dark, radius=14, fill_opacity=0.93, margin_v=12, margin_h=12, include_shadow=True, border_opacity=0.10)
    dialog_op = build_frame_svg(dark, radius=14, fill_opacity=1.0, margin_v=12, margin_h=12, include_shadow=True, border_opacity=0.095)
    tooltip_std = build_frame_svg(dark, radius=10, fill_opacity=0.97, margin_v=8, margin_h=10, include_shadow=True, border_opacity=0.10)
    tooltip_tr = build_frame_svg(dark, radius=10, fill_opacity=0.93, margin_v=8, margin_h=10, include_shadow=True, border_opacity=0.11)
    tooltip_op = build_frame_svg(dark, radius=10, fill_opacity=1.0, margin_v=8, margin_h=10, include_shadow=True, border_opacity=0.10)
    widget_bg = build_frame_svg(dark, radius=12, fill_opacity=0.95, margin_v=10, margin_h=10, include_shadow=True, border_opacity=0.08)

    write_svgz(dt / "widgets/panel-background.svgz", panel_std)
    write_svgz(dt / "translucent/widgets/panel-background.svgz", panel_tr)
    write_svgz(dt / "opaque/widgets/panel-background.svgz", panel_op)
    write_svgz(dt / "dialogs/background.svgz", dialog_std)
    write_svgz(dt / "translucent/dialogs/background.svgz", dialog_tr)
    write_svgz(dt / "opaque/dialogs/background.svgz", dialog_op)
    write_svgz(dt / "widgets/tooltip.svgz", tooltip_std)
    write_svgz(dt / "translucent/widgets/tooltip.svgz", tooltip_tr)
    write_svgz(dt / "opaque/widgets/tooltip.svgz", tooltip_op)
    write_svgz(dt / "widgets/background.svgz", widget_bg)
    write_svgz(dt / "widgets/tasks.svgz", build_tasks_svg(dark))
    write_svgz(dt / "widgets/clock.svgz", build_clock_svg(dark))
    if MARK_SRC.is_file():
        write_svgz(dt / "widgets/branding.svgz", MARK_SRC.read_text(encoding="utf-8"))

    # 3. Aurorae KWin window decorations, one per color scheme so title bars match their windows
    write_aurorae_theme(output_root, AURORAE_NAME, "Tonantzintla", "dark", dark)
    write_aurorae_theme(output_root, AURORAE_LIGHT_NAME, "Tonantzintla Light", "light", light)

    # 4. Wallpaper KPackage
    wp = output_root / "wallpapers" / WALLPAPER_NAME
    write_json(wp / "metadata.json", {
        "KPackageStructure": "Plasma/Image",
        "KPlugin": {
            "Authors": [{"Name": "Tonantzintla Contributors"}],
            "Id": WALLPAPER_NAME,
            "License": "GPL-3.0-or-later",
            "Name": "Tonantzintla Observatory",
        },
    })
    if WALLPAPER_SRC.is_file():
        copy_asset(WALLPAPER_SRC, wp / "contents/images/3840x2160.png")

    # 5. Look-and-Feel (KDE Plasma 6 Global Theme)
    lnf = output_root / "look-and-feel" / LOOK_AND_FEEL_ID
    write_json(lnf / "metadata.json", {
        "KPackageStructure": "Plasma/LookAndFeel",
        "KPlugin": {
            "Authors": [{"Name": "Tonantzintla Contributors"}],
            "Category": "",
            "Description": "Tonantzintla global KDE Plasma 6 theme with Serpantinum-refined matte surfaces, floating top bar, and centered dock",
            "Id": LOOK_AND_FEEL_ID,
            "License": "GPL-3.0-or-later",
            "Name": "Tonantzintla",
            "Version": "1.2.0",
            "Website": "https://github.com/deltadasher/Tonantzintla",
        },
        "Keywords": "Desktop;Workspace;Appearance;Look and Feel;Tonantzintla;Serpantinum;",
        "X-KDE-fallbackPackage": "org.kde.breezedark.desktop",
        "X-Plasma-APIVersion": "2",
    })
    write_text(
        lnf / "contents/defaults",
        "[kdeglobals][General]\n"
        "ColorScheme=TonantzintlaDark\n"
        "font=JetBrains Mono,10,-1,5,400,0,0,0,0,0\n"
        "fixed=JetBrains Mono,10,-1,5,400,0,0,0,0,0\n"
        "menuFont=JetBrains Mono,10,-1,5,400,0,0,0,0,0\n"
        "smallestReadableFont=JetBrains Mono,8,-1,5,400,0,0,0,0,0\n"
        "toolBarFont=JetBrains Mono,10,-1,5,400,0,0,0,0,0\n\n"
        "[kdeglobals][KDE]\n"
        "widgetStyle=Breeze\n\n"
        "[plasmarc][Theme]\n"
        f"name={THEME_ID}\n\n"
        "[kwinrc][org.kde.kdecoration2]\n"
        # Aurorae pads every border to 4px at the Normal size; Tiny is what keeps the 1px hairline.
        "BorderSize=Tiny\n"
        "BorderSizeAuto=false\n"
        "ButtonsOnLeft=\n"
        "ButtonsOnRight=IAX\n"
        "library=org.kde.kwin.aurorae\n"
        f"theme=__aurorae__svg__{AURORAE_NAME}\n\n"
        "[KSplash]\n"
        "Engine=KSplashQML\n"
        f"Theme={LOOK_AND_FEEL_ID}\n\n"
        "[Wallpaper]\n"
        f"Image={WALLPAPER_NAME}\n",
    )
    write_text(
        lnf / "contents/layouts/org.kde.plasma.desktop-layout.js",
        "// Tonantzintla KDE Plasma 6 layout: Serpantinum-refined floating top Aperture bar + centered bottom dock.\n"
        "var topBar = new Panel();\n"
        "topBar.location = 'top';\n"
        "topBar.height = 38;\n"
        "topBar.floating = true;\n"
        "topBar.hiding = 'none';\n"
        "topBar.alignment = 'center';\n"
        "topBar.lengthMode = 'fill';\n\n"
        "var launcher = topBar.addWidget('org.tonantzintla.launcher');\n"
        "launcher.globalShortcut = 'Alt+F1';\n\n"
        "topBar.addWidget('org.tonantzintla.workspaces');\n"
        "topBar.addWidget('org.tonantzintla.media');\n"
        "topBar.addWidget('org.kde.plasma.panelspacer');\n"
        "topBar.addWidget('org.tonantzintla.clock');\n"
        "topBar.addWidget('org.kde.plasma.panelspacer');\n"
        "var tray = topBar.addWidget('org.kde.plasma.systemtray');\n"
        "tray.currentConfigGroup = ['General'];\n"
        "tray.writeConfig('hiddenItems', 'org.kde.plasma.volume,org.kde.plasma.mediacontroller,org.kde.plasma.battery');\n"
        "topBar.addWidget('org.tonantzintla.status');\n\n"
        "var dock = new Panel();\n"
        "dock.location = 'bottom';\n"
        "dock.height = 54;\n"
        "dock.floating = true;\n"
        "dock.hiding = 'dodgewindows';\n"
        "dock.alignment = 'center';\n"
        "dock.lengthMode = 'fit';\n\n"
        "var tasks = dock.addWidget('org.kde.plasma.icontasks');\n"
        "tasks.currentConfigGroup = ['General'];\n"
        "tasks.writeConfig('groupingStrategy', 1);\n"
        "tasks.writeConfig('indicateAudioStreams', true);\n"
        "tasks.writeConfig('maxStripes', 1);\n\n"
        "var desktopsArray = desktopsForActivity(currentActivity());\n"
        "for (var i = 0; i < desktopsArray.length; i++) {\n"
        "    desktopsArray[i].wallpaperPlugin = 'org.kde.image';\n"
        "}\n",
    )
    if MARK_SRC.is_file():
        copy_asset(MARK_SRC, lnf / "contents/splash/images/wabi-sabi.svg")
    write_text(lnf / "contents/splash/Splash.qml", render_splash_qml(dark))
    render_preview_images(lnf / "contents/previews", dark)


def copy_package(src: Path, dst: Path) -> None:
    if dst.is_symlink():
        raise RuntimeError(f"Refusing to overwrite symlink: {dst}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=dst.parent, prefix=".tonantzintla-plasma-") as staging:
        stage_target = Path(staging) / dst.name
        shutil.copytree(src, stage_target)
        backup = None
        try:
            if dst.exists():
                backup = dst.parent / f".{dst.name}.old-{os.getpid()}"
                if backup.exists():
                    shutil.rmtree(backup)
                dst.rename(backup)
            stage_target.rename(dst)
        except Exception:
            if backup is not None and backup.exists() and not dst.exists():
                backup.rename(dst)
            raise
        finally:
            if backup is not None and backup.exists():
                shutil.rmtree(backup, ignore_errors=True)


def install_theme(data_home: Path, *, sync_palette: bool = False) -> dict:
    with tempfile.TemporaryDirectory(prefix="tonantzintla-plasma-stage-") as tmp:
        stage = Path(tmp)
        settings = load_json_dict(xdg_config_home() / "tonantzintla/settings.json") if sync_palette else {}
        mode = settings.get("themeMode", "dark") if isinstance(settings.get("themeMode"), str) else "dark"
        cache_name = "palette-light.json" if mode == "light" else "palette.json"
        matugen = load_json_dict(xdg_cache_home() / "tonantzintla" / cache_name) if sync_palette else {}
        if sync_palette or not (PLASMA_SRC / "look-and-feel" / LOOK_AND_FEEL_ID / "metadata.json").is_file():
            build_tree(stage, settings, matugen)
            source = stage
        else:
            source = PLASMA_SRC

        colors_dst = data_home / "color-schemes"
        colors_dst.mkdir(parents=True, exist_ok=True)
        for scheme in COLOR_SCHEMES:
            install_file(source / "color-schemes" / f"{scheme}.colors", colors_dst / f"{scheme}.colors")

        copy_package(source / "desktoptheme" / THEME_ID, data_home / "plasma/desktoptheme" / THEME_ID)
        for aurorae in AURORAE_THEMES:
            copy_package(source / "aurorae/themes" / aurorae, data_home / "aurorae/themes" / aurorae)
        copy_package(source / "wallpapers" / WALLPAPER_NAME, data_home / "wallpapers" / WALLPAPER_NAME)
        copy_package(source / "look-and-feel" / LOOK_AND_FEEL_ID, data_home / "plasma/look-and-feel" / LOOK_AND_FEEL_ID)
        for pid in PLASMOID_IDS:
            copy_package(source / "plasmoids" / pid, data_home / "plasma/plasmoids" / pid)
        icon_src = source / "icons/hicolor/scalable/apps/tonantzintla-mark.svg"
        if icon_src.is_file():
            install_file(icon_src, data_home / "icons/hicolor/scalable/apps/tonantzintla-mark.svg")

    return {
        "ok": True,
        "installed_to": str(data_home),
        "look_and_feel": LOOK_AND_FEEL_ID,
        "desktop_theme": THEME_ID,
        "plasmoids": list(PLASMOID_IDS),
        "color_schemes": list(COLOR_SCHEMES),
        "window_decorations": list(AURORAE_THEMES),
        "wallpaper": WALLPAPER_NAME,
        "synced_palette": sync_palette,
    }


def _read_setting(file_name: str, group: str, key: str) -> str:
    result = subprocess.run(
        ["kreadconfig6", "--file", file_name, "--group", group, "--key", key],
        capture_output=True, text=True, timeout=10, check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def _write_setting(file_name: str, group: str, key: str, value: str | None, *, kind: str | None = None) -> None:
    command = ["kwriteconfig6", "--file", file_name, "--group", group, "--key", key]
    if value is None:
        command.append("--delete")
    else:
        if kind:
            command += ["--type", kind]
        command.append(value)
    subprocess.run(command, capture_output=True, timeout=10, check=False)


def release_active_settings(data_home: Path) -> list[str]:
    """Hand back to Breeze every setting that still names a package about to be removed.

    Without this, uninstalling the active theme leaves windows without a usable
    decoration and panels without a style until the user finds the right settings page.
    Only the real data home is treated as live; a custom --data-home is a staging prefix.
    """
    if data_home.resolve() != xdg_data_home().resolve():
        return []
    if not (shutil.which("kreadconfig6") and shutil.which("kwriteconfig6")):
        return []

    released = []
    decoration = _read_setting("kwinrc", "org.kde.kdecoration2", "theme")
    if decoration in {f"__aurorae__svg__{name}" for name in AURORAE_THEMES}:
        _write_setting("kwinrc", "org.kde.kdecoration2", "library", "org.kde.breeze")
        _write_setting("kwinrc", "org.kde.kdecoration2", "theme", "Breeze")
        _write_setting("kwinrc", "org.kde.kdecoration2", "BorderSize", None)
        _write_setting("kwinrc", "org.kde.kdecoration2", "BorderSizeAuto", None)
        released.append("window-decoration")
    if _read_setting("plasmarc", "Theme", "name") == THEME_ID:
        _write_setting("plasmarc", "Theme", "name", "default")
        released.append("plasma-style")
    scheme = _read_setting("kdeglobals", "General", "ColorScheme")
    if scheme in COLOR_SCHEMES:
        fallback = "BreezeLight" if scheme.endswith("Light") else "BreezeDark"
        if shutil.which("plasma-apply-colorscheme"):
            subprocess.run(["plasma-apply-colorscheme", fallback], capture_output=True, timeout=15, check=False)
        else:
            _write_setting("kdeglobals", "General", "ColorScheme", fallback)
        released.append(f"colorscheme:{fallback}")
    if _read_setting("kdeglobals", "KDE", "LookAndFeelPackage") == LOOK_AND_FEEL_ID:
        _write_setting("kdeglobals", "KDE", "LookAndFeelPackage", "org.kde.breezedark.desktop")
        released.append("global-theme")
    if released and shutil.which("qdbus6"):
        subprocess.run(["qdbus6", "org.kde.KWin", "/KWin", "reconfigure"], capture_output=True, timeout=10, check=False)
    return released


def layout_uses_theme_widgets(config_home: Path) -> bool:
    try:
        text = (config_home / LAYOUT_FILES[0]).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return False
    return any(f"plugin={plasmoid}" in text for plasmoid in PLASMOID_IDS)


def uninstall_theme(data_home: Path) -> dict:
    released = release_active_settings(data_home)
    removed = []
    targets = [
        data_home / "color-schemes/TonantzintlaDark.colors",
        data_home / "color-schemes/TonantzintlaLight.colors",
        data_home / "icons/hicolor/scalable/apps/tonantzintla-mark.svg",
        data_home / "plasma/desktoptheme" / THEME_ID,
        *[data_home / "aurorae/themes" / aurorae for aurorae in AURORAE_THEMES],
        data_home / "wallpapers" / WALLPAPER_NAME,
        data_home / "plasma/look-and-feel" / LOOK_AND_FEEL_ID,
        *[data_home / "plasma/plasmoids" / pid for pid in PLASMOID_IDS],
    ]
    for target in targets:
        if target.is_symlink():
            continue
        if target.is_dir():
            shutil.rmtree(target)
            removed.append(str(target))
        elif target.is_file():
            target.unlink()
            removed.append(str(target))
    payload = {"ok": True, "removed": removed, "released_settings": released}
    if data_home.resolve() == xdg_data_home().resolve() and layout_uses_theme_widgets(xdg_config_home()):
        payload["note"] = (
            "Your panels still contain Tonantzintla widgets, which are now gone. "
            "Run 'restore-layout' to bring back the layout saved before the theme was applied, "
            "or replace them from the panel's edit mode."
        )
    return payload


def layout_backup_root() -> Path:
    return xdg_state_home() / "tonantzintla/plasma-layouts"


def list_layout_backups() -> list[Path]:
    root = layout_backup_root()
    if not root.is_dir() or root.is_symlink():
        return []
    return sorted(entry for entry in root.iterdir() if entry.is_dir() and not entry.is_symlink())


def backup_layout(config_home: Path) -> Path | None:
    """Copy the user's current panel layout aside before a Global Theme layout reset replaces it."""
    sources = [config_home / name for name in LAYOUT_FILES]
    sources = [path for path in sources if path.is_file() and not path.is_symlink()]
    if not sources:
        return None
    root = layout_backup_root()
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    target = root / time.strftime("%Y%m%d-%H%M%S")
    suffix = 1
    while target.exists():
        suffix += 1
        target = root / f"{time.strftime('%Y%m%d-%H%M%S')}-{suffix}"
    target.mkdir(mode=0o700)
    for path in sources:
        shutil.copyfile(path, target / path.name)
        os.chmod(target / path.name, 0o600)
    for stale in list_layout_backups()[:-LAYOUT_BACKUPS_KEPT]:
        shutil.rmtree(stale, ignore_errors=True)
    return target


def _plasmashell_service_active() -> bool:
    if not shutil.which("systemctl"):
        return False
    active = subprocess.run(
        ["systemctl", "--user", "is-active", "plasma-plasmashell.service"],
        capture_output=True, text=True, timeout=5, check=False,
    )
    return active.returncode == 0 and active.stdout.strip() == "active"


def _running_shell_config_home() -> Path | None:
    """The config directory the running plasmashell reads, or None when no shell is running."""
    if not shutil.which("pgrep"):
        return None
    found = subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "plasmashell"],
                           capture_output=True, text=True, timeout=5, check=False)
    for pid in found.stdout.split():
        try:
            entries = Path(f"/proc/{pid}/environ").read_bytes().split(b"\0")
        except OSError:
            continue
        env = dict(entry.decode("utf-8", "replace").split("=", 1) for entry in entries if b"=" in entry)
        if env.get("XDG_CONFIG_HOME"):
            return Path(env["XDG_CONFIG_HOME"])
        return Path(env.get("HOME") or Path.home()) / ".config"
    return None


def restore_layout(config_home: Path) -> dict:
    """Put back the newest saved panel layout.

    plasmashell rewrites its layout file when it exits, so a shell that owns
    this config directory has to be down while the files are replaced. That is
    only done through its systemd unit; a shell started any other way is left
    alone and reported, and a shell using some other config directory is never
    touched at all.
    """
    backups = list_layout_backups()
    if not backups:
        return {"ok": False, "error": "No saved Plasma layout was found."}
    newest = backups[-1]
    shell_home = _running_shell_config_home()
    shell_owns_config = shell_home is not None and shell_home.resolve() == config_home.resolve()
    managed = shell_owns_config and _plasmashell_service_active()
    if shell_owns_config and not managed:
        return {
            "ok": False,
            "error": "plasmashell is running outside systemd and would overwrite the restored layout on exit.",
            "backup": str(newest),
            "hint": f"Quit plasmashell, copy the files in {newest} to {config_home}, then start plasmashell again.",
        }
    if managed:
        subprocess.run(["systemctl", "--user", "stop", "plasma-plasmashell.service"],
                       capture_output=True, timeout=20, check=False)
    restored = []
    try:
        for name in LAYOUT_FILES:
            saved = newest / name
            if saved.is_file() and not saved.is_symlink():
                install_file(saved, config_home / name)
                os.chmod(config_home / name, 0o600)
                restored.append(name)
    finally:
        if managed:
            subprocess.run(["systemctl", "--user", "start", "plasma-plasmashell.service"],
                           capture_output=True, timeout=20, check=False)
    return {"ok": bool(restored), "restored": restored, "from": str(newest), "plasmashell_restarted": managed}


def plasma_version() -> tuple[int, ...] | None:
    if not shutil.which("plasmashell"):
        return None
    try:
        result = subprocess.run(["plasmashell", "--version"], capture_output=True, text=True, timeout=10, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    match = re.search(r"(\d+)\.(\d+)(?:\.(\d+))?", result.stdout)
    return tuple(int(part) for part in match.groups(default="0")) if match else None


def font_installed(family: str) -> bool | None:
    if not shutil.which("fc-list"):
        return None
    try:
        result = subprocess.run(["fc-list", ":", "family"], capture_output=True, text=True, timeout=10, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    wanted = family.casefold()
    return any(wanted == name.strip().casefold() for line in result.stdout.splitlines() for name in line.split(","))


def doctor() -> dict:
    """Report what this machine needs for the theme, separating blockers from nice-to-haves."""
    checks = []

    def check(name: str, ok: bool | None, required: bool, detail: str) -> None:
        checks.append({"name": name, "ok": ok, "required": required, "detail": detail})

    version = plasma_version()
    check(
        "KDE Plasma 6.3 or newer",
        None if version is None else version >= (6, 3),
        True,
        "plasmashell was not found" if version is None else "found " + ".".join(str(part) for part in version),
    )
    for tool in ("plasma-apply-lookandfeel", "plasma-apply-colorscheme", "plasma-apply-desktoptheme", "kwriteconfig6"):
        check(tool, bool(shutil.which(tool)), True, "applies the theme")
    check("kreadconfig6", bool(shutil.which("kreadconfig6")), False, "lets uninstall hand settings back to Breeze")
    font = font_installed("JetBrains Mono")
    check("JetBrains Mono font", font, False,
          "the theme's typeface; without it the widgets use your fixed-width font and apps fall back to the default")
    check("Qt shader compiler (qsb)", find_qsb() is not None, False, "only for 'sync'; prebuilt shaders are used otherwise")
    check("Pillow", importlib.util.find_spec("PIL") is not None, False, "only for 'sync'; redraws the Global Theme preview")
    blocked = [item["name"] for item in checks if item["required"] and item["ok"] is not True]
    return {"ok": not blocked, "ready": not blocked, "blocked_by": blocked, "checks": checks,
            "kde_session": "kde" in os.environ.get("XDG_CURRENT_DESKTOP", "").lower()}


def status_theme(data_home: Path) -> dict:
    checks = {
        "look_and_feel": (data_home / "plasma/look-and-feel" / LOOK_AND_FEEL_ID / "metadata.json").is_file(),
        "desktop_theme": (data_home / "plasma/desktoptheme" / THEME_ID / "metadata.json").is_file(),
        "color_scheme_dark": (data_home / "color-schemes/TonantzintlaDark.colors").is_file(),
        "color_scheme_light": (data_home / "color-schemes/TonantzintlaLight.colors").is_file(),
        "window_decoration": all((data_home / "aurorae/themes" / name / "metadata.json").is_file() for name in AURORAE_THEMES),
        "wallpaper": (data_home / "wallpapers" / WALLPAPER_NAME / "metadata.json").is_file(),
        "plasmoids": all((data_home / "plasma/plasmoids" / pid / "metadata.json").is_file() for pid in PLASMOID_IDS),
    }
    return {
        "ok": True,
        "installed": all(checks.values()),
        "components": checks,
        "kde_session": "kde" in os.environ.get("XDG_CURRENT_DESKTOP", "").lower(),
        "layout_backups": [entry.name for entry in list_layout_backups()],
        "tools": {
            name: bool(shutil.which(name))
            for name in ("plasma-apply-lookandfeel", "plasma-apply-desktoptheme", "plasma-apply-colorscheme", "plasma-apply-wallpaperimage", "kpackagetool6")
        },
    }


def apply_theme(data_home: Path, *, mode: str = "dark", reset_layout: bool = True) -> dict:
    if not status_theme(data_home)["installed"]:
        install_theme(data_home, sync_palette=False)
    applied = []
    errors = []

    # Clear cached SVG kcache & plasmoid QML cache so updated Plasma Style frames and Plasmoid QML paint immediately.
    for stale in xdg_cache_home().glob(f"plasma_theme_{THEME_ID}*.kcache"):
        try:
            stale.unlink()
        except OSError:
            pass
    qml_cache = xdg_cache_home() / "plasmashell/qmlcache"
    if qml_cache.is_dir() and not qml_cache.is_symlink():
        shutil.rmtree(qml_cache, ignore_errors=True)

    layout_backup = None
    if shutil.which("plasma-apply-lookandfeel"):
        cmd = ["plasma-apply-lookandfeel", "--apply", LOOK_AND_FEEL_ID]
        if reset_layout:
            # --resetLayout replaces every panel the user has. Keep a copy they can return to.
            layout_backup = backup_layout(xdg_config_home())
            cmd.append("--resetLayout")
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=25, check=False)
        if res.returncode == 0:
            applied.append("look-and-feel (with layout)" if reset_layout else "look-and-feel")
        else:
            errors.append(res.stderr.strip() or res.stdout.strip() or "plasma-apply-lookandfeel failed")

    # Explicitly force Plasma 6.8 to reload the SVG desktoptheme and Aurorae decoration.
    if shutil.which("plasma-apply-desktoptheme"):
        subprocess.run(["plasma-apply-desktoptheme", "breeze-dark"], capture_output=True, text=True, timeout=15, check=False)
        res = subprocess.run(["plasma-apply-desktoptheme", THEME_ID], capture_output=True, text=True, timeout=15, check=False)
        if res.returncode == 0:
            applied.append(f"desktoptheme:{THEME_ID}")
        else:
            errors.append(res.stderr.strip() or "plasma-apply-desktoptheme failed")
    if shutil.which("kwriteconfig6"):
        subprocess.run(["kwriteconfig6", "--file", "plasmarc", "--group", "Theme", "--key", "name", THEME_ID],
                       capture_output=True, timeout=10, check=False)
        subprocess.run(["kwriteconfig6", "--file", "kwinrc", "--group", "org.kde.kdecoration2", "--key", "library", "org.kde.kwin.aurorae"],
                       capture_output=True, timeout=10, check=False)
        aurorae = AURORAE_LIGHT_NAME if mode == "light" else AURORAE_NAME
        _write_setting("kwinrc", "org.kde.kdecoration2", "theme", f"__aurorae__svg__{aurorae}")
        _write_setting("kwinrc", "org.kde.kdecoration2", "BorderSize", "Tiny")
        _write_setting("kwinrc", "org.kde.kdecoration2", "BorderSizeAuto", "false", kind="bool")
        applied.append(f"window-decoration:{aurorae}")
    if shutil.which("kbuildsycoca6"):
        subprocess.run(["kbuildsycoca6"], capture_output=True, timeout=15, check=False)

    scheme = "TonantzintlaLight" if mode == "light" else "TonantzintlaDark"
    if shutil.which("plasma-apply-colorscheme"):
        res = subprocess.run(["plasma-apply-colorscheme", scheme], capture_output=True, text=True, timeout=15, check=False)
        if res.returncode == 0:
            applied.append(f"colorscheme:{scheme}")
        else:
            errors.append(res.stderr.strip() or "plasma-apply-colorscheme failed")

    wp_image = data_home / "wallpapers" / WALLPAPER_NAME / "contents/images/3840x2160.png"
    if wp_image.is_file() and shutil.which("plasma-apply-wallpaperimage"):
        res = subprocess.run(["plasma-apply-wallpaperimage", str(wp_image)], capture_output=True, text=True, timeout=15, check=False)
        if res.returncode == 0:
            applied.append(f"wallpaper:{WALLPAPER_NAME}")
        else:
            errors.append(res.stderr.strip() or "plasma-apply-wallpaperimage failed")

    if shutil.which("qdbus6"):
        subprocess.run(["qdbus6", "org.kde.KWin", "/KWin", "reconfigure"], capture_output=True, timeout=10, check=False)

    # Reload plasmashell cleanly when running under systemd user session so updated Plasmoid QML takes effect immediately.
    if shutil.which("systemctl"):
        active = subprocess.run(
            ["systemctl", "--user", "is-active", "plasma-plasmashell.service"],
            capture_output=True, text=True, timeout=5, check=False,
        )
        if active.returncode == 0 and active.stdout.strip() == "active":
            res = subprocess.run(
                ["systemctl", "--user", "restart", "plasma-plasmashell.service"],
                capture_output=True, text=True, timeout=20, check=False,
            )
            if res.returncode == 0:
                applied.append("plasmashell:reloaded")

    if not applied and not errors:
        errors.append("KDE Plasma apply tools (plasma-apply-*) were not found on PATH.")
    payload = {"ok": bool(applied) and not errors, "applied": applied, "errors": errors}
    if layout_backup is not None:
        payload["layout_backup"] = str(layout_backup)
        payload["note"] = "Your previous panels were saved. 'restore-layout' brings them back."
    return payload


def validate_tree(root: Path) -> dict:
    missing = []
    required = [
        "color-schemes/TonantzintlaDark.colors",
        "color-schemes/TonantzintlaLight.colors",
        "icons/hicolor/scalable/apps/tonantzintla-mark.svg",
        f"desktoptheme/{THEME_ID}/metadata.json",
        f"desktoptheme/{THEME_ID}/colors",
        f"desktoptheme/{THEME_ID}/plasmarc",
        f"desktoptheme/{THEME_ID}/widgets/panel-background.svgz",
        f"desktoptheme/{THEME_ID}/dialogs/background.svgz",
        f"desktoptheme/{THEME_ID}/widgets/tooltip.svgz",
        f"desktoptheme/{THEME_ID}/widgets/tasks.svgz",
        f"desktoptheme/{THEME_ID}/widgets/clock.svgz",
        *[f"aurorae/themes/{name}/{leaf}" for name in AURORAE_THEMES
          for leaf in ("metadata.json", f"{name}rc", "decoration.svg", "close.svg")],
        f"wallpapers/{WALLPAPER_NAME}/metadata.json",
        f"look-and-feel/{LOOK_AND_FEEL_ID}/metadata.json",
        f"look-and-feel/{LOOK_AND_FEEL_ID}/contents/defaults",
        f"look-and-feel/{LOOK_AND_FEEL_ID}/contents/layouts/org.kde.plasma.desktop-layout.js",
        f"look-and-feel/{LOOK_AND_FEEL_ID}/contents/splash/Splash.qml",
        *[f"plasmoids/{pid}/metadata.json" for pid in PLASMOID_IDS],
        *[f"plasmoids/{pid}/contents/ui/main.qml" for pid in PLASMOID_IDS],
        *PLASMA_SHADERS.keys(),
    ]
    for rel in required:
        if not (root / rel).is_file():
            missing.append(rel)

    json_errors = []
    for meta in root.rglob("metadata.json"):
        try:
            parsed = json.loads(meta.read_text(encoding="utf-8"))
            if not isinstance(parsed, dict) or "KPlugin" not in parsed:
                json_errors.append(f"{meta}: missing KPlugin")
        except (OSError, ValueError) as error:
            json_errors.append(f"{meta}: {error}")

    return {"ok": not missing and not json_errors, "missing": missing, "json_errors": json_errors}


def render_human(action: str, payload: dict) -> str:
    """Plain-language summary of a result for people; --json stays the stable machine format."""
    lines: list[str] = []
    if payload.get("error"):
        lines.append(f"Error: {payload['error']}")
        if payload.get("hint"):
            lines.append(payload["hint"])
        return "\n".join(lines)
    if action == "doctor":
        for item in payload["checks"]:
            if item["ok"] is True:
                state = "ok"
            elif item["required"]:
                state = "missing"
            else:
                state = "optional"
            suffix = "" if item["ok"] is True else f" ({item['detail']})"
            lines.append(f"  [{state:^8}] {item['name']}{suffix}")
        lines.append("Ready to install." if payload["ready"] else "Not ready: " + ", ".join(payload["blocked_by"]) + ".")
        if payload["ready"] and not payload["kde_session"]:
            lines.append("This is not a Plasma session, so 'apply' will only take effect once you log into one.")
    elif action == "status":
        lines.append("Installed." if payload["installed"] else "Not fully installed.")
        for name, present in payload["components"].items():
            lines.append(f"  [{'ok' if present else 'missing':^8}] {name.replace('_', ' ')}")
        if payload["layout_backups"]:
            lines.append(f"Saved panel layouts: {len(payload['layout_backups'])} (newest {payload['layout_backups'][-1]}).")
    elif action in ("install", "sync"):
        lines.append(f"Installed into {payload['installed_to']}." + (" Colors follow your Tonantzintla palette." if payload["synced_palette"] else ""))
    elif action == "apply":
        if payload["applied"]:
            lines.append("Applied: " + ", ".join(payload["applied"]) + ".")
        lines.extend(f"Failed: {error}" for error in payload["errors"])
    elif action == "uninstall":
        lines.append(f"Removed {len(payload['removed'])} installed item(s)." if payload["removed"] else "Nothing was installed.")
        if payload["released_settings"]:
            lines.append("Handed back to Breeze: " + ", ".join(payload["released_settings"]) + ".")
    elif action == "restore-layout":
        lines.append(f"Restored {', '.join(payload['restored'])} from {payload['from']}.")
    else:
        return json.dumps(payload, indent=2)
    if payload.get("note"):
        lines.append(payload["note"])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=(
        "build", "install", "sync", "apply", "uninstall", "status", "validate", "restore-layout", "doctor",
    ))
    parser.add_argument("--data-home", type=Path, default=xdg_data_home())
    parser.add_argument("--output", type=Path, default=PLASMA_SRC)
    parser.add_argument("--mode", choices=("dark", "light"), default="dark")
    parser.add_argument("--layout", action="store_true", help="Apply Tonantzintla's top bar + floating dock layout (default)")
    parser.add_argument("--keep-layout", action="store_true", help="Keep your existing Plasma panel layout when applying")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--human", action="store_true", help="Print a short plain-language summary instead of JSON")
    args = parser.parse_args()

    try:
        if args.action == "build":
            build_tree(args.output)
            payload = {"ok": True, "built": str(args.output)}
        elif args.action == "install":
            payload = install_theme(args.data_home, sync_palette=False)
        elif args.action == "sync":
            payload = install_theme(args.data_home, sync_palette=True)
        elif args.action == "apply":
            payload = apply_theme(args.data_home, mode=args.mode, reset_layout=not args.keep_layout)
        elif args.action == "uninstall":
            payload = uninstall_theme(args.data_home)
        elif args.action == "status":
            payload = status_theme(args.data_home)
        elif args.action == "restore-layout":
            payload = restore_layout(xdg_config_home())
        elif args.action == "doctor":
            payload = doctor()
        else:
            payload = validate_tree(args.output)
    except Exception as error:
        payload = {"ok": False, "error": str(error)}

    rendered = render_human(args.action, payload) if args.human and not args.json else json.dumps(payload, indent=2)
    print(rendered, file=sys.stdout if args.json or payload.get("ok") else sys.stderr)
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
