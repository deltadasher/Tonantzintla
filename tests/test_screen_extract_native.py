"""Native service + full CaptureWidget with real QR helper and isolated IO."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = '雪猫\nhttps://example.com/?a=1&b=2'


@unittest.skipUnless(all(shutil.which(tool) for tool in ('qs', 'qrencode', 'zbarimg')), 'Native QR tools unavailable')
class ScreenExtractNativeTests(unittest.TestCase):
    def scenario(self, missing=False, mode='normal'):
        with tempfile.TemporaryDirectory(prefix='screen-extract-native-') as directory:
            root = Path(directory)
            # shellDir remains a real shell root; runtime files stay in the sandbox.
            shell = root / 'quickshell'
            shutil.copytree(ROOT / 'src/quickshell', shell, symlinks=True)
            (root / 'libexec').symlink_to(ROOT / 'src/libexec', target_is_directory=True)
            (root / 'assets').symlink_to(ROOT / 'src/assets', target_is_directory=True)
            (shell / 'native-test.qml').write_text((ROOT / 'tests/screen-extract/native.qml').read_text())
            (root / 'tonantzintla').mkdir()
            (root / 'tonantzintla/settings.json').write_text('{"clipboardPaused":true,"motion":false}')
            fake = root / 'bin'
            fake.mkdir()
            (fake / 'python3').symlink_to(sys.executable)
            copy = fake / 'wl-copy'
            copy.write_text(f'#!{sys.executable}\nimport os,sys\nfrom pathlib import Path\nPath(os.environ["EXTRACT_TEST_CLIPBOARD"]).write_bytes(sys.stdin.buffer.read())\nwith open(os.environ["EXTRACT_TEST_CLIPBOARD"] + ".calls", "a") as calls: calls.write("1")\n')
            copy.chmod(0o755)
            selector = fake / 'slurp'
            selector.write_text(f'#!{sys.executable}\nimport os,time\nfrom pathlib import Path\nPath(os.environ["EXTRACT_TEST_SELECTED"]).write_text(str(os.getpid()))\ntime.sleep(60)\n')
            selector.chmod(0o755)
            image = root / 'qr.png'
            subprocess.run(['qrencode', '-s', '6', '-o', str(image), EXPECTED], check=True)
            screenshot = root / 'capture.png'
            clipboard = root / 'clipboard.txt'
            selection = root / 'selected.txt'
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory,
                       XDG_CACHE_HOME=directory, XDG_STATE_HOME=directory,
                       XDG_RUNTIME_DIR=directory, XDG_DATA_HOME=directory,
                       TMPDIR=directory, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',
                       DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent',
                       PATH=str(fake) + ('' if missing else ':' + os.environ['PATH']),
                       EXTRACT_TEST_MODE='missing' if missing else mode,
                       EXTRACT_TEST_IMAGE=str(image), EXTRACT_TEST_CAPTURE=str(screenshot),
                       EXTRACT_TEST_CLIPBOARD=str(clipboard), EXTRACT_TEST_SELECTED=str(selection))
            for key in ('WAYLAND_DISPLAY', 'NIRI_SOCKET', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key, None)
            process = subprocess.run([shutil.which('qs'), '-p', str(shell / 'native-test.qml'), '--no-color'],
                                     env=env, capture_output=True, text=True, timeout=18)
            output = process.stdout + process.stderr
            artifacts = os.environ.get('TONA_SCREEN_EXTRACT_ARTIFACTS')
            if artifacts:
                target = Path(artifacts)
                target.mkdir(parents=True, exist_ok=True)
                (target / ('missing.log' if missing else mode + '.log')).write_text(output)
                if screenshot.exists():
                    shutil.copyfile(screenshot, target / 'capture.png')
            self.assertEqual(process.returncode, 0, output)
            self.assertIn('EXTRACT_COMPLETE 0', output)
            for bad in ('EXTRACT_FAIL', 'ReferenceError', 'TypeError', 'Binding loop', 'Unable to assign', 'Failed to load configuration'):
                self.assertNotIn(bad, output)
            self.assertEqual(list(root.glob('tonantzintla-extract-*')), [], 'Captured images must be removed after cancellation')
            if missing or mode != 'normal':
                self.assertFalse(clipboard.exists())
            else:
                self.assertGreater(screenshot.stat().st_size, 10000)
                self.assertEqual(clipboard.read_bytes(), EXPECTED.encode('utf-8'))
                self.assertEqual(Path(str(clipboard) + '.calls').read_text(), '1', 'Copy must run exactly once, only when explicitly requested')
                with self.assertRaises(ProcessLookupError):
                    os.kill(int(selection.read_text()), 0)

    def test_real_qr_copy_clear_cancel_and_full_widget_render(self):
        self.scenario()

    def test_missing_decoder_is_disabled_and_reports_error(self):
        self.scenario(missing=True)

    def test_copy_failed_start_recovers(self):
        self.scenario(mode='copy-fail')

    def test_reader_failed_start_recovers(self):
        self.scenario(mode='reader-fail')

    def test_probe_failed_start_reports_unavailable(self):
        self.scenario(mode='probe-fail')
