"""Native input, reduced-motion and idle lifetime for the audio fill response."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AudioLiquidTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_native_adjustment_settles_and_preserves_quiet_states(self):
        source = (ROOT / 'tests/instruments/audio-liquid.qml').read_text().replace(
            '../../src/quickshell/', '').replace('"../../src/quickshell"', '"."')
        with tempfile.TemporaryDirectory(prefix='audio-liquid-') as directory:
            folder = Path(directory)
            (folder / 'tonantzintla').mkdir()
            (folder / 'tonantzintla/settings.json').write_text(json.dumps({
                'motion': True, 'adaptivePalette': False, 'clipboardPaused': True}))
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory,
                       XDG_CACHE_HOME=directory, XDG_STATE_HOME=directory,
                       XDG_DATA_HOME=directory, XDG_RUNTIME_DIR=directory,
                       QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',
                       DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent',
                       AUDIO_LIQUID_OUTPUT=directory)
            for key in ('WAYLAND_DISPLAY', 'NIRI_SOCKET', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key, None)
            with tempfile.NamedTemporaryFile(mode='w', prefix='test-audio-liquid-',
                                             suffix='.qml', dir=ROOT / 'src/quickshell') as harness:
                harness.write(source); harness.flush()
                try:
                    result = subprocess.run(['qs', '-p', harness.name, '--no-color'],
                                            env=env, capture_output=True, text=True, timeout=15)
                except subprocess.TimeoutExpired as error:
                    self.fail(str(error) + '\n' + str(error.stdout) + '\n' + str(error.stderr))
            output = result.stdout + result.stderr
            if os.environ.get('AUDIO_LIQUID_CAPTURE'):
                destination = Path(os.environ['AUDIO_LIQUID_CAPTURE'])
                destination.mkdir(parents=True, exist_ok=True)
                for image in folder.glob('*.png'):
                    shutil.copyfile(image, destination / image.name)
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('AUDIO LIQUID COMPLETE 0 failures', output)
            for bad in ('ReferenceError', 'TypeError', 'Binding loop', 'Unable to assign', 'Failed to load configuration'):
                self.assertNotIn(bad, output)
            for name in ('rest', 'adjusting', 'settled'):
                self.assertGreater((folder / (name + '.png')).stat().st_size, 2000)
