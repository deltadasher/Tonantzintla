"""Native popup bindings and placement consumers; no live compositor actions."""
import os
import json
import re
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class IslandSettingsNativeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("qs"), "Quickshell unavailable")
    def test_target_edge_geometry_and_placement_consumers(self):
        source = (ROOT / "tests/aperture/island-settings.qml").read_text().replace("../../src/quickshell", ".")
        # Offscreen Qt has no layer-shell PanelWindow backend. Run the complete
        # production popup body in a Window, replacing only its platform host.
        popup = (ROOT / "src/quickshell/modules/aperture/IslandQuickSettings.qml").read_text()
        popup = popup.replace('import "."', 'import "./modules/aperture"')
        popup = popup.replace('"../.."', '"."').replace('"../../', '"./')
        popup = popup.replace("PanelWindow {", "Window {", 1)
        popup = re.sub(r"(?m)^    screen:.*$", "    width: 800; height: 800; visible: true", popup)
        for line in ("    focusable: true", "    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive",
                     "    anchors { top: true; bottom: true; left: true; right: true }",
                     "    exclusionMode: ExclusionMode.Ignore", "    WlrLayershell.layer: WlrLayer.Overlay",
                     '    WlrLayershell.namespace: "tonantzintla-island-popover"'):
            popup = popup.replace(line, "")
        with tempfile.TemporaryDirectory(prefix="island-settings-") as directory:
            folder = Path(directory)
            (folder / "tonantzintla").mkdir()
            (folder / "tonantzintla/settings.json").write_text(json.dumps({"clipboardPaused":True,"motion":False,"barPosition":"top", "barOutputOverrides":json.dumps({"TEST-DP":{"barPosition":"bottom"}}), "barIslandPlacements":json.dumps({"TEST-DP":{"clock":{"edge":"right","zone":"end","order":0}}}), "barLayoutHorizontal":json.dumps({"start":["launcher"],"center":["clock"],"end":["status"]}), "barLayoutVertical":json.dumps({"start":["media"],"center":[],"end":["status"]})}))
            (folder / "offscreen.json").write_text(json.dumps({"screens":[{"name":"OTHER", "width":800,"height":800}, {"name":"TEST-DP", "width":800,"height":800}]}))
            binaries = folder / "bin"
            binaries.mkdir()
            for name in ("niri", "wl-paste", "cliphist"):
                executable = binaries / name
                executable.write_text("#!/bin/sh\nexit 0\n")
                executable.chmod(0o755)
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory,
                       XDG_CACHE_HOME=directory, XDG_STATE_HOME=directory,
                       XDG_DATA_HOME=directory, XDG_RUNTIME_DIR=directory,
                       QT_QPA_PLATFORM="offscreen:configfile=" + str(folder / "offscreen.json"), QT_QUICK_BACKEND="software",
                       DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent",
                       PATH=str(binaries) + ":" + os.environ["PATH"])
            for key in ("WAYLAND_DISPLAY", "NIRI_SOCKET", "SWAYSOCK", "HYPRLAND_INSTANCE_SIGNATURE"):
                env.pop(key, None)
            with tempfile.NamedTemporaryFile(mode="w", prefix="test-popup-", suffix=".qml", dir=ROOT / "src/quickshell") as popup_file, tempfile.NamedTemporaryFile(mode="w", prefix="test-island-", suffix=".qml", dir=ROOT / "src/quickshell") as harness:
                popup_file.write(popup)
                popup_file.flush()
                source = source.replace('IslandQuickSettings { id: popup; modelData: Quickshell.screens[0] }',
                    'property var popup: popupLoader.item\n    Loader { id: popupLoader; source: "' + Path(popup_file.name).name + '"; onLoaded: item.modelData = Quickshell.screens[0] }')
                # required properties must be passed when constructing the host.
                popup_file.seek(0)
                popup_file.write(popup.replace("required property var modelData", "property var modelData: Quickshell.screens[0]", 1))
                popup_file.truncate()
                popup_file.flush()
                harness.write(source)
                harness.flush()
                result = subprocess.run(["qs", "-p", harness.name, "--no-color"], env=env,
                                        capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("ISLAND COMPLETE 0 failures", output)
            for failure in ("ReferenceError", "TypeError", "Unable to assign", "Failed to load configuration", "ISLAND TIMEOUT"):
                self.assertNotIn(failure, output)
