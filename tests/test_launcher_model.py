"""Behavioral checks for the command palette's pure JavaScript model."""

from pathlib import Path
import json
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "src/quickshell/modules/ephemeris/widgets/catalog/LauncherModel.js"
NODE = shutil.which("node")


@unittest.skipUnless(NODE, "Node.js is needed to execute the QML JavaScript model")
class LauncherModelTests(unittest.TestCase):
    def evaluate(self, expression):
        program = MODEL.read_text().replace(".pragma library", "", 1)
        program += """
const installed = [
    {id: 'firefox.desktop', name: 'Firefox', command: 'firefox', comment: 'Web browser'},
    {id: 'terminal.desktop', name: 'Terminal', command: 'terminal', comment: 'Terminal emulator'},
    {id: 'files.desktop', name: 'Files', command: 'files', comment: 'File manager'}
];
const actions = surfaceCommands([
    {id: 'apps', title: 'Blackhole'},
    {id: 'walls', title: 'Parallax library'},
    {id: 'audio', title: 'Acoustic routing'}
]);
const entries = applications(installed).concat(actions);
"""
        program += "\nconsole.log(JSON.stringify(" + expression + "));"
        result = subprocess.run([NODE, "-e", program], capture_output=True, text=True, check=True)
        return json.loads(result.stdout)

    def test_discovery_order_does_not_move_existing_apps(self):
        result = self.evaluate("[applications(installed).map(e => e.id), applications(installed.slice().reverse()).map(e => e.id)]")
        self.assertEqual(result[0], result[1])

    def test_search_preserves_relative_order_and_selected_identity(self):
        result = self.evaluate("(() => { const before = filter(entries, '', 'apps', []); const after = filter(entries, 'fi', 'apps', []); return [before.filter(e => after.some(a => a.id === e.id)).map(e => e.id), after.map(e => e.id), selectedId(after, 'app:files.desktop')]; })()")
        self.assertEqual(result[0], result[1])
        self.assertEqual(result[2], "app:files.desktop")

    def test_missing_selection_recovers_without_stale_activation(self):
        result = self.evaluate("[selectedId(filter(entries, 'terminal', 'apps', []), 'app:files.desktop'), selectedId([], 'app:files.desktop'), moveSelection([], 'app:files.desktop', 1)]")
        self.assertEqual(result, ["app:terminal.desktop", "", ""])

    def test_command_prefix_overrides_app_category(self):
        result = self.evaluate("filter(entries, '> wallpaper', 'apps', []).map(e => e.id)")
        self.assertEqual(result, ["surface:walls"])

    def test_saved_apps_are_a_filter_not_a_sort(self):
        result = self.evaluate("[filter(entries, '', 'saved', ['files.desktop', 'firefox.desktop']).map(e => e.id), applications(installed).filter(e => e.appId !== 'terminal.desktop').map(e => e.id), filter(entries, '', 'saved', []).length]")
        self.assertEqual(result[0], result[1])
        self.assertEqual(result[2], 0)

    def test_arrows_wrap_and_survive_an_empty_model(self):
        result = self.evaluate("(() => { const first = entries[0].id; const last = entries[entries.length-1].id; return [moveSelection(entries, first, -1) === last, moveSelection(entries, last, 1) === first, moveSelection(entries, '', 1) === first]; })()")
        self.assertEqual(result, [True, True, True])

    def test_launch_targets_exclude_helpers_duplicates_and_empty_commands(self):
        result = self.evaluate("applications(installed.concat([installed[0], {id: 'about', name: 'About Xfce', command: 'about'}, {id: 'broken', name: 'Broken', command: ''}])).length")
        self.assertEqual(result, 3)

    def test_unavailable_action_remains_discoverable_but_is_not_default(self):
        result = self.evaluate("(() => { const commands = [{id: 'pause', name: 'Pause', kind: 'media', enabled: false}, {id: 'audio', name: 'Audio', kind: 'surface', enabled: true}]; return [filter(commands, '', 'actions', []).length, selectedId(commands, '')]; })()")
        self.assertEqual(result, [2, "audio"])

    def test_math_evaluation(self):
        result = self.evaluate("evaluateMath('42 * 2')")
        self.assertIsNotNone(result)
        self.assertEqual(result["result"], "84")
        self.assertEqual(result["kind"], "calc")

        complex_calc = self.evaluate("evaluateMath('(10 + 5) * 2 ^ 3')")
        self.assertIsNotNone(complex_calc)
        self.assertEqual(complex_calc["result"], "120")

    def test_astronomical_facts(self):
        result = self.evaluate("astronomicalFact('speed of light')")
        self.assertIsNotNone(result)
        self.assertIn("299,792,458", result["result"])
        self.assertEqual(result["kind"], "astro")

        parsec = self.evaluate("astronomicalFact('parsec')")
        self.assertIsNotNone(parsec)
        self.assertIn("3.0857", parsec["result"])
        self.assertIn("3.26", parsec["detail"])

    def test_terminal_command(self):
        result = self.evaluate("terminalCommand('! btop')")
        self.assertIsNotNone(result)
        self.assertEqual(result["cmd"], "btop")
        self.assertEqual(result["kind"], "terminal_cmd")

        dollar_result = self.evaluate("terminalCommand('$ uname -a')")
        self.assertIsNotNone(dollar_result)
        self.assertEqual(dollar_result["cmd"], "uname -a")

    def test_special_entries_filter_precedence(self):
        result = self.evaluate("filter(entries, 'speed of light', 'all', []).map(e => e.kind)")
        self.assertIn("astro", result)
        self.assertEqual(result[0], "astro")

        calc_result = self.evaluate("filter(entries, '15 * 4', 'all', []).map(e => e.kind)")
        self.assertIn("calc", calc_result)
        self.assertEqual(calc_result[0], "calc")

    def test_calculator_disabled_flag(self):
        calc_on = self.evaluate("filter(entries, '15 * 4', 'all', [], true).map(e => e.kind)")
        self.assertIn("calc", calc_on)
        calc_off = self.evaluate("filter(entries, '15 * 4', 'all', [], false).map(e => e.kind)")
        self.assertNotIn("calc", calc_off)

    def test_scattered_letters_do_not_match_descriptions(self):
        self.assertFalse(self.evaluate("matches({name: 'Settings', detail: 'Safe tools edit audio mixer'}, 'steam')"))
        self.assertFalse(self.evaluate("matches({name: 'Configuration', detail: 'File integration renderer editor for online extensions'}, 'firefox')"))

    def test_exact_name_beats_prefix_and_metadata_noise(self):
        result = self.evaluate("filter([{id:'helper', name:'Steam Tools', kind:'app'}, {id:'noise', name:'Settings', kind:'app', detail:'Steam configuration'}, {id:'steam', name:'Steam', kind:'app'}], 'steam', 'all', []).map(e => e.id)")
        self.assertEqual(result, ['steam', 'helper'])

    def test_name_search_is_case_and_whitespace_insensitive(self):
        result = self.evaluate("filter([{id:'code', name:'Visual Studio Code', kind:'app'}, {id:'studio', name:'Studio', kind:'app'}], '  CODE   visual ', 'all', []).map(e => e.id)")
        self.assertEqual(result, ['code'])

    def test_metadata_remains_useful_when_no_name_matches(self):
        result = self.evaluate("filter(entries, 'web browser', 'apps', []).map(e => e.id)")
        self.assertEqual(result, ['app:firefox.desktop'])

    def test_short_queries_do_not_search_description_or_inject_constants(self):
        result = self.evaluate("filter([{id:'config', kind:'app', name:'Config'}, {id:'noise', kind:'app', name:'Tools', detail:'Configuration'}], 'c', 'all', []).map(e => e.id)")
        self.assertEqual(result, ['config'])

    def test_category_filter_applies_before_name_priority(self):
        result = self.evaluate("filter([{id:'app', appId:'app', kind:'app', name:'Browser'}, {id:'action', kind:'surface', name:'Open browser', keywords:'browser'}], '> browser', 'apps', []).map(e => e.id)")
        self.assertEqual(result, ['action'])

    def test_unrelated_query_returns_nothing(self):
        self.assertEqual(self.evaluate("filter(entries, 'zyxnotanapp', 'all', [])"), [])


if __name__ == "__main__":
    unittest.main()
