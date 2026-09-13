import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest


class IdleWatcherTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_owned_process_starts_and_stops_without_locking(self):
        repo = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory(prefix='idle-watcher-') as directory:
            folder = Path(directory)
            program = folder / 'swayidle'
            shutil.copyfile(repo / 'tests/fake-swayidle.py', program)
            program.chmod(0o700)
            argsfile = folder / 'args.json'
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       XDG_RUNTIME_DIR=directory, IDLE_TEST_PROGRAM=str(program),
                       IDLE_TEST_ARGS=str(argsfile),
                       IDLE_TEST_COMPONENT=(repo / 'src/quickshell/components/IdleWatcher.qml').as_uri())
            env.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run(['qs', '-p', str(repo / 'tests/qml/idle-watcher.qml'), '--no-color'],
                                    env=env, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertIn('IDLE_STARTED', output)
            self.assertIn('IDLE_STOPPED', output)
            self.assertNotIn('IDLE_FAILED', output)
            args = json.loads(argsfile.read_text())
            self.assertEqual(args[:3], ['-w', 'timeout', '60'])
            self.assertEqual(shlex.split(args[3]), ['exec', "/tmp/a path/black'hole", 'lock'])
