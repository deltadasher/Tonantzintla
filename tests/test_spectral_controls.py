import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class SpectralControlsTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_native_hex_validation_theme_reset_undo_and_persistence(self):
        source = (ROOT/'tests/instruments/spectral.qml').read_text().replace('../../src/quickshell/', '').replace('"../../src/quickshell"', '"."')
        with tempfile.TemporaryDirectory(prefix='spectral-native-') as directory:
            root = Path(directory)
            (root/'tonantzintla').mkdir()
            settings = root/'tonantzintla/settings.json'
            settings.write_text(json.dumps({'adaptivePalette': False, 'motion': False, 'clipboardPaused': True}))
            screenshot = root/'spectral.png'
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory, XDG_CACHE_HOME=directory,
                       XDG_STATE_HOME=directory, XDG_RUNTIME_DIR=directory, QT_QPA_PLATFORM='offscreen',
                       QT_QUICK_BACKEND='software', DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',
                       SPECTRAL_SCREENSHOT=str(screenshot))
            for key in ('WAYLAND_DISPLAY', 'NIRI_SOCKET', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key, None)
            with tempfile.NamedTemporaryFile(mode='w', prefix='test-spectral-', suffix='.qml', dir=ROOT/'src/quickshell') as harness:
                harness.write(source); harness.flush()
                result = subprocess.run(['qs', '-p', harness.name, '--no-color'], env=env, capture_output=True, text=True, timeout=15)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('SPECTRAL COMPLETE 0 failures', output)
            for bad in ('SPECTRAL FAIL', 'ReferenceError', 'TypeError', 'Binding loop', 'Unable to assign', 'Failed to load configuration'):
                self.assertNotIn(bad, output)
            self.assertGreater(screenshot.stat().st_size, 5000)
            data = json.loads(settings.read_text())
            self.assertEqual(data['spectralColors'], {'cyan': '#d4d8e8'})
            if os.environ.get('SPECTRAL_CAPTURE'):
                shutil.copyfile(screenshot, os.environ['SPECTRAL_CAPTURE'])
