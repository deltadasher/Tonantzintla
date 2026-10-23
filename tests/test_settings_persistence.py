import os
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class SettingsPersistenceTests(unittest.TestCase):
    def test_undo_survives_own_save_but_not_external_edits(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Path(temporary) / "settings-persistence.qml"
            fixture.write_text(
                (ROOT / "tests/qml/settings-persistence.qml").read_text()
                .replace("../../src/quickshell", (ROOT / "src/quickshell").as_uri())
            )
            settings = Path(temporary) / "config/tonantzintla/settings.json"
            settings.parent.mkdir(parents=True)
            settings.write_text(json.dumps({"constellationEnabled": True, "constellationState": {"instances": [{"kind": "clock"}]}}))
            env = dict(
                os.environ,
                QT_QPA_PLATFORM="offscreen",
                QT_QUICK_BACKEND="software",
                XDG_CONFIG_HOME=temporary + "/config",
                XDG_RUNTIME_DIR=temporary + "/runtime",
            )
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(
                ["qs", "-p", str(fixture), "--no-color"],
                env=env, capture_output=True, text=True, timeout=12,
            )
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn("SETTINGS CHECK COMPLETE 0", output)
        self.assertNotIn("CHECK FAIL", output)


if __name__ == "__main__":
    unittest.main()
