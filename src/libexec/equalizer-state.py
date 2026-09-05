#!/usr/bin/env python3
"""Manage Tonantzintla's EasyEffects equalizer and live output pitch."""

from __future__ import annotations

import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys


PRESETS: dict[str, list[int]] = {
    "Neutral": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    "Gravity": [6, 5, 3, 1, 0, -1, -1, 0, 1, 1],
    "Air": [-2, -2, -1, 0, 1, 2, 3, 4, 5, 5],
    "Dialogue": [-4, -3, -1, 2, 4, 5, 3, 1, -1, -2],
    "Pulse": [3, 2, 0, -1, 0, 2, 3, 2, 1, 0],
    "Impact": [4, 3, 2, 0, -1, 0, 2, 3, 4, 3],
    "Lounge": [2, 2, 1, 0, 1, 1, 2, 2, 1, 1],
    "Orchestra": [-1, 0, 1, 2, 2, 1, 1, 2, 3, 2],
}
CONTROL_FREQUENCIES = [31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
EASY_EFFECTS_FREQUENCIES = [
    32, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630,
    800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000,
    10000, 12500, 16000, 20000, 22000, 24000, 24000,
]
PRESET_NAME = "tonantzintla-live-eq"


def config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))


def state_path() -> Path:
    return config_home() / "tonantzintla" / "equalizer.json"


def default_state() -> dict[str, object]:
    return {
        "preset": "Neutral",
        "bands": list(PRESETS["Neutral"]),
        "pitch_enabled": False,
        "pitch_semitones": 0.0,
        "pitch_cents": 0.0,
        "pitch_mix": 100,
        "available": bool(shutil.which("easyeffects")),
    }


def read_state() -> dict[str, object]:
    try:
        data = json.loads(state_path().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, TypeError):
        data = default_state()
    bands = data.get("bands", PRESETS["Neutral"])
    if not isinstance(bands, list) or len(bands) != 10:
        bands = PRESETS["Neutral"]
    data["bands"] = [max(-12, min(12, int(float(value)))) for value in bands]
    saved_preset = str(data.get("preset", "Custom"))
    data["preset"] = saved_preset if saved_preset in PRESETS else "Custom"
    data["pitch_enabled"] = bool(data.get("pitch_enabled", False))
    data["pitch_semitones"] = max(-12.0, min(12.0, float(data.get("pitch_semitones", 0))))
    data["pitch_cents"] = max(-100.0, min(100.0, float(data.get("pitch_cents", 0))))
    data["pitch_mix"] = max(0, min(100, int(float(data.get("pitch_mix", 100)))))
    data["available"] = bool(shutil.which("easyeffects"))
    return data


def write_state(data: dict[str, object]) -> None:
    path = state_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")


def interpolated_gain(frequency: float, bands: list[int]) -> float:
    """Interpolate control points on a logarithmic frequency axis."""
    if frequency <= CONTROL_FREQUENCIES[0]:
        return float(bands[0])
    if frequency >= CONTROL_FREQUENCIES[-1]:
        return float(bands[-1])
    target = math.log2(frequency)
    for index in range(1, len(CONTROL_FREQUENCIES)):
        upper = CONTROL_FREQUENCIES[index]
        if frequency > upper:
            continue
        lower = CONTROL_FREQUENCIES[index - 1]
        span = math.log2(upper) - math.log2(lower)
        blend = (target - math.log2(lower)) / span
        return round(float(bands[index - 1]) * (1 - blend) + float(bands[index]) * blend, 2)
    return float(bands[-1])


def mix_gain(amount: float) -> float:
    """Convert a zero-to-one mix amount to a bounded constant-power dB gain."""
    if amount <= 0:
        return -100.0
    return round(max(-100.0, 20.0 * math.log10(math.sqrt(amount))), 2)


def easy_effects_preset(data: dict[str, object]) -> dict[str, object]:
    bands = data["bands"]
    nodes: dict[str, object] = {}
    for index, frequency in enumerate(EASY_EFFECTS_FREQUENCIES):
        gain = interpolated_gain(frequency, bands)
        nodes[f"band{index}"] = {
            "frequency": frequency,
            "gain": gain,
            "mode": "Bell",
            "mute": False,
            "q": 1.0,
            "solo": False,
            "width": 1.0,
            "slope": "x1",
        }
    equalizer = {
        "bypass": False,
        "input-gain": 0.0,
        "output-gain": 0.0,
        "left": nodes,
        "right": nodes,
        "mode": "IIR",
        "num-bands": 32,
        "split-channels": False,
    }
    mix = float(data["pitch_mix"]) / 100.0
    pitch = {
        "bypass": not bool(data["pitch_enabled"]),
        "input-gain": 0.0,
        "output-gain": 0.0,
        "dry": mix_gain(1.0 - mix),
        "wet": mix_gain(mix),
        "quick-seek": False,
        "anti-alias": True,
        "sequence-length": 40,
        "seek-window": 15,
        "overlap-length": 8,
        "tempo-difference": 0.0,
        "rate-difference": 0.0,
        "octaves": 0.0,
        "semitones": float(data["pitch_semitones"]),
        "cents": float(data["pitch_cents"]),
    }
    order = ["pitch#0", "equalizer#0"] if data["pitch_enabled"] else ["equalizer#0"]
    return {
        "output": {
            "blocklist": [],
            "plugins_order": order,
            "pitch#0": pitch,
            "equalizer#0": equalizer,
        }
    }


def apply(data: dict[str, object]) -> None:
    if not shutil.which("easyeffects"):
        return
    preset_dir = config_home() / "easyeffects" / "output"
    preset_dir.mkdir(parents=True, exist_ok=True)
    preset_file = preset_dir / f"{PRESET_NAME}.json"
    preset_file.write_text(json.dumps(easy_effects_preset(data), indent=2), encoding="utf-8")
    try:
        subprocess.Popen(
            ["easyeffects", "-l", PRESET_NAME],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        pass


def main() -> None:
    command = sys.argv[1] if len(sys.argv) > 1 else "get"
    data = read_state()
    if command == "recover":
        if shutil.which("easyeffects"):
            subprocess.run(["easyeffects", "--quit"], check=True, timeout=5,
                           stdout=subprocess.DEVNULL)
        data["pitch_enabled"] = False
        write_state(data)
    elif command == "preset" and len(sys.argv) > 2:
        name = sys.argv[2]
        if name in PRESETS:
            data["preset"] = name
            data["bands"] = PRESETS[name]
            write_state(data)
            apply(data)
    elif command == "band" and len(sys.argv) > 3:
        index = max(0, min(9, int(sys.argv[2])))
        data["bands"][index] = max(-12, min(12, int(float(sys.argv[3]))))
        data["preset"] = "Custom"
        write_state(data)
        apply(data)
    elif command == "pitch" and len(sys.argv) > 3:
        data["pitch_semitones"] = max(-12.0, min(12.0, float(sys.argv[2])))
        data["pitch_cents"] = max(-100.0, min(100.0, float(sys.argv[3])))
        data["pitch_enabled"] = True
        write_state(data)
        apply(data)
    elif command == "pitch-enable" and len(sys.argv) > 2:
        data["pitch_enabled"] = sys.argv[2].lower() in {"1", "true", "on", "yes"}
        write_state(data)
        apply(data)
    elif command == "pitch-mix" and len(sys.argv) > 2:
        data["pitch_mix"] = max(0, min(100, int(float(sys.argv[2]))))
        write_state(data)
        apply(data)
    elif command == "pitch-reset":
        data["pitch_enabled"] = False
        data["pitch_semitones"] = 0.0
        data["pitch_cents"] = 0.0
        data["pitch_mix"] = 100
        write_state(data)
        apply(data)
    print(json.dumps(data, separators=(",", ":")))


if __name__ == "__main__":
    main()
