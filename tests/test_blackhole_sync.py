"""Unit tests for bin/blackhole sync sequencing and preset contracts."""
import json
import os
from pathlib import Path
import stat
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

    def test_sync_sequencing_with_test_doubles(self):
        """Verify pull failure halts, installer failure stops restart, and success restarts."""
        with tempfile.TemporaryDirectory(prefix="tonantzintla-sync-test-") as temp_dir:
            temp_path = Path(temp_dir)
            bin_dir = temp_path / "bin"
            bin_dir.mkdir()

            log_file = temp_path / "calls.log"

            fake_git = bin_dir / "git"
            fake_git.write_text(f"""#!/bin/sh
echo "git $@" >> "{log_file}"
if [ "$FAIL_GIT" = "1" ]; then
    echo "Simulated git pull error" >&2
    exit 1
fi
exit 0
""")
            fake_git.chmod(fake_git.stat().st_mode | stat.S_IXUSR)

            fake_project = temp_path / "repo"
            fake_project.mkdir()
            (fake_project / ".git").mkdir()
            (fake_project / "bin").mkdir()

            fake_blackhole = fake_project / "bin/blackhole"
            fake_blackhole.write_text(self.blackhole_bin.read_text())
            fake_blackhole.chmod(fake_blackhole.stat().st_mode | stat.S_IXUSR)

            fake_installer = fake_project / "bin/tonantzintla-installer"
            fake_installer.write_text(f"""#!/bin/sh
echo "installer $@" >> "{log_file}"
if [ "$FAIL_INSTALL" = "1" ]; then
    echo "Simulated install error" >&2
    exit 1
fi
exit 0
""")
            fake_installer.chmod(fake_installer.stat().st_mode | stat.S_IXUSR)

            # Test 1: Git pull failure must halt sync immediately
            log_file.unlink(missing_ok=True)
            env = dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}", FAIL_GIT="1", FAIL_INSTALL="0")
            result = subprocess.run(
                [str(fake_blackhole), "sync"],
                env=env,
                capture_output=True,
                text=True
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("git pull failed. Sync halted", result.stderr)
            logs = log_file.read_text() if log_file.exists() else ""
            self.assertIn("git -C", logs)
            self.assertNotIn("installer", logs)

            # Test 2: Installer failure must halt before restart
            log_file.unlink(missing_ok=True)
            env = dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}", FAIL_GIT="0", FAIL_INSTALL="1")
            result = subprocess.run(
                [str(fake_blackhole), "sync"],
                env=env,
                capture_output=True,
                text=True
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("Runtime installation failed. Desktop restart skipped", result.stderr)
            logs = log_file.read_text() if log_file.exists() else ""
            self.assertIn("git -C", logs)
            self.assertIn("installer", logs)

            # Test 3: Success must call installer and then restart
            log_file.unlink(missing_ok=True)
            env = dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}", FAIL_GIT="0", FAIL_INSTALL="0")
            result = subprocess.run(
                [str(fake_blackhole), "sync"],
                env=env,
                capture_output=True,
                text=True
            )
            logs = log_file.read_text() if log_file.exists() else ""
            self.assertIn("git -C", logs)
            self.assertIn("installer", logs)
            self.assertIn("✦ Syncing Tonantzintla observatory...", result.stdout)
            self.assertIn("Restarting running desktop instance", result.stdout)


if __name__ == "__main__":
    unittest.main()
