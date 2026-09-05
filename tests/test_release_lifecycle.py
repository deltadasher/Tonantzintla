import importlib.util
from pathlib import Path
import tempfile
import os
import socket
import subprocess
import sys
import time
import unittest
from unittest.mock import patch, Mock

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "src/libexec" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ReleaseLifecycleTests(unittest.TestCase):
    def test_real_supervisor_restart_and_session_exit(self):
        module = load("session-daemon")
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            display = socket.socket(socket.AF_UNIX)
            try:
                display.bind(str(base / "wayland-test"))
            except PermissionError:
                display.close()
                self.skipTest("sandbox blocks Unix socket creation")
            fake = base / "qs"
            fake.write_text(f"#!{sys.executable}\nimport time\ntime.sleep(120)\n")
            fake.chmod(0o755)
            env = dict(os.environ, XDG_RUNTIME_DIR=folder, WAYLAND_DISPLAY="wayland-test",
                       PATH=folder + os.pathsep + os.environ["PATH"])
            command = [sys.executable, str(ROOT / "src/libexec/session-daemon.py")]
            try:
                subprocess.run(command + ["start"], env=env, check=True, timeout=10)
                directory = base / "tonantzintla-session"
                first = module.request(directory, "status")
                subprocess.run(command + ["start"], env=env, check=True, timeout=10)
                self.assertEqual(first["pid"], module.request(directory, "status")["pid"])
                os.kill(first["pid"], 9)
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    state = module.request(directory, "status")
                    if state["pid"] != first["pid"] and state["running"]:
                        break
                    time.sleep(0.1)
                else:
                    self.fail("child was not restarted")
                display.close()
                (base / "wayland-test").unlink()
                deadline = time.monotonic() + 6
                while (directory / "control").exists() and time.monotonic() < deadline:
                    time.sleep(0.1)
                self.assertFalse((directory / "control").exists())
            finally:
                subprocess.run(command + ["stop"], env=env, timeout=10)
                display.close()

    def test_drift_detects_content_changes_even_when_revision_is_unchanged(self):
        module = load("build-status")
        with tempfile.TemporaryDirectory() as folder:
            source, installed = Path(folder) / "source", Path(folder) / "installed"
            for base in (source, installed):
                (base / "src").mkdir(parents=True)
                (base / "src/file.qml").write_text("original")
            self.assertEqual(list(module.differences(source, installed)), [])
            (source / "src/file.qml").write_text("edited")
            self.assertEqual(list(module.differences(source, installed)), ["src/file.qml"])

    def test_start_is_idempotent(self):
        module = load("session-daemon")
        with patch.object(module, "runtime", return_value=Path("/unused")), \
             patch.object(module, "request", return_value={"root": str(module.ROOT)}), \
             patch.object(module.subprocess, "Popen") as spawn, \
             patch.object(module.sys, "argv", ["daemon", "start"]):
            module.main()
            spawn.assert_not_called()

    def test_start_rejects_another_checkouts_supervisor(self):
        module = load("session-daemon")
        with patch.object(module, "runtime", return_value=Path("/unused")), \
             patch.object(module, "request", return_value={"root": "/other"}), \
             patch.object(module.sys, "argv", ["daemon", "start"]):
            with self.assertRaises(RuntimeError):
                module.main()

    def test_shutdown_targets_child_process_group(self):
        module = load("session-daemon")
        child = Mock(pid=12345)
        with patch.object(module.os, "killpg") as kill:
            module.terminate(child)
            self.assertEqual(kill.call_count, 2)
            self.assertEqual(kill.call_args.args[0], 12345)


if __name__ == "__main__":
    unittest.main()
