import unittest

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


if __name__ == "__main__":
    unittest.main()
