"""Actual Umbra editor and private MPRIS fixture; no live bus or compositor."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class UmbraFontsNativeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("qs") and shutil.which("dbus-run-session"), "Quickshell/private D-Bus unavailable")
    def test_editor_icon_roles_keep_regular_weight_and_text_emphasis(self):
        if subprocess.run(["python3", "-c", "from gi.repository import Gio"], capture_output=True).returncode:
            self.skipTest("Python Gio unavailable")
        with tempfile.TemporaryDirectory(prefix="umbra-fonts-") as directory:
            folder = Path(directory)
            (folder / "tonantzintla").mkdir()
            (folder / "tonantzintla/settings.json").write_text(json.dumps({"motion": False, "adaptivePalette": False, "clipboardPaused": True, "umbraBackgroundMode": "solid", "umbraMotion": False, "umbraShowMedia": True}))
            screenshot = folder / "icons.png"
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory,
                       XDG_CACHE_HOME=directory, XDG_DATA_HOME=directory, XDG_STATE_HOME=directory,
                       XDG_RUNTIME_DIR=directory, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       DBUS_SYSTEM_BUS_ADDRESS="unix:path=/nonexistent", ICON_SCREENSHOT=str(screenshot),
                       MALLOC_CONF="narenas:2,dirty_decay_ms:0,muzzy_decay_ms:0,thp:never")
            for key in ("WAYLAND_DISPLAY", "NIRI_SOCKET", "SWAYSOCK", "HYPRLAND_INSTANCE_SIGNATURE", "DBUS_SESSION_BUS_ADDRESS"):
                env.pop(key, None)
            # The private bus and both children terminate with this isolated run.
            child = folder / "child.py"
            child.write_text('''import os,subprocess,time,json
from pathlib import Path
fixture=subprocess.Popen(['python3',os.environ['ICON_MEDIA_FIXTURE']])
try:
    time.sleep(.15)
    p=subprocess.Popen(['qs','-p',os.environ['ICON_QML'],'--no-color'])
    try:
        time.sleep(1.4)
        Path(os.environ['ICON_MAPS']).write_text(Path('/proc/'+str(p.pid)+'/smaps').read_text())
        p.wait(timeout=5)
    finally:
        if p.poll() is None: p.terminate(); p.wait(timeout=3)
finally:
    fixture.terminate();fixture.wait(timeout=3)
''')
            source = (ROOT / "tests/fonts/umbra.qml").read_text().replace("../../src/quickshell", ".")
            with tempfile.NamedTemporaryFile(mode="w", prefix="test-umbra-font-", suffix=".qml", dir=Path(os.environ.get("TONA_UMBRA_SOURCE_ROOT", str(ROOT / "src/quickshell")))) as harness:
                harness.write(source); harness.flush()
                env.update(ICON_QML=harness.name, ICON_MAPS=str(folder / "smaps"), ICON_MEDIA_FIXTURE=str(ROOT / "tests/fonts/media-fixture.py"))
                result = subprocess.run(["dbus-run-session", "--", "python3", str(child)], env=env, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            if result.returncode == 127 and "Failed to bind socket" in output and "Operation not permitted" in output:
                self.skipTest("Sandbox denies private test D-Bus socket; run this native fixture outside the sandbox")
            # Optional artifact destination is only for this isolated benchmark.
            artifacts = os.environ.get("TONA_UMBRA_FONT_ARTIFACTS")
            if artifacts:
                destination = Path(artifacts); destination.mkdir(parents=True, exist_ok=True)
                for name in ("smaps", "icons.png"):
                    if (folder / name).exists(): shutil.copyfile(folder / name, destination / name)
                (destination / "native.log").write_text(output)
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("UMBRA FONT COMPLETE 0 failures", output)
            self.assertGreater(screenshot.stat().st_size, 1000)
            mappings = (folder / "smaps").read_text()
            self.assertNotIn("IosevkaNerdFont-Bold.ttf", mappings)
            self.assertNotIn("IosevkaNerdFont-SemiBold.ttf", mappings)
            for error in ("TypeError", "ReferenceError", "Unable to assign", "Failed to load configuration"):
                self.assertNotIn(error, output)
