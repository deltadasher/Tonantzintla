import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class TransitionTests(unittest.TestCase):
    def test_ui_names_map_to_supported_backend_transitions(self):
        for backend in ('awww', 'swww'):
            for chosen, expected, angle in [('swipe', 'left', None), ('diagonal', 'wipe', '45')]:
                with self.subTest(backend=backend, chosen=chosen), tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    command = root / backend
                    command.write_text('#!' + sys.executable + '\nimport json,os,sys\nif sys.argv[1] == "img":\n open(os.environ["ARGS_FILE"], "w").write(json.dumps(sys.argv[1:]))\n')
                    command.chmod(0o755)
                    # Isolate every backend name even before implementation
                    # understands the requested backend argument.
                    for name in ('awww', 'swww', 'awww-daemon'):
                        stub = root / name
                        if not stub.exists():
                            stub.write_text(command.read_text())
                            stub.chmod(0o755)
                    original = root / 'my wall.png'
                    original.write_bytes(b'fixture')
                    result = root / 'args.json'
                    env = dict(os.environ, PATH=str(root)+':'+os.environ['PATH'], XDG_RUNTIME_DIR=str(root), ARGS_FILE=str(result))
                    subprocess.run(['bash', str(ROOT/'src/libexec/wallpaper-apply'), 'image', str(original), 'DP-1', chosen, backend], env=env, check=True, capture_output=True)
                    args = json.loads(result.read_text())
                    self.assertEqual(args[args.index('--transition-type')+1], expected)
                    if angle:
                        self.assertEqual(args[args.index('--transition-angle')+1], angle)
                    self.assertEqual(args[args.index('--outputs')+1], 'DP-1')
                    self.assertEqual(args[1], str(original))
