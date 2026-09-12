"""Exercise per-output, per-edge Aperture placement independently of QML."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("node"), "Node.js unavailable")
class BarPlacementTests(unittest.TestCase):
    def evaluate(self, expression: str):
        source = (ROOT / "src/quickshell/components/BarPlacement.js").read_text()
        source = source.replace(".pragma library", "", 1)
        source += '\nconst base = {start: ["launcher", "workspaces"], center: ["clock"], end: ["status", "controls"]};\n'
        result = subprocess.run(
            ["node", "-e", source + "\nconsole.log(JSON.stringify(" + expression + "));"],
            check=True, capture_output=True, text=True,
        )
        return json.loads(result.stdout)

    def test_one_island_can_move_to_an_independent_edge(self):
        raw = json.dumps({"DP-1": {"clock": {"edge": "left", "zone": "center", "order": 0}}})
        top = self.evaluate(f'layoutFor(base, "top", "top", {json.dumps(raw)}, "DP-1")')
        left = self.evaluate(f'layoutFor(base, "top", "left", {json.dumps(raw)}, "DP-1")')
        self.assertEqual(top, {
            "start": ["launcher", "workspaces"], "center": [], "end": ["status", "controls"]
        })
        self.assertEqual(left, {"start": [], "center": ["clock"], "end": []})

    def test_placement_is_scoped_to_the_output(self):
        raw = json.dumps({"DP-1": {"clock": {"edge": "left", "zone": "center", "order": 0}}})
        other = self.evaluate(f'layoutFor(base, "top", "top", {json.dumps(raw)}, "HDMI-A-1")')
        self.assertEqual(other["center"], ["clock"])

    def test_drop_order_is_stable_and_non_overlapping(self):
        placed = self.evaluate('place("", "DP-1", "clock", "left", "start", ["clock", "launcher"])')
        raw = json.dumps(placed)
        left = self.evaluate(f'layoutFor(base, "top", "left", {json.dumps(raw)}, "DP-1")')
        self.assertEqual(left["start"], ["clock"])
        self.assertNotIn("clock", left["center"])

    def test_clear_restores_the_primary_edge(self):
        raw = json.dumps({"DP-1": {"clock": {"edge": "left", "zone": "center", "order": 0}}})
        cleared = self.evaluate(f'clear({json.dumps(raw)}, "DP-1", "clock")')
        restored = self.evaluate(
            f'layoutFor(base, "top", "top", {json.dumps(json.dumps(cleared))}, "DP-1")'
        )
        self.assertEqual(restored["center"], ["clock"])


if __name__ == "__main__":
    unittest.main()
