"""Parallax symbols must not load heavy text-weight fallback font faces."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class WallpaperFontsNativeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("qs"), "Quickshell unavailable")
    def test_actual_parallax_symbols_avoid_bold_fallback_keep_text_emphasis(self):
        with tempfile.TemporaryDirectory(prefix="wallpaper-fonts-") as directory:
            folder = Path(directory)
            (folder / "tonantzintla").mkdir()
            empty = json.dumps({"start": [], "center": [], "end": []})
            (folder / "tonantzintla/settings.json").write_text(json.dumps({
                "motion": False, "adaptivePalette": False, "dockEnabled": False,
                "barLayoutHorizontal": empty, "barLayoutVertical": empty,
            }))
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory,
                       XDG_CACHE_HOME=directory, XDG_STATE_HOME=directory, XDG_DATA_HOME=directory,
                       XDG_RUNTIME_DIR=directory, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent", DBUS_SYSTEM_BUS_ADDRESS="unix:path=/nonexistent",
                       MALLOC_CONF="narenas:2,dirty_decay_ms:0,muzzy_decay_ms:0,thp:never")
            for key in ("WAYLAND_DISPLAY", "NIRI_SOCKET", "SWAYSOCK", "HYPRLAND_INSTANCE_SIGNATURE"):
                env.pop(key, None)
            source = (ROOT / "tests/fonts/wallpaper.qml").read_text().replace("../../src/quickshell", ".")
            with tempfile.NamedTemporaryFile(mode="w", prefix="test-wallpaper-font-", suffix=".qml", dir=ROOT / "src/quickshell") as harness:
                harness.write(source); harness.flush()
                process = subprocess.Popen(["qs", "-p", harness.name, "--no-color"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                try:
                    time.sleep(1.1)
                    mappings = Path(f"/proc/{process.pid}/smaps").read_text()
                    output, _ = process.communicate(timeout=5)
                finally:
                    if process.poll() is None:
                        process.terminate(); process.wait(timeout=3)
            artifacts = os.environ.get("TONA_WALL_FONT_ARTIFACTS")
            if artifacts:
                dest = Path(artifacts); dest.mkdir(parents=True, exist_ok=True)
                (dest / "smaps").write_text(mappings)
                (dest / "native.log").write_text(output)
            self.assertEqual(process.returncode, 0, output)
            self.assertIn("WALL FONT COMPLETE 0 failures", output)
            self.assertNotIn("IosevkaNerdFont-Bold.ttf", mappings)
            self.assertNotIn("IosevkaNerdFont-SemiBold.ttf", mappings)
            for error in ("TypeError", "ReferenceError", "Unable to assign", "Failed to load configuration"):
                self.assertNotIn(error, output)
