"""Exercise layout sanitization and moves independently of the desktop."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('node'), 'Node.js unavailable')
class BarLayoutTests(unittest.TestCase):
    def evaluate(self, expression):
        source = (ROOT / 'src/quickshell/components/BarLayout.js').read_text().replace('.pragma library', '', 1)
        source += '\nconst original = {start: ["launcher", "workspaces"], center: ["clock", "media"], end: ["controls"]};\n'
        result = subprocess.run(['node', '-e', source + '\nconsole.log(JSON.stringify(' + expression + '));'],
                                check=True, capture_output=True, text=True)
        return json.loads(result.stdout)

    def test_invalid_json_and_missing_zones_use_defaults(self):
        self.assertTrue(self.evaluate('JSON.stringify(normalize("broken", original)) === JSON.stringify(original)'))
        self.assertEqual(self.evaluate('normalize({center: []}, original)'),
                         {'start': ['launcher', 'workspaces'], 'center': [], 'end': ['controls']})

    def test_unknown_and_duplicate_islands_are_removed(self):
        self.assertEqual(self.evaluate('normalize({start: ["launcher", "launcher", "unknown"], center: ["launcher", "clock"], end: []}, original)'),
                         {'start': ['launcher'], 'center': ['clock'], 'end': []})

    def test_transfer_preserves_input_and_selected_identity(self):
        result = self.evaluate('(() => { const next = transfer(original, "center", "end", "clock", 0); return [next, original.center, locate(next, "clock")]; })()')
        self.assertEqual(result, [{'start': ['launcher', 'workspaces'], 'center': ['media'], 'end': ['clock', 'controls']},
                                  ['clock', 'media'], {'zone': 'end', 'index': 0}])

    def test_center_can_reorder(self):
        self.assertEqual(self.evaluate('transfer(original, "center", "center", "clock", 1).center'), ['media', 'clock'])

    def test_stale_and_invalid_source_cannot_duplicate(self):
        for zone in ('start', 'missing'):
            self.assertTrue(self.evaluate('JSON.stringify(transfer(original, ' + json.dumps(zone) + ', "end", "clock")) === JSON.stringify(original)'))

    def test_destination_index_is_clamped(self):
        self.assertEqual(self.evaluate('transfer(original, "center", "end", "clock", -9).end'), ['clock', 'controls'])
        self.assertEqual(self.evaluate('transfer(original, "center", "end", "clock", 99).end'), ['controls', 'clock'])

    def test_add_island_inserts_and_removes_from_other_zones(self):
        # Adding an island not present in original
        res = self.evaluate('addIsland(original, "start", "tray", 1)')
        self.assertEqual(res['start'], ['launcher', 'tray', 'workspaces'])
        # Adding an island already present moves it to the target zone
        res2 = self.evaluate('addIsland(original, "start", "clock", 0)')
        self.assertEqual(res2['start'], ['clock', 'launcher', 'workspaces'])
        self.assertEqual(res2['center'], ['media'])

    def test_remove_island_deletes_specified_island(self):
        res = self.evaluate('removeIsland(original, "clock")')
        self.assertEqual(res['center'], ['media'])
        self.assertNotIn('clock', res['start'])
        self.assertNotIn('clock', res['center'])
        self.assertNotIn('clock', res['end'])
