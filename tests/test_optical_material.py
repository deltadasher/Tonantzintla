"""Native lifecycle and mapping checks; GPU captures are a separate host check."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[1]

class OpticalMaterialTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_oriented_wallpaper_mapping_through_rotated_ancestor(self):
        self.run_fixture("optical-affine.qml")

    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_native_provider_lifecycle_and_mapping(self):
        self.run_fixture("optics.qml")

    @unittest.skipUnless(shutil.which("qs"), "Quickshell unavailable")
    def test_native_interaction_lens_and_toggle(self):
        self.run_fixture("optical-interactions.qml")

    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_dedicated_settings_page_lazy_route_and_scope_consumers(self):
        self.run_fixture("optics-settings-page.qml")

    def run_fixture(self, name):
        source = (ROOT/"tests/instruments"/name).read_text().replace('../../src/quickshell/', '').replace('"../../src/quickshell"', '"."')
        with tempfile.TemporaryDirectory(prefix='optics-native-') as directory:
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory, XDG_CACHE_HOME=directory,
                       XDG_STATE_HOME=directory, XDG_RUNTIME_DIR=directory, QT_QPA_PLATFORM='offscreen',
                       QT_QUICK_BACKEND='software', DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',
                       OPTICS_SCREENSHOT=directory+'/optics.png')
            for key in ('WAYLAND_DISPLAY', 'NIRI_SOCKET', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key, None)
            with tempfile.NamedTemporaryFile(mode='w', prefix='test-optics-', suffix='.qml', dir=ROOT/'src/quickshell') as harness:
                harness.write(source); harness.flush()
                result = subprocess.run(['qs', '-p', harness.name, '--no-color'], env=env, capture_output=True, text=True, timeout=12)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('OPTICS COMPLETE 0 failures', output)
            for bad in ('OPTICS FAIL', 'ReferenceError', 'TypeError', 'Binding loop', 'Unable to assign', 'Failed to load configuration'):
                self.assertNotIn(bad, output)
