import importlib.util
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]


def load_helper():
    path = ROOT / "src/libexec/niri-ownership.py"
    spec = importlib.util.spec_from_file_location("niri_ownership", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class NiriOwnershipTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.config = root / "config/niri/config.kdl"
        self.config.parent.mkdir(parents=True)
        self.config.write_text('binds { Mod+D { spawn "blackhole"; } }\n')
        self.bin = root / "bin"
        self.bin.mkdir()
        niri = self.bin / "niri"
        niri.write_text("#!/bin/sh\nexit 0\n")
        niri.chmod(niri.stat().st_mode | stat.S_IXUSR)
        self.env = mock.patch.dict(os.environ, {
            "XDG_CONFIG_HOME": str(root / "config"),
            "XDG_STATE_HOME": str(root / "state"),
            "PATH": str(self.bin) + os.pathsep + os.environ.get("PATH", ""),
        }, clear=False)
        self.env.start()
        self.mod = load_helper()

    def tearDown(self):
        self.env.stop()
        self.temp.cleanup()

    def invoke(self, action, *extra):
        parser = self.mod.parser()
        args = parser.parse_args([action, "--config", str(self.config), *extra])
        if action == "inspect":
            return self.mod.cmd_inspect(args)
        if action == "check":
            return self.mod.cmd_check(args)
        if action == "accept":
            return self.mod.cmd_accept(args)
        if action == "handoff":
            return self.mod.cmd_handoff(args)
        if action in ("disable", "enable"):
            return self.mod.cmd_disabled(args)
        if action == "restore":
            return self.mod.cmd_restore(args)
        return self.mod.cmd_snapshot(args)

    def accept_tonantzintla(self):
        self.assertEqual(self.invoke("accept", "--shell", "tonantzintla"), 0)

    def test_external_serpantinum_overwrite_is_blocked(self):
        self.accept_tonantzintla()
        self.config.write_text('include "~/.config/serpantinum/niri.kdl"\nspawn-at-startup "serpantinumd"\n')
        self.assertEqual(self.invoke("check", "--quiet"), 3)
        info = self.mod.inspection(self.mod.load(), self.config)
        self.assertEqual(info["classification"], "unexpected-overwrite")
        self.assertEqual(info["detected_shell"], "serpantinum")

    def test_legitimate_user_edit_is_never_rewritten(self):
        self.accept_tonantzintla()
        edited = 'binds { Mod+D { spawn "blackhole"; } Mod+E { spawn "foot"; } }\n'
        self.config.write_text(edited)
        self.assertEqual(self.invoke("check", "--quiet"), 0)
        self.assertEqual(self.config.read_text(), edited)
        info = self.mod.inspection(self.mod.load(), self.config)
        self.assertEqual(info["classification"], "user-edit")

    def test_include_content_drift_is_detected_without_entrypoint_rewrite(self):
        include = self.config.parent / "owned.kdl"
        include.write_text('binds { Mod+D { spawn "blackhole"; } }\n')
        self.config.write_text('include "owned.kdl"\n')
        self.accept_tonantzintla()
        include.write_text('spawn-at-startup "serpantinumd"\n')
        self.assertEqual(self.invoke("check", "--quiet"), 3)
        info = self.mod.inspection(self.mod.load(), self.config)
        self.assertEqual(info["detected_shell"], "serpantinum")

    def test_intentional_handoff_is_not_recovery(self):
        self.accept_tonantzintla()
        self.assertEqual(self.invoke("handoff", "--shell", "serpantinum"), 0)
        self.config.write_text('include "~/.config/serpantinum/niri.kdl"\n')
        info = self.mod.inspection(self.mod.load(), self.config)
        self.assertEqual(info["classification"], "intentional-switch")
        self.assertEqual(self.invoke("check", "--quiet"), 4)

    def test_disabled_state_prevents_daemon_resurrection(self):
        self.accept_tonantzintla()
        self.assertEqual(self.invoke("disable"), 0)
        self.assertEqual(self.invoke("check", "--quiet"), 4)
        daemon_spec = importlib.util.spec_from_file_location(
            "session_daemon", ROOT / "src/libexec/session-daemon.py"
        )
        daemon = importlib.util.module_from_spec(daemon_spec)
        daemon_spec.loader.exec_module(daemon)
        allowed, _ = daemon.ownership_allows_start()
        self.assertFalse(allowed)

    def test_modified_snapshot_cannot_be_restored(self):
        self.accept_tonantzintla()
        state = self.mod.load()
        snapshot = Path(state["last_good_snapshot"]["path"])
        snapshot.write_text("not the verified snapshot\n")
        self.config.write_text('include "other-shell.kdl"\n')
        self.assertEqual(self.invoke("restore"), 1)
        self.assertIn("other-shell", self.config.read_text())


if __name__ == "__main__":
    unittest.main()
