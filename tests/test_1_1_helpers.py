from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from test_wallpaper_helpers import load_script


class SolarTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.weather = load_script("weather-state.py")

    def solar(self, date, lat=40.7, lon=-74.0, zone="America/New_York", rise="", setting=""):
        return self.weather.solar_day(date, lat, lon, zone, -18000, rise, setting)

    def test_dst_days_have_real_elapsed_duration(self):
        self.assertEqual(self.solar("2026-03-08")["end"] - self.solar("2026-03-08")["start"], 23 * 3600)
        self.assertEqual(self.solar("2026-11-01")["end"] - self.solar("2026-11-01")["start"], 25 * 3600)

    def test_provider_times_and_estimated_twilight_are_distinct(self):
        day = self.solar("2026-06-21", rise="2026-06-21T05:25", setting="2026-06-21T20:30")
        self.assertEqual(day["sunrise"]["time"], "05:25")
        self.assertFalse(day["sunrise"]["estimated"])
        self.assertTrue(day["dawn"]["estimated"])
        events = [day[key]["epoch"] for key in ("dawn", "sunrise", "noon", "sunset", "dusk")]
        self.assertEqual(events, sorted(events))

    def test_polar_conditions_do_not_invent_sunrise(self):
        for date, state in (("2026-06-21", "polar-day"), ("2026-12-21", "polar-night")):
            day = self.solar(date, 78.2, 15.6, "Arctic/Longyearbyen")
            self.assertEqual(day["state"], state)
            self.assertIsNone(day["sunrise"])
            self.assertIsNone(day["sunset"])

    def test_missing_provider_events_stay_missing(self):
        day = self.solar("2026-09-04")
        self.assertIsNone(day["sunrise"])
        self.assertIsNone(day["sunset"])


class AudioRoutingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.audio = load_script("audio-route.py")

    def test_resolves_serials_to_pulse_indices(self):
        replies = [json.dumps([{"index": 7, "sink": 2, "properties": {"object.serial": "101"}}]),
                   json.dumps([{"index": 9, "name": "headphones", "properties": {"object.serial": "202"}}]), ""]
        with mock.patch.object(self.audio, "run", side_effect=replies) as run:
            self.audio.move_stream("101", "202")
        self.assertEqual(run.call_args.args[0], ["move-sink-input", "7", "headphones"])

    def test_stale_serial_does_not_move_another_stream(self):
        with mock.patch.object(self.audio, "run", return_value="[]") as run:
            with self.assertRaises(ValueError):
                self.audio.move_stream("101", "202")
        self.assertEqual(run.call_count, 1)

    def test_invalid_serial_never_calls_audio_server(self):
        with mock.patch.object(self.audio, "run") as run:
            with self.assertRaises(ValueError):
                self.audio.move_stream("not-a-node", "202")
        run.assert_not_called()


class ParallaxImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.library = load_script("wallpaper-library.py")

    def test_import_preserves_source_and_existing_names(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "sky.png"
            source.write_bytes(b"original")
            with mock.patch.object(self.library, "library_home", return_value=root / "library"), \
                 mock.patch.object(self.library, "validate_import"):
                first = self.library.import_files([source.as_uri()])
                second = self.library.import_files([str(source)])
            self.assertTrue(first["ok"] and second["ok"])
            self.assertNotEqual(first["imported"], second["imported"])
            self.assertEqual(source.read_bytes(), b"original")
            self.assertEqual(Path(first["imported"][0]).read_bytes(), b"original")

    def test_remote_paths_rejected(self):
        for path in ("https://example.com/a.png", "file://server/a.png", "relative.png"):
            with self.assertRaises(ValueError):
                self.library.local_path(path)

    def test_invalid_import_copies_nothing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "fake.png"
            source.write_text("not an image")
            with mock.patch.object(self.library, "library_home", return_value=root / "library"):
                result = self.library.import_files([str(source)])
            self.assertFalse(result["ok"])
            self.assertEqual(result["imported"], [])
            self.assertFalse((root / "library").exists())

    def test_favorites_persist_and_malformed_state_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            image = root / "sky.png"
            image.write_bytes(b"image")
            state = root / "state.json"
            with mock.patch.object(self.library, "state_file", return_value=state):
                self.library.set_favorite(str(image), True)
                self.assertIn(str(image), self.library.read_favorites())
                self.library.set_favorite(str(image), False)
                self.assertEqual(self.library.read_favorites(), set())
                state.write_text("broken")
                with self.assertRaises(ValueError):
                    self.library.set_favorite(str(image), True)
                self.assertEqual(state.read_text(), "broken")
