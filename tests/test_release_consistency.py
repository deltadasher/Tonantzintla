"""One version, one place: everything that states the release must match VERSION."""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / "VERSION").read_text(encoding="utf-8").strip()


class ReleaseConsistencyTests(unittest.TestCase):
    def test_shell_fallback_version_matches_version_file(self):
        environment = (ROOT / "src/quickshell/services/Environment.qml").read_text(encoding="utf-8")
        self.assertIn(f'property string version: "{VERSION}"', environment)
        # The running shell reads the same file `blackhole version` prints.
        self.assertIn('path: Quickshell.shellDir + "/../../VERSION"', environment)

    def test_public_surfaces_name_the_same_release(self):
        self.assertIn(f"## Tonantzintla {VERSION}", (ROOT / "README.md").read_text(encoding="utf-8"))
        self.assertRegex((ROOT / "CHANGELOG.md").read_text(encoding="utf-8"),
                         rf"(?m)^## {re.escape(VERSION)} - \d{{4}}-\d{{2}}-\d{{2}}$")
        site = (ROOT / "docs/index.html").read_text(encoding="utf-8")
        self.assertIn(f"Install {VERSION} ", site)
        self.assertIn(f"Tonantzintla {VERSION} runs on", site)

    def test_installer_and_plasma_packages_carry_the_release(self):
        cargo = (ROOT / "install/Cargo.toml").read_text(encoding="utf-8")
        self.assertIn(f'version = "{VERSION}.0"', cargo)
        generator = (ROOT / "src/libexec/plasma-theme.py").read_text(encoding="utf-8")
        versions = set(re.findall(r'"Version": "([^"]+)"', generator))
        self.assertEqual(versions, {f"{VERSION}.0"})
        for metadata in sorted((ROOT / "plasma").rglob("metadata.json")):
            found = re.findall(r'"Version": "([^"]+)"', metadata.read_text(encoding="utf-8"))
            for value in found:
                self.assertEqual(value, f"{VERSION}.0", metadata)


class LifetimeRegressionTests(unittest.TestCase):
    def test_osd_window_outlives_its_exit_animation(self):
        shell = (ROOT / "src/quickshell/shell.qml").read_text(encoding="utf-8")
        self.assertIn("model: root.osdResident ? root.focusedScreens : []", shell)
        self.assertNotIn("model: Osd.visible ? root.focusedScreens : []", shell)
        self.assertIn("interval: Theme.motionFast + 48", shell)

    def test_closed_notifications_are_not_dismissed_through_a_dead_reference(self):
        service = (ROOT / "src/quickshell/services/Notifications.qml").read_text(encoding="utf-8")
        self.assertIn("notification && notification.id !== undefined ? notification : null", service)

    def test_supervisor_checks_ownership_before_spawn_not_every_pass(self):
        daemon = (ROOT / "src/libexec/session-daemon.py").read_text(encoding="utf-8")
        self.assertIn("if child is None or now - checked >= OWNERSHIP_RECHECK_SECONDS:", daemon)
        self.assertIn('stopping = stopping or action == "stop"', daemon)


if __name__ == "__main__":
    unittest.main()
