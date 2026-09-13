"""Run the real CLI with fake git, installer and lifecycle endpoints."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SyncTests(unittest.TestCase):
    def run_sync(self, **overrides):
        with tempfile.TemporaryDirectory(prefix='blackhole-sync-') as directory:
            root = Path(directory)
            (root / 'bin').mkdir()
            (root / 'src/libexec').mkdir(parents=True)
            # Worktrees have a .git file rather than a directory.
            (root / '.git').write_text('gitdir: unused-test-path\n')
            shutil.copy2(ROOT / 'bin/blackhole', root / 'bin/blackhole')
            fixtures = {
                'git': '#!/bin/bash\ncase "$3" in\nstatus) printf "%s" "${DIRTY:-}"; exit "${STATUS_EXIT:-0}";;\npull) echo pull >> "$TRACE"; exit "${PULL_EXIT:-0}";;\nesac\n',
                'tonantzintla-installer': '#!/bin/bash\necho install >> "$TRACE"\nexit "${INSTALL_EXIT:-0}"\n',
                'qs': '#!/bin/bash\nexit 0\n',
            }
            for name, content in fixtures.items():
                path = root / 'bin' / name
                path.write_text(content)
                path.chmod(0o755)
            (root / 'src/libexec/session-daemon.py').write_text(
                'import os, sys\nwith open(os.environ["TRACE"], "a") as f: f.write(sys.argv[1] + "\\n")\n')
            trace = root / 'trace'
            env = dict(os.environ, PATH=str(root / 'bin') + ':' + os.environ['PATH'],
                       XDG_DATA_HOME=str(root / 'data'), TRACE=str(trace), **overrides)
            result = subprocess.run([str(root / 'bin/blackhole'), 'sync'], env=env,
                                    capture_output=True, text=True, timeout=10)
            return result, trace.read_text().splitlines() if trace.exists() else []

    def test_success_installs_then_restarts_once(self):
        result, actions = self.run_sync()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(actions, ['pull', 'install', 'stop', 'start'])

    def test_pull_failure_stops_before_install(self):
        result, actions = self.run_sync(PULL_EXIT='7')
        self.assertEqual(result.returncode, 7)
        self.assertEqual(actions, ['pull'])

    def test_install_failure_does_not_restart(self):
        result, actions = self.run_sync(INSTALL_EXIT='8')
        self.assertEqual(result.returncode, 8)
        self.assertEqual(actions, ['pull', 'install'])

    def test_dirty_or_unreadable_source_never_pulls(self):
        for options in ({'DIRTY': ' M file'}, {'STATUS_EXIT': '9'}):
            result, actions = self.run_sync(**options)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(actions, [])
