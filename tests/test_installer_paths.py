"""The installer must look for the shell where the shell actually lives."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ShellDetectionTests(unittest.TestCase):
    def test_update_probes_the_quickshell_project_directory(self) -> None:
        maintain = (ROOT / "install/src/maintain.rs").read_text()
        # Probing the runtime root finds no Quickshell instance, so update
        # reports the shell idle and leaves the running one on the old
        # revision. bin/blackhole probes src/quickshell; so must this.
        self.assertIn('install_root.join("src/quickshell")', maintain)
        self.assertNotIn('.arg(install_root)\n        .arg("list")', maintain)

    def test_the_cli_and_the_installer_agree_on_that_path(self) -> None:
        cli = (ROOT / "bin/blackhole").read_text()
        self.assertIn('shell_root="$project_root/src/quickshell"', cli)


if __name__ == "__main__":
    unittest.main()
