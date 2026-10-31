"""Compile migrated ThemeMark instances from their actual consumer source."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def mark_instances(source):
    # Preserve the complete real instance, including every property assignment.
    import re
    for match in re.finditer(r"\bThemeMark\s*\{", source):
        depth = 1
        end = match.end()
        while depth and end < len(source):
            depth += (source[end] == "{") - (source[end] == "}")
            end += 1
        if depth:
            raise ValueError("Unterminated ThemeMark instance")
        yield source[match.start():end]


class IdentityConsumerCompileTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("qs"), "Quickshell unavailable")
    def test_actual_logo_instances_compile_without_obsolete_properties(self):
        qml = ROOT / "src/quickshell"
        with tempfile.TemporaryDirectory(prefix="identity-consumers-") as directory:
            folder = Path(directory)
            sources = []
            for consumer in sorted(qml.rglob("*.qml")):
                for index, instance in enumerate(mark_instances(consumer.read_text())):
                    path = folder / (str(len(sources)) + "-" + consumer.stem + ".qml")
                    path.write_text('import QtQuick\nimport QtQuick.Layouts\nimport "'
                                    + (qml / "components").as_uri() + '"\nItem {\n'
                                    + instance + '\n}\n')
                    sources.append(path)
            self.assertGreaterEqual(len(sources), 8, "all migrated logo consumers are included")
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory,
                       XDG_CACHE_HOME=directory, XDG_DATA_HOME=directory, XDG_STATE_HOME=directory,
                       XDG_RUNTIME_DIR=directory, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent", DBUS_SYSTEM_BUS_ADDRESS="unix:path=/nonexistent",
                       TONANTZINTLA_TEST_SOURCES=json.dumps([str(path) for path in sources]))
            for key in ("WAYLAND_DISPLAY", "NIRI_SOCKET", "SWAYSOCK", "HYPRLAND_INSTANCE_SIGNATURE"):
                env.pop(key, None)
            result = subprocess.run(["qs", "-p", str(ROOT / "tests/qml/compile-surfaces.qml"), "--no-color"],
                                    env=env, capture_output=True, text=True, timeout=20)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("SURFACE COMPILE COMPLETE 0 failures", output)
            self.assertNotIn("SURFACE FAIL", output)
