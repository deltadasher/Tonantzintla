import os, shutil, subprocess, tempfile, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class UiRegressions(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_empty_tray_optical_outline_and_hovered_orbit(self):
        with tempfile.TemporaryDirectory(prefix='ui-regressions-') as directory:
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory,
                       XDG_CACHE_HOME=directory, XDG_STATE_HOME=directory,
                       XDG_RUNTIME_DIR=directory, QT_QPA_PLATFORM='offscreen',
                       QT_QUICK_BACKEND='software', DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
            for key in ('WAYLAND_DISPLAY', 'NIRI_SOCKET', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key, None)
            with tempfile.NamedTemporaryFile('w', suffix='.qml', dir=ROOT/'src/quickshell') as harness:
                harness.write((ROOT/'tests/ui-regressions.qml').read_text()); harness.flush()
                result = subprocess.run(['qs', '-p', harness.name, '--no-color'], env=env,
                                        capture_output=True, text=True, timeout=12)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('UI REGRESSIONS COMPLETE 0', output)
            for error in ('ReferenceError', 'TypeError', 'Unable to assign', 'Failed to load configuration'):
                self.assertNotIn(error, output)
