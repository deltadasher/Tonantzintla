"""Safety tests for the clipboard cache helper CLI."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]


def load_helper():
    path = ROOT / "src" / "libexec" / "clipboard-index.py"
    spec = importlib.util.spec_from_file_location("clipboard_index", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


clipboard_index = load_helper()


class ClipboardHelperTests(unittest.TestCase):
    def test_text_size_is_decoded_once_then_cached(self) -> None:
        listing = mock.Mock(stdout="12\tshort preview\n")
        decoded = mock.Mock(stdout=("x" * 240).encode())
        with tempfile.TemporaryDirectory() as cache_dir:
            with (
                mock.patch.object(
                    clipboard_index.subprocess,
                    "run",
                    side_effect=[listing, decoded],
                ) as first_run,
                mock.patch.object(
                    sys, "argv", ["clipboard-index.py", cache_dir]
                ),
                contextlib.redirect_stdout(io.StringIO()) as output,
            ):
                clipboard_index.main()
            self.assertEqual(2, first_run.call_count)
            self.assertEqual(240, json.loads(output.getvalue())[0]["size"])

            with (
                mock.patch.object(
                    clipboard_index.subprocess, "run", return_value=listing
                ) as second_run,
                mock.patch.object(
                    sys, "argv", ["clipboard-index.py", cache_dir]
                ),
                contextlib.redirect_stdout(io.StringIO()) as cached_output,
            ):
                clipboard_index.main()
            self.assertEqual(1, second_run.call_count)
            self.assertEqual(240, json.loads(cached_output.getvalue())[0]["size"])

    def test_help_does_not_create_a_literal_help_directory(self) -> None:
        accidental = ROOT / "--help"
        self.assertFalse(accidental.exists())
        result = subprocess.run(
            ["python3", str(ROOT / "src" / "libexec" / "clipboard-index.py"), "--help"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn("cache_dir", result.stdout)
        self.assertFalse(accidental.exists())


if __name__ == "__main__":
    unittest.main()
