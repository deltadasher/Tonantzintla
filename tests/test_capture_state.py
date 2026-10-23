"""Recorder lifecycle integration uses only an isolated fake executable."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'src/libexec/capture-state.py'


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(HELPER.is_file(), 'Capture requires confirmed lifecycle state')
        spec = importlib.util.spec_from_file_location('capture_state', HELPER)
        self.helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.helper)

    def test_options_build_real_backend_arguments(self):
        command = self.helper.recorder_command('/tmp/recording.mp4', 30, True, True, False, True)
        self.assertEqual(command[:3], ['gpu-screen-recorder', '-w', 'portal'])
        self.assertEqual(command[command.index('-f') + 1], '30')
        self.assertEqual(command[command.index('-a') + 1], 'default_output|default_input')
        self.assertEqual(command[command.index('-cursor') + 1], 'no')
        self.assertIn('-write-first-frame-ts', command)
        quiet = self.helper.recorder_command('/tmp/a.mp4', 60, False, False, True, False)
        self.assertNotIn('-a', quiet)
        self.assertNotIn('-write-first-frame-ts', quiet)
        with self.assertRaises(ValueError):
            self.helper.recorder_command('/tmp/a.mp4', 9999, False, False, True, False)

    def test_stale_owner_cannot_claim_recording_or_signal_reused_pid(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.dict(os.environ, {'XDG_STATE_HOME': directory}):
            self.helper.write_state({'state': 'recording', 'ownerPid': os.getpid(), 'ownerStart': 'wrong', 'token': 'old'})
            state = self.helper.read_status()
            self.assertEqual(state['state'], 'error')
            self.assertIn('ended', state['message'])
            self.helper.request_stop()
            self.assertFalse(self.helper.stop_path().exists())

    def test_first_frame_finalizing_and_saved_are_confirmed(self):
        self.exercise_fake(success=True)

    def test_failed_recorder_is_error_not_saved(self):
        self.exercise_fake(success=False)

    def test_legacy_recorder_remains_finalizing_after_stop(self):
        self.exercise_stop_feedback(late_timestamp=False)

    def test_late_first_frame_does_not_reenter_recording_after_stop(self):
        self.exercise_stop_feedback(late_timestamp=True)

    def exercise_stop_feedback(self, late_timestamp):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary = root / 'bin'
            binary.mkdir()
            recorder = binary / 'gpu-screen-recorder'
            recorder.write_text('#!' + sys.executable + '\n' + '''import os, pathlib, signal, sys, time
late = os.environ['LATE_TIMESTAMP'] == '1'
if '--help' in sys.argv:
    print('-write-first-frame-ts yes|no' if late else 'legacy recorder')
    raise SystemExit(0)
root = pathlib.Path(os.environ['HOME'])
out = pathlib.Path(sys.argv[sys.argv.index('-o') + 1])
def stop(*args):
    out.write_bytes(b'fixture frames')
    if late:
        pathlib.Path(str(out)+'.ts').write_text('monotonic_microsec\\trealtime_microsec\\n123\\t456\\n')
    (root/'stopping').touch()
    time.sleep(.7)
    raise SystemExit(0)
signal.signal(signal.SIGINT, stop)
(root/'ready').touch()
while True: time.sleep(.02)
''')
            recorder.chmod(0o755)
            env = dict(os.environ, HOME=str(root), XDG_STATE_HOME=str(root / 'state'),
                       PATH=str(binary) + ':' + os.environ['PATH'], LATE_TIMESTAMP='1' if late_timestamp else '0')
            proc = subprocess.Popen([sys.executable, str(HELPER), 'run', '--countdown', '0'],
                                    env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            try:
                statefile = root / 'state/tonantzintla/capture.json'
                def wait_file(path):
                    deadline = time.monotonic() + 6
                    while not path.exists() and time.monotonic() < deadline:
                        time.sleep(.02)
                    self.assertTrue(path.exists(), 'Recorder did not reach ' + path.name)
                wait_file(root / 'ready')
                subprocess.run([sys.executable, str(HELPER), 'stop'], env=env, check=True, capture_output=True)
                wait_file(root / 'stopping')
                # Allow another real supervisor iteration after SIGINT. A late
                # timestamp or unsupported timestamp must not regress shutdown.
                time.sleep(.15)
                observed = []
                deadline = time.monotonic() + 3
                while proc.poll() is None and time.monotonic() < deadline:
                    phase = json.loads(statefile.read_text())['state']
                    if phase in self.helper.ACTIVE:
                        observed.append(phase)
                    time.sleep(.03)
                self.assertEqual(proc.wait(timeout=3), 0)
                self.assertTrue(observed, 'Finalizing must be observable before the recorder exits')
                self.assertEqual(set(observed), {'finalizing'})
                self.assertEqual(json.loads(statefile.read_text())['state'], 'saved')
            finally:
                if proc.poll() is None:
                    proc.terminate()
                    proc.wait(timeout=3)
                proc.stderr.close()

    def exercise_fake(self, success):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary = root / 'bin'
            binary.mkdir()
            recorder = binary / 'gpu-screen-recorder'
            recorder.write_text('#!' + sys.executable + '\n' + '''import pathlib, signal, sys, time
if '--help' in sys.argv:
    print('-write-first-frame-ts yes|no'); raise SystemExit(0)
out = pathlib.Path(sys.argv[sys.argv.index('-o') + 1])
time.sleep(.2)
''' + ('''out.write_bytes(b'fixture frames')
pathlib.Path(str(out)+'.ts').write_text('monotonic_microsec\\trealtime_microsec\\n123\\t456\\n')
def stop(*args):
    time.sleep(.3)
    raise SystemExit(0)
signal.signal(signal.SIGINT, stop)
while True: time.sleep(.02)
''' if success else 'raise SystemExit(7)\n'))
            recorder.chmod(0o755)
            env = dict(os.environ, HOME=str(root), XDG_STATE_HOME=str(root / 'state'), PATH=str(binary) + ':' + os.environ['PATH'])
            proc = subprocess.Popen([sys.executable, str(HELPER), 'run', '--countdown', '0'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            try:
                statefile = root / 'state/tonantzintla/capture.json'
                def wait_state(states):
                    deadline = time.monotonic() + 6
                    while time.monotonic() < deadline:
                        try:
                            value = json.loads(statefile.read_text())
                            if value.get('state') in states: return value
                        except (OSError, ValueError): pass
                        time.sleep(.03)
                    self.fail('Never observed ' + repr(states) + ': ' + (statefile.read_text() if statefile.exists() else 'missing'))
                if success:
                    wait_state({'pending'})
                    active = wait_state({'recording'})
                    self.assertTrue(Path(active['output']).is_file())
                    subprocess.run([sys.executable, str(HELPER), 'stop'], env=env, check=True, capture_output=True)
                    wait_state({'finalizing'})
                    saved = wait_state({'saved'})
                    self.assertGreater(Path(saved['output']).stat().st_size, 0)
                else:
                    error = wait_state({'error'})
                    self.assertIn('7', error['message'])
                self.assertEqual(proc.wait(timeout=3), 0)
            finally:
                if proc.poll() is None:
                    proc.terminate()
                    proc.wait(timeout=3)
                proc.stderr.close()
