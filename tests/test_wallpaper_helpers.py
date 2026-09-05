from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import urllib.parse


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def load_script(name: str):
    path = PROJECT_ROOT / "src" / "libexec" / name
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class WallpaperValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.library = load_script("wallpaper-library.py")
        cls.online = load_script("wallpaper-online.py")

    def test_supported_signatures(self) -> None:
        self.assertTrue(self.online.valid_image_bytes(b"\xff\xd8\xff" + b"0" * 29))
        self.assertTrue(self.online.valid_image_bytes(b"\x89PNG\r\n\x1a\n" + b"0" * 24))
        self.assertTrue(self.online.valid_image_bytes(b"RIFF0000WEBP" + b"0" * 20))

    def test_html_disguised_as_image_is_rejected(self) -> None:
        self.assertFalse(self.online.valid_image_bytes(b"<!doctype html><html>error</html>"))
        with tempfile.TemporaryDirectory() as directory:
            fake_image = Path(directory) / "error.jpg"
            fake_image.write_text("<!doctype html><html>error</html>", encoding="utf-8")
            self.assertFalse(self.library.valid_image(fake_image))

    def test_bundled_wallpapers_have_valid_signatures(self) -> None:
        wallpaper_root = PROJECT_ROOT / "src" / "assets" / "wallpapers"
        for wallpaper in wallpaper_root.glob("*.png"):
            with self.subTest(wallpaper=wallpaper.name):
                self.assertTrue(self.library.valid_image(wallpaper))

    def test_color_buckets(self) -> None:
        self.assertEqual(self.library.color_bucket("#777777"), "Mono")
        self.assertEqual(self.library.color_bucket("#7040B0"), "Purple")
        self.assertEqual(self.library.color_bucket("#2088C0"), "Blue")

    def test_library_does_not_crawl_screenshots(self) -> None:
        bundled = Path("/tmp/tonantzintla-bundled")
        with mock.patch.object(self.library.Path, "home", return_value=Path("/home/tester")):
            roots = self.library.library_roots(bundled)
        self.assertIn(Path("/home/tester/Pictures/Wallpapers"), roots)
        self.assertNotIn(Path("/home/tester/Pictures"), roots)
        self.assertNotIn(Path("/home/tester/Pictures/Screenshots"), roots)

    def test_duplicate_wallpaper_roots_are_deduplicated(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            wallpaper = root / "nebula.png"
            wallpaper.write_bytes(b"\x89PNG\r\n\x1a\n" + b"0" * 24)
            self.assertEqual(
                [wallpaper.resolve()],
                list(self.library.iter_files([root, root])),
            )

    def test_unreadable_video_preview_does_not_abort_index(self) -> None:
        with (
            mock.patch.object(self.library.Path, "stat", side_effect=OSError),
            mock.patch.object(self.library.Path, "mkdir", side_effect=OSError),
        ):
            self.assertEqual("", self.library.video_preview(Path("wallpaper.mp4")))

    def test_online_downloads_use_the_tonantzintla_stills_folder(self) -> None:
        source = (PROJECT_ROOT / "src" / "libexec" / "wallpaper-online.py").read_text()
        self.assertIn('"Wallpapers" / "Tonantzintla" / "Stills"', source)

    def test_commons_results_preserve_license_metadata(self) -> None:
        payload = {
            "query": {
                "pages": [{
                    "title": "File:Deep field.jpg",
                    "imageinfo": [{
                        "width": 4096,
                        "height": 2160,
                        "mime": "image/jpeg",
                        "url": "https://upload.wikimedia.org/deep-field.jpg",
                        "thumburl": "https://upload.wikimedia.org/deep-field-thumb.jpg",
                        "descriptionurl": "https://commons.wikimedia.org/wiki/File:Deep_field.jpg",
                        "extmetadata": {
                            "LicenseShortName": {"value": "CC BY-SA 4.0"},
                            "Artist": {"value": "Example observatory"},
                        },
                    }],
                }]
            }
        }
        entries = self.online.parse_commons_results(payload)
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["source"], "Online")
        self.assertEqual(entries[0]["provider"], "Wikimedia Commons")
        self.assertEqual(entries[0]["license"], "CC BY-SA 4.0")
        self.assertEqual(entries[0]["name"], "Deep field.jpg")

    def test_commons_results_reject_small_images(self) -> None:
        payload = {
            "query": {
                "pages": [{
                    "title": "File:Small.png",
                    "imageinfo": [{
                        "width": 800,
                        "height": 600,
                        "mime": "image/png",
                        "url": "https://upload.wikimedia.org/small.png",
                    }],
                }]
            }
        }
        self.assertEqual(self.online.parse_commons_results(payload), [])

    def test_commons_search_uses_compact_previews(self) -> None:
        query = urllib.parse.parse_qs(
            urllib.parse.urlparse(self.online.commons_search_url("nebula")).query
        )
        self.assertEqual(query["iiurlwidth"], ["640"])

    def test_search_cache_avoids_repeating_a_query(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            preview = root / "preview.jpg"
            preview.write_bytes(b"preview")
            entries = [{"name": "Nebula", "preview": str(preview)}]
            with mock.patch.object(self.online, "cache_root", return_value=root):
                self.online.cache_search("  Nebula  ".strip(), entries)
                self.assertEqual(self.online.cached_search("nebula"), entries)


if __name__ == "__main__":
    unittest.main()
