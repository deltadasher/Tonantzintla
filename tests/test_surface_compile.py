"""Compile real widget components without constructing any desktop services."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class SurfaceCompileTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
    def test_widgets_compile_in_quickshell(self):
        project = Path(__file__).resolve().parents[1]
        qml = project / "src/quickshell"
        sources = sorted((qml / "modules/ephemeris/widgets").glob("**/*Widget.qml"))
        sources += [qml / "modules/aperture/ApertureContents.qml",
                    qml / "modules/ephemeris/SettingsPane.qml",
                    qml / "modules/ephemeris/CursorSettings.qml",
                    qml / "modules/ephemeris/TonantzintlaMorphBackdrop.qml",
                    qml / "modules/ephemeris/LiveBarPreview.qml"]
        with tempfile.TemporaryDirectory(prefix="tonantzintla-compile-") as directory:
            env = dict(os.environ, XDG_RUNTIME_DIR=directory,
                       QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       TONANTZINTLA_TEST_SOURCES=json.dumps([str(path) for path in sources]))
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run([shutil.which("qs"), "-p", str(project / "tests/qml/compile-surfaces.qml"),
                                     "--no-color"], env=env, capture_output=True, text=True, timeout=30)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertNotIn("SURFACE FAIL", output)
        self.assertIn("SURFACE COMPILE COMPLETE 0 failures", output)
