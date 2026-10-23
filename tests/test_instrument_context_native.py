import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class InstrumentContextTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_native_keys_consumers_persistence_and_small_viewport(self):
        source = (ROOT/'tests/instruments/context.qml').read_text().replace('../../src/quickshell/', '').replace('"../../src/quickshell"', '"."')
        with tempfile.TemporaryDirectory(prefix='instrument-context-') as directory:
            root = Path(directory)
            (root/'tonantzintla').mkdir()
            settings = root/'tonantzintla/settings.json'
            settings.write_text(json.dumps({'clipboardPaused': True, 'motion': False, 'weatherEnabled': False}))
            fake = root/'bin'; fake.mkdir()
            for binary in ('cliphist', 'wl-paste', 'wl-copy', 'niri'):
                script = fake/binary; script.write_text('#!/bin/sh\nexit 0\n'); script.chmod(0o755)
            screenshot = root/'context.png'
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory,
                       XDG_CACHE_HOME=directory, XDG_STATE_HOME=directory, XDG_RUNTIME_DIR=directory,
                       QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent', PATH=str(fake)+':'+os.environ['PATH'],
                       CONTEXT_SCREENSHOT=str(screenshot))
            for key in ('WAYLAND_DISPLAY', 'NIRI_SOCKET', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key, None)
            with tempfile.NamedTemporaryFile(mode='w', prefix='test-context-', suffix='.qml', dir=ROOT/'src/quickshell') as harness:
                harness.write(source); harness.flush()
                result = subprocess.run(['qs', '-p', harness.name, '--no-color'], env=env, capture_output=True, text=True, timeout=15)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('CONTEXT COMPLETE 0 failures', output)
            for bad in ('CONTEXT FAIL', 'ReferenceError', 'TypeError', 'Unable to assign', 'Failed to load configuration'):
                self.assertNotIn(bad, output)
            self.assertGreater(screenshot.stat().st_size, 3000)
            data = json.loads(settings.read_text())
            self.assertEqual(data['calendarDefaultMode'], 2)
            self.assertEqual(data['resonanceVisualizer'], 'bars')
            self.assertEqual(data['wallpaperTransition'], 'swipe')
            self.assertEqual(data['moduleAppearance']['media'], 'classic')
            destination = os.environ.get('CONTEXT_CAPTURE')
            if destination:
                shutil.copyfile(screenshot, destination)

    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_context_placement_uses_margins_and_clamps_stale_bounds(self):
        source = (ROOT/'tests/instruments/placement.qml').read_text().replace('../../src/quickshell/', '').replace('"../../src/quickshell"', '"."')
        with tempfile.TemporaryDirectory(prefix='context-placement-') as directory:
            root = Path(directory)
            (root/'tonantzintla').mkdir()
            (root/'tonantzintla/settings.json').write_text(json.dumps({'adaptivePalette': False, 'motion': False, 'clipboardPaused': True}))
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory, XDG_CACHE_HOME=directory,
                       XDG_STATE_HOME=directory, XDG_RUNTIME_DIR=directory, QT_QPA_PLATFORM='offscreen',
                       QT_QUICK_BACKEND='software', DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
            for key in ('WAYLAND_DISPLAY', 'NIRI_SOCKET', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key, None)
            with tempfile.NamedTemporaryFile(mode='w', prefix='test-context-placement-', suffix='.qml', dir=ROOT/'src/quickshell') as harness:
                harness.write(source); harness.flush()
                result = subprocess.run(['qs', '-p', harness.name, '--no-color'], env=env, capture_output=True, text=True, timeout=15)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('PLACEMENT COMPLETE 0 failures', output)
            for bad in ('PLACEMENT FAIL', 'ReferenceError', 'TypeError', 'Binding loop', 'Unable to assign', 'Failed to load configuration'):
                self.assertNotIn(bad, output)
