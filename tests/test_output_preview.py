import importlib.util
import fcntl
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('output_preview', Path(__file__).resolve().parents[1] / 'src/libexec/output-preview.py')
preview = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(preview)


class OutputPreviewTests(unittest.TestCase):
    def test_concurrent_preview_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            with (folder / 'watchdog.lock').open('a') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                with patch.object(preview, 'runtime', return_value=folder), patch.object(preview, 'command') as command:
                    with self.assertRaisesRegex(ValueError, 'already running'):
                        preview.preview('DP-1', 1.5)
                    command.assert_not_called()

    def run_preview(self, action=None):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            current = [1.0]
            calls = []
            def outputs():
                return {'HDMI-A-1': {'logical': {'scale': current[0]}}}
            def command(*args):
                calls.append(args)
                current[0] = float(args[-1])
            def sleep(_):
                state = preview.state_of(folder)
                if action == 'keep':
                    preview.keep(state['token'])
                elif action == 'external':
                    current[0] = 2.0
                    preview.keep(state['token'])
            with patch.object(preview, 'runtime', return_value=folder), patch.object(preview, 'outputs', side_effect=outputs), patch.object(preview, 'command', side_effect=command), patch.object(preview.time, 'sleep', side_effect=sleep):
                preview.preview('HDMI-A-1', 1.5, seconds=0.05 if action else 0)
            return current[0], calls, preview.state_of(folder)

    def test_timeout_restores_original(self):
        scale, calls, state = self.run_preview()
        self.assertEqual(scale, 1.0)
        self.assertEqual(len(calls), 2)
        self.assertEqual(state['phase'], 'reverted')

    def test_confirmation_keeps_session_change(self):
        scale, calls, state = self.run_preview('keep')
        self.assertEqual(scale, 1.5)
        self.assertEqual(len(calls), 1)
        self.assertEqual(state['phase'], 'kept')

    def test_external_change_is_not_overwritten(self):
        scale, calls, state = self.run_preview('external')
        self.assertEqual(scale, 2.0)
        self.assertEqual(len(calls), 1)
        self.assertEqual(state['phase'], 'changed')

    def test_inactive_output_rejected(self):
        with self.assertRaises(ValueError):
            preview.scale_of({'DP-1': {'logical': None}}, 'DP-1')

    def test_invalid_scale_never_dispatches(self):
        with patch.object(preview, 'command') as command:
            for scale in (0, -1, float('nan'), 10):
                with self.assertRaises(ValueError):
                    preview.preview('DP-1', scale)
            command.assert_not_called()

    def test_stale_confirmation_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(preview, 'runtime', return_value=Path(directory)):
                with self.assertRaises(ValueError):
                    preview.keep('stale')
