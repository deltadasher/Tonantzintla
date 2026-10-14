"""Tests for blackhole config get/set/preset and the help text."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class BlackholeCliTests(unittest.TestCase):
    def setUp(self):
        self.project_root = Path(__file__).resolve().parents[1]
        self.blackhole_bin = self.project_root / "bin/blackhole"

    def test_presets_contract_matches_expected_keys(self):
        with tempfile.TemporaryDirectory(prefix="tonantzintla-preset-") as temp_dir:
            temp_config = Path(temp_dir) / "settings.json"
            initial_data = {
                "unrelatedKey": "preserve_me",
                "customSetting": 12345
            }
            temp_config.write_text(json.dumps(initial_data), encoding="utf-8")

            env = dict(os.environ, TONANTZINTLA_SETTINGS=str(temp_config))

            expected_presets = {
                "serpantinum": {
                    "accentName": "violet",
                    "barPosition": "top",
                    "barMode": "capsules",
                    "barHeightProfile": "nominal",
                    "ephemerisStyle": "deck",
                    "motionSpeedProfile": "fluid",
                    "typographyProfile": "serpantinum",
                },
                "caelestia": {
                    "accentName": "cyan",
                    "barPosition": "left",
                    "barMode": "capsules",
                    "barHeightProfile": "compact",
                    "ephemerisStyle": "spotlight",
                    "motionSpeedProfile": "snappy",
                    "typographyProfile": "readable",
                },
                "solaris": {
                    "accentName": "amber",
                    "barPosition": "bottom",
                    "barMode": "docked",
                    "barHeightProfile": "nominal",
                    "ephemerisStyle": "spotlight",
                    "motionSpeedProfile": "fluid",
                    "clock12h": False,
                },
                "cyberpunk": {
                    "accentName": "rose",
                    "barPosition": "right",
                    "barMode": "capsules",
                    "barHeightProfile": "compact",
                    "ephemerisStyle": "spotlight",
                    "motionSpeedProfile": "instant",
                    "typographyProfile": "serpantinum",
                },
                "minimalist": {
                    "accentName": "silver",
                    "barPosition": "top",
                    "barMode": "floating",
                    "barHeightProfile": "compact",
                    "ephemerisStyle": "spotlight",
                    "motionSpeedProfile": "snappy",
                    "showTray": False,
                    "showDate": False,
                },
            }

            for name, expected in expected_presets.items():
                result = subprocess.run(
                    [str(self.blackhole_bin), "config", "preset", name],
                    env=env,
                    capture_output=True,
                    text=True,
                    check=True
                )
                self.assertIn(f"Wrote '{name}' desktop preset", result.stdout)

                data = json.loads(temp_config.read_text(encoding="utf-8"))
                self.assertEqual(data.get("unrelatedKey"), "preserve_me")
                self.assertEqual(data.get("customSetting"), 12345)
                for k, v in expected.items():
                    self.assertEqual(data.get(k), v, f"Mismatch for {k} in preset {name}")

    def test_invalid_preset_rejected(self):
        with tempfile.TemporaryDirectory(prefix="tonantzintla-preset-") as temp_dir:
            temp_config = Path(temp_dir) / "settings.json"
            env = dict(os.environ, TONANTZINTLA_SETTINGS=str(temp_config))
            result = subprocess.run(
                [str(self.blackhole_bin), "config", "preset", "nonexistent_preset"],
                env=env,
                capture_output=True,
                text=True
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Error: Unknown preset 'nonexistent_preset'", result.stderr)

    def test_bar_edit_help_and_dispatch(self):
        result = subprocess.run([str(self.blackhole_bin), "help"], capture_output=True, text=True, check=True)
        self.assertIn("bar-edit", result.stdout)
        self.assertIn("Bar Studio edit mode", result.stdout)


    def test_set_refuses_to_overwrite_unreadable_settings(self):
        with tempfile.TemporaryDirectory(prefix="tonantzintla-config-") as temp_dir:
            temp_config = Path(temp_dir) / "settings.json"
            temp_config.write_text('{"barMode": "dock', encoding="utf-8")
            env = dict(os.environ, TONANTZINTLA_SETTINGS=str(temp_config))
            for command in (["set", "barMode", "docked"], ["preset", "solaris"]):
                result = subprocess.run(
                    [str(self.blackhole_bin), "config", *command],
                    env=env,
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(result.returncode, 1)
                self.assertIn("Refusing to overwrite", result.stderr)
                self.assertEqual(temp_config.read_text(encoding="utf-8"), '{"barMode": "dock')

    def test_set_parses_integers_floats_and_booleans(self):
        with tempfile.TemporaryDirectory(prefix="tonantzintla-config-") as temp_dir:
            temp_config = Path(temp_dir) / "settings.json"
            env = dict(os.environ, TONANTZINTLA_SETTINGS=str(temp_config))
            for key, value in (("offset", "-5"), ("ratio", "0.5"), ("showTray", "false"), ("barMode", "docked")):
                subprocess.run(
                    [str(self.blackhole_bin), "config", "set", key, value],
                    env=env,
                    capture_output=True,
                    text=True,
                    check=True,
                )
            data = json.loads(temp_config.read_text(encoding="utf-8"))
            self.assertEqual(data, {"offset": -5, "ratio": 0.5, "showTray": False, "barMode": "docked"})
            self.assertIsInstance(data["offset"], int)


if __name__ == "__main__":
    unittest.main()
