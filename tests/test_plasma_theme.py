"""Tests for Tonantzintla's native KDE Plasma 6 Global Theme packages."""
from __future__ import annotations

import gzip
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

REPO = Path(__file__).resolve().parents[1]
HELPER = REPO / "src/libexec/plasma-theme.py"


class PlasmaThemeTests(unittest.TestCase):
    def test_bundled_plasma_tree_validates_and_parses_all_svgs(self):
        result = subprocess.run(
            ["python3", str(HELPER), "validate"],
            capture_output=True,
            text=True,
            check=True,
        )
        payload = json.loads(result.stdout)
        self.assertTrue(payload["ok"], payload)
        self.assertEqual(payload["missing"], [])
        self.assertEqual(payload["json_errors"], [])

        plasma_root = REPO / "plasma"
        svgz_files = list(plasma_root.rglob("*.svgz"))
        self.assertGreaterEqual(len(svgz_files), 12)
        for svgz in svgz_files:
            with gzip.open(svgz, "rb") as stream:
                root = ET.fromstring(stream.read())
            self.assertTrue(root.tag.endswith("svg"), str(svgz))

        # Ensure incomplete partial widget overrides are not shipped (Plasma inherits Breeze)
        for partial in ("button.svgz", "lineedit.svgz", "tabbar.svgz", "switch.svgz", "scrollbar.svgz"):
            self.assertFalse((plasma_root / "desktoptheme/tonantzintla/widgets" / partial).exists(), partial)

        # Ensure tasks.svgz stretches borders (preventing double-dot tiling) and supports all edges
        with gzip.open(plasma_root / "desktoptheme/tonantzintla/widgets/tasks.svgz", "rb") as stream:
            tasks_ids = {el.attrib.get("id") for el in ET.fromstring(stream.read()).iter()}
        for required_id in ("hint-stretch-borders", "focus-bottom", "north-focus-top", "west-focus-left", "east-focus-right"):
            self.assertIn(required_id, tasks_ids)

        # Ensure Aurorae decoration includes maximized flat headers and exact mask elements
        aur_ids = {el.attrib.get("id") for el in ET.fromstring((plasma_root / "aurorae/themes/Tonantzintla/decoration.svg").read_bytes()).iter()}
        for required_id in ("decoration-topleft", "decoration-inactive-topleft", "decoration-maximized-center", "mask-topleft"):
            self.assertIn(required_id, aur_ids)

        # Ensure Event Horizon launcher declares org.kde.plasma.launchermenu for Meta/Super key binding
        launcher_meta = json.loads((plasma_root / "plasmoids/org.tonantzintla.launcher/metadata.json").read_text(encoding="utf-8"))
        self.assertIn("org.kde.plasma.launchermenu", launcher_meta.get("X-Plasma-Provides", []))

        for svg in plasma_root.rglob("*.svg"):
            root = ET.fromstring(svg.read_bytes())
            self.assertTrue(root.tag.endswith("svg"), str(svg))

    def test_install_sync_status_and_uninstall_in_sandbox(self):
        with tempfile.TemporaryDirectory(prefix="tona-plasma-") as tmp:
            root = Path(tmp)
            data_home = root / "share"
            config_home = root / "config"
            (config_home / "tonantzintla").mkdir(parents=True)
            (config_home / "tonantzintla/settings.json").write_text(
                json.dumps({"accentName": "cyan", "spectralColors": {"accent": "#7cd8e6"}}),
                encoding="utf-8",
            )
            env = dict(
                os.environ,
                XDG_DATA_HOME=str(data_home),
                XDG_CONFIG_HOME=str(config_home),
                XDG_CACHE_HOME=str(root / "cache"),
            )

            install = subprocess.run(
                [str(REPO / "bin/blackhole"), "plasma", "sync", "--data-home", str(data_home)],
                env=env, capture_output=True, text=True, check=True,
            )
            self.assertTrue(json.loads(install.stdout)["ok"])
            colors_text = (data_home / "color-schemes/TonantzintlaDark.colors").read_text(encoding="utf-8")
            self.assertIn("ForegroundActive=124,216,230", colors_text)

            status = subprocess.run(
                [str(REPO / "bin/blackhole"), "plasma", "status", "--data-home", str(data_home)],
                env=env, capture_output=True, text=True, check=True,
            )
            self.assertTrue(json.loads(status.stdout)["installed"])

            if shutil.which("kpackagetool6"):
                lnf = subprocess.run(
                    ["kpackagetool6", "--type", "Plasma/LookAndFeel", "--list"],
                    env=env, capture_output=True, text=True, check=True,
                )
                self.assertIn("org.tonantzintla.desktop", lnf.stdout)
                dt = subprocess.run(
                    ["kpackagetool6", "--type", "Plasma/Theme", "--list"],
                    env=env, capture_output=True, text=True, check=True,
                )
                self.assertIn("tonantzintla", dt.stdout)

            if shutil.which("plasma-apply-colorscheme"):
                schemes = subprocess.run(
                    ["plasma-apply-colorscheme", "--list-schemes"],
                    env=env, capture_output=True, text=True, check=True,
                )
                self.assertIn("TonantzintlaDark", schemes.stdout)
                self.assertIn("TonantzintlaLight", schemes.stdout)

            uninstall = subprocess.run(
                [str(REPO / "bin/blackhole"), "plasma", "uninstall", "--data-home", str(data_home)],
                env=env, capture_output=True, text=True, check=True,
            )
            self.assertTrue(json.loads(uninstall.stdout)["ok"])
            status_after = subprocess.run(
                [str(REPO / "bin/blackhole"), "plasma", "status", "--data-home", str(data_home)],
                env=env, capture_output=True, text=True, check=True,
            )
            self.assertFalse(json.loads(status_after.stdout)["installed"])


if __name__ == "__main__":
    unittest.main()
