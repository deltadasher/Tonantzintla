import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class OsdSettingsTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_real_osd_preferences_and_expiry(self):
        repo = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory(prefix='osd-settings-') as directory:
            fixture = Path(directory) / 'test.qml'
            fixture.write_text((repo / 'tests/qml/osd-settings.qml').read_text().replace(
                '../../src/quickshell', (repo / 'src/quickshell').as_uri()))
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       XDG_RUNTIME_DIR=directory, XDG_CONFIG_HOME=directory, XDG_CACHE_HOME=directory)
            env.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run(['qs', '-p', str(fixture), '--no-color'], env=env,
                                    capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertNotIn('OSD_FAILED', output)
            self.assertNotIn('ReferenceError', output)
            self.assertIn('OSD_OK', output)
