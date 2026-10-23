import importlib.util
from pathlib import Path
import tempfile
import os
import socket
import subprocess
import sys
import time
import unittest
from unittest.mock import patch, Mock, MagicMock, mock_open

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "src/libexec" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class SessionDaemonTests(unittest.TestCase):
    def test_quickshell_allocator_policy_preserves_environment_without_mutation(self):
        module = load("session-daemon")
        policy = "narenas:2,dirty_decay_ms:0,muzzy_decay_ms:0"
        for value in (None, "", "thp:never,narenas:8,dirty_decay_ms:1000,background_thread:true"):
            original = {"WAYLAND_DISPLAY": "wayland-test", "PATH": "/test/bin"}
            if value is not None:
                original["MALLOC_CONF"] = value
            expected = dict(original)
            with patch.dict(module.os.environ, original, clear=True):
                child = module.quickshell_environment()
                self.assertEqual(dict(module.os.environ), expected)
            self.assertEqual(child["MALLOC_CONF"], (value + "," if value else "") + policy)
            self.assertEqual(child["WAYLAND_DISPLAY"], original["WAYLAND_DISPLAY"])
            self.assertEqual(child["PATH"], original["PATH"])
            options = dict(part.split(":", 1) for part in child["MALLOC_CONF"].split(","))
            self.assertEqual(options["narenas"], "2")
            self.assertEqual(options["dirty_decay_ms"], "0")
            self.assertEqual(options["muzzy_decay_ms"], "0")

    def test_supervisor_scopes_allocator_policy_to_quickshell_spawn(self):
        module = load("session-daemon")
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder) / "session"
            directory.mkdir()
            (Path(folder) / "wayland-test").touch()
            server = MagicMock()
            server.__enter__.return_value = server
            server.accept.side_effect = socket.timeout
            child = Mock(pid=12345, returncode=0)
            child.poll.return_value = 0
            inherited = {"WAYLAND_DISPLAY": "wayland-test", "MALLOC_CONF": "thp:never"}
            with patch.dict(module.os.environ, inherited, clear=True), \
                    patch.object(module.socket, "socket", return_value=server), \
                    patch.object(module.Path, "open", mock_open()), \
                    patch.object(module.fcntl, "flock"), \
                    patch.object(module.signal, "signal"), \
                    patch.object(module, "ownership_allows_start", return_value=(True, "")), \
                    patch.object(module, "terminate"), \
                    patch.object(module.subprocess, "Popen", return_value=child) as spawn:
                module.serve(directory)
                self.assertEqual(dict(module.os.environ), inherited)
            spawn.assert_called_once()
            self.assertEqual(spawn.call_args.args[0][:3], ["qs", "-n", "-p"])
            self.assertTrue(spawn.call_args.kwargs["start_new_session"])
            self.assertEqual(spawn.call_args.kwargs["env"]["MALLOC_CONF"],
                "thp:never,narenas:2,dirty_decay_ms:0,muzzy_decay_ms:0")

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
            fake.write_text(f"#!{sys.executable}\nimport os,time\nfrom pathlib import Path\nPath(os.environ['QS_ENV_CAPTURE']).write_text(os.environ.get('MALLOC_CONF',''))\ntime.sleep(120)\n")
            fake.chmod(0o755)
            env = dict(os.environ, XDG_RUNTIME_DIR=folder, WAYLAND_DISPLAY="wayland-test",
                       XDG_CONFIG_HOME=str(base / "config"),
                       QS_ENV_CAPTURE=str(base / "qs-environment"), MALLOC_CONF="thp:never,dirty_decay_ms:1000",
                       PATH=folder + os.pathsep + os.environ["PATH"])
            (base / "config/niri").mkdir(parents=True)
            (base / "config/niri/config.kdl").write_text('binds { Mod+D { spawn "blackhole"; } }\n')
            command = [sys.executable, str(ROOT / "src/libexec/session-daemon.py")]
            try:
                subprocess.run(command + ["start"], env=env, check=True, timeout=10)
                directory = base / "tonantzintla-session"
                first = module.request(directory, "status")
                deadline = time.monotonic() + 2
                while not (base / "qs-environment").exists() and time.monotonic() < deadline:
                    time.sleep(0.02)
                self.assertEqual((base / "qs-environment").read_text(),
                    "thp:never,dirty_decay_ms:1000,narenas:2,dirty_decay_ms:0,muzzy_decay_ms:0")
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
