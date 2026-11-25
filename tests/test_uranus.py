"""Tests for Uranus, the standalone KDE Plasma edition, and the Plasma fixes it ships."""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
HELPER = REPO / "src/libexec/plasma-theme.py"
INSTALLER = REPO / "uranus/install.sh"
PLASMA = REPO / "plasma"


def sandbox_env(root: Path) -> dict[str, str]:
    """An environment in which nothing can reach the real home, config, or state."""
    home = root / "home"
    home.mkdir(parents=True, exist_ok=True)
    return dict(
        os.environ,
        HOME=str(home),
        XDG_DATA_HOME=str(home / ".local/share"),
        XDG_CONFIG_HOME=str(home / ".config"),
        XDG_CACHE_HOME=str(home / ".cache"),
        XDG_STATE_HOME=str(home / ".local/state"),
        URANUS_BIN_DIR=str(home / ".local/bin"),
        PYTHONDONTWRITEBYTECODE="1",
    )


def load_helper():
    spec = importlib.util.spec_from_file_location("plasma_theme_under_test", HELPER)
    module = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(module)
    return module


class UranusInstallerTests(unittest.TestCase):
    def test_install_runs_standalone_and_purge_removes_everything(self):
        with tempfile.TemporaryDirectory(prefix="uranus-") as tmp:
            env = sandbox_env(Path(tmp))
            home = Path(env["HOME"])
            runtime = home / ".local/share/uranus"

            subprocess.run([str(INSTALLER), "--skip-checks"], env=env, capture_output=True, text=True, check=True)

            self.assertTrue((runtime / ".uranus-runtime").is_file())
            self.assertTrue((runtime / "plasma/look-and-feel/org.tonantzintla.desktop/metadata.json").is_file())
            # Only the Plasma helper and its two modules: no Quickshell runtime comes along.
            self.assertEqual(
                sorted(entry.name for entry in (runtime / "src/libexec").iterdir()),
                ["plasma-theme.py", "plasma_plasmoids.py", "plasma_shaders.py"],
            )
            self.assertFalse((runtime / "src/quickshell").exists())
            link = home / ".local/bin/uranus"
            self.assertEqual(link.resolve(), (runtime / "bin/uranus").resolve())

            # The installed copy works without the checkout it came from.
            status = subprocess.run([str(link), "status", "--json"], env=env, capture_output=True, text=True, check=True)
            self.assertTrue(json.loads(status.stdout)["installed"])
            self.assertEqual(
                subprocess.run([str(link), "path"], env=env, capture_output=True, text=True, check=True).stdout.strip(),
                str(runtime.resolve()),
            )
            rebuilt = subprocess.run([str(link), "sync", "--json"], env=env, capture_output=True, text=True, check=True)
            self.assertTrue(json.loads(rebuilt.stdout)["ok"])

            subprocess.run([str(link), "uninstall", "--purge"], env=env, capture_output=True, text=True, check=True)
            self.assertFalse(runtime.exists())
            self.assertFalse(link.is_symlink())
            self.assertFalse((home / ".local/share/plasma/plasmoids/org.tonantzintla.launcher").exists())

    def test_installer_refuses_a_directory_it_did_not_create(self):
        with tempfile.TemporaryDirectory(prefix="uranus-") as tmp:
            env = sandbox_env(Path(tmp))
            foreign = Path(env["HOME"]) / ".local/share/uranus"
            foreign.mkdir(parents=True)
            (foreign / "keep.txt").write_text("mine", encoding="utf-8")

            result = subprocess.run([str(INSTALLER), "--skip-checks"], env=env, capture_output=True, text=True)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("was not created by this installer", result.stderr)
            self.assertEqual((foreign / "keep.txt").read_text(encoding="utf-8"), "mine")

    def test_purge_refuses_a_source_checkout(self):
        result = subprocess.run([str(REPO / "bin/uranus"), "path"], capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.strip(), str(REPO))
        self.assertFalse((REPO / ".uranus-runtime").exists())
        source = (REPO / "bin/uranus").read_text(encoding="utf-8")
        self.assertIn('[[ -f "$runtime_marker" ]] || fail', source)


class PlasmaLayoutSafetyTests(unittest.TestCase):
    def test_layout_is_saved_and_restored_without_touching_a_shell(self):
        helper = load_helper()
        with tempfile.TemporaryDirectory(prefix="uranus-layout-") as tmp:
            root = Path(tmp)
            config = root / "config"
            config.mkdir()
            original = "[Containments][1]\nplugin=org.kde.panel\n"
            (config / "plasma-org.kde.plasma.desktop-appletsrc").write_text(original, encoding="utf-8")
            previous = os.environ.get("XDG_STATE_HOME")
            os.environ["XDG_STATE_HOME"] = str(root / "state")
            try:
                saved = helper.backup_layout(config)
                self.assertIsNotNone(saved)
                self.assertEqual(saved.stat().st_mode & 0o777, 0o700)
                (config / "plasma-org.kde.plasma.desktop-appletsrc").write_text("replaced", encoding="utf-8")

                result = helper.restore_layout(config)

                self.assertTrue(result["ok"], result)
                self.assertFalse(result["plasmashell_restarted"])
                self.assertEqual(
                    (config / "plasma-org.kde.plasma.desktop-appletsrc").read_text(encoding="utf-8"), original,
                )
            finally:
                if previous is None:
                    del os.environ["XDG_STATE_HOME"]
                else:
                    os.environ["XDG_STATE_HOME"] = previous

    def test_installed_files_are_never_written_through_a_symlink(self):
        helper = load_helper()
        with tempfile.TemporaryDirectory(prefix="uranus-link-") as tmp:
            root = Path(tmp)
            victim = root / "victim"
            victim.write_text("untouched", encoding="utf-8")
            (root / "source").write_text("payload", encoding="utf-8")
            (root / "TonantzintlaDark.colors").symlink_to(victim)

            with self.assertRaises(RuntimeError):
                helper.install_file(root / "source", root / "TonantzintlaDark.colors")

            self.assertEqual(victim.read_text(encoding="utf-8"), "untouched")


class PlasmaWidgetRegressionTests(unittest.TestCase):
    def widget_sources(self) -> dict[str, str]:
        return {
            path.parts[-4]: path.read_text(encoding="utf-8")
            for path in sorted((PLASMA / "plasmoids").glob("*/contents/ui/main.qml"))
        }

    def test_no_widget_runs_shell_commands(self):
        sources = self.widget_sources()
        self.assertEqual(len(sources), 5)
        for name, source in sources.items():
            self.assertNotIn('engine: "executable"', source, name)
            self.assertNotIn("plasma5support", source, name)

    def test_album_art_only_loads_ordinary_image_locations(self):
        media = self.widget_sources()["org.tonantzintla.media"]
        self.assertIn("function safeArtUrl(url)", media)
        self.assertNotIn('(root.player.artUrl || "")', media)
        self.assertEqual(media.count("root.safeArtUrl(root.player.artUrl)"), 2)

    def test_window_borders_stay_hairline_and_light_mode_gets_light_title_bars(self):
        defaults = (PLASMA / "look-and-feel/org.tonantzintla.desktop/contents/defaults").read_text(encoding="utf-8")
        self.assertIn("BorderSize=Tiny", defaults)
        self.assertIn("BorderSizeAuto=false", defaults)
        dark = (PLASMA / "aurorae/themes/Tonantzintla/decoration.svg").read_text(encoding="utf-8")
        light = (PLASMA / "aurorae/themes/TonantzintlaLight/decoration.svg").read_text(encoding="utf-8")
        self.assertIn('fill="#16161d"', dark)
        self.assertIn('fill="#eeedf5"', light)
        self.assertNotIn('fill="#16161d"', light)

    def test_fonts_fall_back_to_a_fixed_width_family(self):
        for name, source in self.widget_sources().items():
            self.assertNotIn('font.family: "JetBrains Mono"', source, name)


if __name__ == "__main__":
    unittest.main()
