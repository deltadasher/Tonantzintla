import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("memory_profile", Path(__file__).resolve().parents[1] / "tools/memory-profile.py")
profile = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profile)


class MemoryProfileTests(unittest.TestCase):
    def test_shared_memory_is_not_mistaken_for_private_memory(self):
        result = profile.parse_rollup("Rss: 204800 kB\nPss: 102400 kB\nPrivate_Clean: 1024 kB\nPrivate_Dirty: 51200 kB\nSwapPss: 2048 kB\n")
        self.assertEqual(result["rss_bytes"], 204800 * 1024)
        self.assertEqual(result["rss_mib"], 200)
        self.assertEqual(result["pss_mib"], 100)
        self.assertEqual(result["private_mib"], 51)
        self.assertEqual(result["swap_pss_mib"], 2)

    def test_unavailable_measurement_is_not_zero(self):
        self.assertIsNone(profile.parse_rollup("Rss: 1024 kB\n")["pss_mib"])
        self.assertIsNone(profile.parse_rollup("")["private_mib"])
