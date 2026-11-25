"""Regression tests for Tonantzintla security hardening fixes."""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest
from unittest import mock

REPO = Path(__file__).resolve().parents[1]


def load_helper(name: str):
    path = REPO / "src/libexec" / name
    spec = importlib.util.spec_from_file_location(name.replace("-", "_").replace(".", "_"), path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


class SecurityHardeningTests(unittest.TestCase):
    def test_wallpaper_online_rejects_non_https_and_non_wikimedia_urls(self):
        online = load_helper("wallpaper-online.py")
        for bad in (
            "file:///etc/passwd",
            "http://upload.wikimedia.org/image.jpg",
            "https://127.0.0.1/secret.png",
            "https://169.254.169.254/latest/meta-data/",
            "https://evil.example.com/wall.jpg",
            "https://user:pass@upload.wikimedia.org/wall.jpg",
            "https://upload.wikimedia.org:8443/wall.jpg",
        ):
            with self.subTest(url=bad):
                with self.assertRaises(ValueError):
                    online.validate_remote_url(bad)

    def test_wallpaper_online_blocks_private_dns_resolution(self):
        online = load_helper("wallpaper-online.py")
        with mock.patch.object(
            online.socket,
            "getaddrinfo",
            return_value=[(2, 1, 6, "", ("127.0.0.1", 443))],
        ):
            with self.assertRaises(ValueError):
                online.validate_remote_url("https://upload.wikimedia.org/test.jpg")

    def test_blackhole_refuses_shell_injection_in_configured_commands(self):
        with tempfile.TemporaryDirectory(prefix="tona-sec-") as tmp:
            root = Path(tmp)
            marker = root / "pwned"
            settings = root / "settings.json"
            settings.write_text(
                json.dumps({"browser": f"true; touch {marker}"}),
                encoding="utf-8",
            )
            env = dict(os.environ, TONANTZINTLA_SETTINGS=str(settings))
            result = subprocess.run(
                [str(REPO / "bin/blackhole"), "browser"],
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(marker.exists(), "Shell metacharacter must not execute via sh -lc")

    def test_blackhole_config_writes_private_settings_permissions(self):
        with tempfile.TemporaryDirectory(prefix="tona-cfg-") as tmp:
            settings = Path(tmp) / "sub" / "settings.json"
            env = dict(os.environ, TONANTZINTLA_SETTINGS=str(settings))
            subprocess.run(
                [str(REPO / "bin/blackhole"), "config", "set", "accentName", "violet"],
                env=env,
                capture_output=True,
                text=True,
                check=True,
            )
            self.assertEqual(stat.S_IMODE(settings.stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE(settings.parent.stat().st_mode), 0o700)

    def test_niri_snapshot_sanitizes_traversal_label(self):
        ownership = load_helper("niri-ownership.py")
        with tempfile.TemporaryDirectory(prefix="tona-niri-") as tmp:
            root = Path(tmp)
            config = root / "config.kdl"
            config.write_text("spawn-at-startup \"blackhole\"\n", encoding="utf-8")
            with mock.patch.dict(os.environ, {"XDG_STATE_HOME": str(root / "state")}), \
                 mock.patch.object(ownership, "validate", return_value=(True, "ok")):
                state = ownership.load()
                result = ownership.snapshot(state, config, "../../escape")
                self.assertTrue(result["ok"])
                dest = Path(result["snapshot"]["path"]).resolve()
                snaps = (root / "state" / "tonantzintla" / "niri-ownership" / "snapshots").resolve()
                self.assertTrue(dest.is_relative_to(snaps))
                self.assertEqual(stat.S_IMODE(dest.stat().st_mode), 0o600)

    def test_clipboard_index_enforces_private_cache_permissions(self):
        with tempfile.TemporaryDirectory(prefix="tona-clip-") as tmp:
            cache_dir = Path(tmp) / "clipcache"
            fake_bin = Path(tmp) / "bin"
            fake_bin.mkdir()
            cliphist = fake_bin / "cliphist"
            cliphist.write_text(
                "#!/bin/sh\n"
                "if [ \"$1\" = list ]; then printf '1\\tsecret text\\n2\\t[[ binary data 4 bytes png ]]\\n';\n"
                "else printf 'secret-bytes'; fi\n",
                encoding="utf-8",
            )
            cliphist.chmod(0o755)
            env = dict(os.environ, PATH=f"{fake_bin}:{os.environ.get('PATH', '')}")
            result = subprocess.run(
                ["python3", str(REPO / "src/libexec/clipboard-index.py"), str(cache_dir)],
                env=env,
                capture_output=True,
                text=True,
                check=True,
            )
            rows = json.loads(result.stdout)
            self.assertEqual(len(rows), 2)
            self.assertEqual(stat.S_IMODE(cache_dir.stat().st_mode), 0o700)
            self.assertEqual(stat.S_IMODE((cache_dir / "sizes.json").stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE((cache_dir / "2.png").stat().st_mode), 0o600)

    def test_umbra_capabilities_rejects_dotdot_pam_profile(self):
        caps = load_helper("umbra-capabilities.py")
        with tempfile.TemporaryDirectory(prefix="tona-pam-") as tmp:
            root = Path(tmp)
            self.assertFalse(caps.profile_uses_fingerprint("..", root=root))
            self.assertFalse(caps.profile_uses_fingerprint(".hidden", root=root))
            self.assertFalse(caps.profile_uses_fingerprint("a..b", root=root))

    def test_lyrics_local_rejects_fifo(self):
        lyrics = load_helper("lyrics-state.py")
        with tempfile.TemporaryDirectory(prefix="tona-lrc-") as tmp:
            root = Path(tmp)
            track = root / "song.mp3"
            track.write_bytes(b"mp3")
            fifo = root / "song.lrc"
            os.mkfifo(fifo)
            self.assertIsNone(lyrics.local_lyrics(track.as_uri()))

    def test_inline_python_ignores_modules_planted_in_the_current_directory(self):
        with tempfile.TemporaryDirectory(prefix="tona-cwd-") as tmp:
            root = Path(tmp)
            config_home = root / "config"
            (config_home / "tonantzintla").mkdir(parents=True)
            (config_home / "tonantzintla/settings.json").write_text('{"accentName": "cyan"}', encoding="utf-8")
            hostile = root / "hostile"
            hostile.mkdir()
            for module in ("json", "shlex", "tempfile"):
                (hostile / f"{module}.py").write_text("raise SystemExit(99)\n", encoding="utf-8")
            env = dict(os.environ, XDG_CONFIG_HOME=str(config_home), HOME=str(root))

            result = subprocess.run(
                [str(REPO / "bin/blackhole"), "config", "get", "accentName"],
                cwd=hostile, env=env, capture_output=True, text=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "cyan")
        snipping = (REPO / "src/libexec/snipping-tool").read_text(encoding="utf-8")
        self.assertNotIn("python3 -c", snipping)

    def test_weather_and_lyrics_redirects_cannot_leave_their_service(self):
        import urllib.error
        import urllib.request

        weather = load_helper("weather-state.py")
        lyrics = load_helper("lyrics-state.py")
        weather_request = urllib.request.Request("https://api.open-meteo.com/v1/forecast")
        lyrics_request = urllib.request.Request("https://lrclib.net/api/get")
        for target in ("http://127.0.0.1:8080/", "https://169.254.169.254/latest/", "http://api.open-meteo.com/", "ftp://lrclib.net/x"):
            with self.assertRaises(ValueError):
                weather.AllowlistedRedirectHandler().redirect_request(weather_request, None, 302, "Found", {}, target)
            with self.assertRaises(urllib.error.URLError):
                lyrics.SameHostRedirectHandler().redirect_request(lyrics_request, None, 302, "Found", {}, target)
        self.assertIsNotNone(weather.AllowlistedRedirectHandler().redirect_request(
            weather_request, None, 302, "Found", {}, "https://geocoding-api.open-meteo.com/v1/search"))
        self.assertIsNotNone(lyrics.SameHostRedirectHandler().redirect_request(
            lyrics_request, None, 302, "Found", {}, "/api/get/2"))

    def test_player_metadata_cannot_be_read_as_helper_options(self):
        lyrics_service = (REPO / "src/quickshell/services/Lyrics.qml").read_text(encoding="utf-8")
        self.assertIn('"--title=" + Media.title', lyrics_service)
        self.assertNotIn('"--title", Media.title', lyrics_service)
        online = subprocess.run(
            ["python3", str(REPO / "src/libexec/wallpaper-online.py"), "search", "--help"],
            capture_output=True, text=True,
        )
        self.assertEqual(online.returncode, 0)
        environment = (REPO / "src/quickshell/services/Environment.qml").read_text(encoding="utf-8")
        self.assertIn('"search", "--", cleaned', environment)

    def test_wallpaper_apply_has_no_predictable_tmp_logs(self):
        source = (REPO / "src/libexec/wallpaper-apply").read_text(encoding="utf-8")
        self.assertNotIn("/tmp/tonantzintla-", source)


if __name__ == "__main__":
    unittest.main()
