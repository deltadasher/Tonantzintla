import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class ControlLayoutTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_long_text_fits_narrow_controls(self):
        repo = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory(prefix='control-layout-') as directory:
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       XDG_RUNTIME_DIR=directory, XDG_CONFIG_HOME=directory, XDG_CACHE_HOME=directory,
                       CONTROL_SOURCES=json.dumps([(repo / 'src/quickshell/components' / name).as_uri()
                           for name in ('SettingChoice.qml', 'SettingToggle.qml', 'SettingTextField.qml')]))
            env.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run(['qs', '-p', str(repo / 'tests/qml/control-layout.qml'), '--no-color'],
                                    env=env, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertNotIn('CONTROL_FAILED', output)
            self.assertNotIn('Binding loop', output)
            self.assertIn('CONTROL_LAYOUT_OK', output)

    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_optical_controls_render_with_software_fallback(self):
        repo = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory(prefix='control-render-') as directory:
            capture = Path(directory) / 'controls.png'
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       XDG_RUNTIME_DIR=directory, XDG_CONFIG_HOME=directory,
                       XDG_CACHE_HOME=directory, CONTROL_CAPTURE=str(capture))
            env.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run(['qs', '-p', str(repo / 'src/quickshell/preview-controls.qml'), '--no-color'],
                                    env=env, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('CONTROL_CAPTURE_OK', output)
            self.assertNotIn('Binding loop', output)
            self.assertNotIn('ReferenceError', output)
            self.assertNotIn('TypeError', output)
            self.assertGreater(capture.stat().st_size, 1000)
