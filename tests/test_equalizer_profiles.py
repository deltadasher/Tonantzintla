from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]


def load_equalizer():
    path = ROOT / "src" / "libexec" / "equalizer-state.py"
    spec = importlib.util.spec_from_file_location("tonantzintla_equalizer", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class EqualizerProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.equalizer = load_equalizer()

    def test_original_profile_set_has_ten_points_each(self) -> None:
        self.assertEqual(
            set(self.equalizer.PRESETS),
            {"Neutral", "Gravity", "Air", "Dialogue", "Pulse", "Impact", "Lounge", "Orchestra"},
        )
        for profile in self.equalizer.PRESETS.values():
            self.assertEqual(len(profile), 10)
            self.assertTrue(all(-12 <= value <= 12 for value in profile))

    def test_log_interpolation_reaches_control_points(self) -> None:
        profile = self.equalizer.PRESETS["Gravity"]
        for frequency, expected in zip(self.equalizer.CONTROL_FREQUENCIES, profile):
            self.assertEqual(
                self.equalizer.interpolated_gain(frequency, profile),
                float(expected),
            )

    def test_generated_easy_effects_graph_is_continuous(self) -> None:
        state = self.equalizer.default_state()
        state["bands"] = self.equalizer.PRESETS["Air"]
        graph = self.equalizer.easy_effects_preset(state)
        left = graph["output"]["equalizer#0"]["left"]
        self.assertEqual(len(left), 32)
        gains = [left[f"band{index}"]["gain"] for index in range(32)]
        self.assertGreater(gains[-1], gains[0])
        self.assertGreater(len({gain for gain in gains}), 10)

    def test_pitcher_precedes_equalizer_when_enabled(self) -> None:
        state = self.equalizer.default_state()
        state.update({
            "pitch_enabled": True,
            "pitch_semitones": 7,
            "pitch_cents": -18,
            "pitch_mix": 64,
        })
        output = self.equalizer.easy_effects_preset(state)["output"]
        self.assertEqual(output["plugins_order"], ["pitch#0", "equalizer#0"])
        self.assertEqual(output["pitch#0"]["semitones"], 7.0)
        self.assertEqual(output["pitch#0"]["cents"], -18.0)
        self.assertFalse(output["pitch#0"]["bypass"])
        self.assertGreater(output["pitch#0"]["wet"], output["pitch#0"]["dry"])

    def test_disabled_pitcher_leaves_the_output_graph_dry(self) -> None:
        state = self.equalizer.default_state()
        output = self.equalizer.easy_effects_preset(state)["output"]
        self.assertEqual(output["plugins_order"], ["equalizer#0"])
        self.assertTrue(output["pitch#0"]["bypass"])

    def test_pitcher_mix_uses_bounded_constant_power_gain(self) -> None:
        self.assertEqual(self.equalizer.mix_gain(0), -100.0)
        self.assertEqual(self.equalizer.mix_gain(1), 0.0)
        self.assertAlmostEqual(self.equalizer.mix_gain(0.5), -3.01, places=2)

    def test_apply_writes_and_loads_the_pitcher_output_preset(self) -> None:
        state = self.equalizer.default_state()
        state["pitch_enabled"] = True
        state["pitch_semitones"] = -5
        with tempfile.TemporaryDirectory() as directory:
            with (
                patch.object(self.equalizer, "config_home", return_value=Path(directory)),
                patch.object(self.equalizer.shutil, "which", return_value="/usr/bin/easyeffects"),
                patch.object(self.equalizer.subprocess, "Popen") as launch,
            ):
                self.equalizer.apply(state)
            preset = Path(directory) / "easyeffects" / "output" / "tonantzintla-live-eq.json"
            output = json.loads(preset.read_text())["output"]
            self.assertEqual(output["plugins_order"][0], "pitch#0")
            self.assertEqual(output["pitch#0"]["semitones"], -5.0)
            launch.assert_called_once()
            self.assertEqual(
                launch.call_args.args[0],
                ["easyeffects", "-l", "tonantzintla-live-eq"],
            )


if __name__ == "__main__":
    unittest.main()
