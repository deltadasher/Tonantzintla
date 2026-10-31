"""Identity choices agree across the shell and the login-theme exporter."""
import importlib.util
import json
import random
import subprocess
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT/'src/libexec'/f'{name}.py')
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

class IdentityExportTests(unittest.TestCase):
    def test_shell_and_greeter_match_for_registered_and_neighboring_colors(self):
        model = module('theme-identity')
        colors = [mark['color'] for mark in model.identities()]
        rng = random.Random(314)
        colors += [f'#{rng.randrange(0x1000000):06x}' for _ in range(50)]
        script = r'''const fs=require('fs'),vm=require('vm');const data={};vm.createContext(data);
vm.runInContext(fs.readFileSync('src/quickshell/components/ThemeIdentities.js','utf8'),data);
const model={Data:data};vm.createContext(model);
vm.runInContext(fs.readFileSync('src/quickshell/components/ThemeIdentity.js','utf8').replace(/^\.(pragma|import).*$/gm,''),model);
console.log(JSON.stringify(JSON.parse(process.argv[1]).map(color=>model.match(color).id)));'''
        result = subprocess.run(['node','-e',script,json.dumps(colors)],cwd=ROOT,text=True,capture_output=True,check=True)
        self.assertEqual(json.loads(result.stdout), [model.match(color)['id'] for color in colors])

    def test_export_contains_safe_identity_fixed_color_and_selected_mode(self):
        exporter = module('umbra-greeter-palette')
        for mark in exporter.identity.identities():
            content = exporter.render({},dict(themeIdentity=mark['id'],themeMode='auto',motion=False))
            self.assertIn('themeIdentity='+mark['id'],content)
            self.assertIn('identityColor='+mark['color'],content)
            self.assertIn('themeMode=dark',content)
            self.assertIn('lockMode=dark',content)
            self.assertIn('motion=false',content)
        content=exporter.render({},dict(themeIdentity='../../bad\nextra=yes',themeMode='dark'))
        self.assertIn('themeIdentity=wabi-sabi',content)
        self.assertNotIn('extra=',content)
        self.assertEqual(exporter.material_color({'ok':True,'palette':{'colors':{'primary':{'dark':{'color':'#fff\nextra=yes'}}}}},'primary','#123456'),'#123456')

    def test_manual_selection_and_explicit_mode_win_without_changing_settings(self):
        model=module('theme-identity')
        settings=dict(themeIdentity='ink',paletteSeedColor='#ffffff',themeMode='auto')
        before=dict(settings)
        mark,mode=model.resolve(settings)
        self.assertEqual((mark['id'],mode),('ink','dark'))
        self.assertEqual(settings,before)
        settings['themeMode']='dark'
        self.assertEqual(model.resolve(settings)[1],'dark')
        settings.update(themeIdentity='auto',themeMode='auto',spectralColors={'accent':'#d11e40'})
        self.assertEqual(model.resolve(settings)[0]['id'],'ruby')

    def test_modes_stay_independent_for_every_logo_and_exact_color(self):
        exporter = module('umbra-greeter-palette')
        for mark in exporter.identity.identities():
            for seed, automatic in (('#101010', 'light'), ('#eeeeee', 'dark')):
                for choice in ('auto', 'light', 'dark'):
                    with self.subTest(mark=mark['id'], seed=seed, choice=choice):
                        values = dict(line.split('=', 1) for line in exporter.render({},
                            dict(themeIdentity=mark['id'], paletteSeedColor=seed,
                                 themeMode=choice)).splitlines() if '=' in line)
                        expected = automatic if choice == 'auto' else choice
                        self.assertEqual(values['themeMode'], expected)
                        self.assertEqual(values['lockMode'],
                            'dark' if mark['id']=='leaf' and choice=='auto' else expected)
                        self.assertEqual(values['themeIdentity'], mark['id'])

    def test_settings_gate_cached_identity_and_material_colors(self):
        exporter = module('umbra-greeter-palette')
        payload = dict(ok=True, source='/example.png', seed='', mode='light', palette={'colors': {
            'source_color': {'light': {'color': '#d11e40'}, 'dark': {'color': '#d11e40'}},
            'primary': {'light': {'color': '#123456'}, 'dark': {'color': '#abcdef'}},
            'surface_container_lowest': {'light': {'color': '#112233'}, 'dark': {'color': '#223344'}}}})
        settings = dict(themeIdentity='auto', themeMode='auto', adaptivePalette=False,
                        accentName='violet', wallpaperPath='/example.png', paletteSeedColor='', spectralColors={})
        def values(data=payload, preferences=settings):
            return dict(line.split('=', 1) for line in exporter.render(data, preferences).splitlines() if '=' in line)
        disabled = values()
        self.assertEqual((disabled['themeIdentity'], disabled['themeMode']), ('ringed-planet', 'dark'))
        self.assertEqual(disabled['voidColor'], '#080910')
        self.assertEqual(disabled['accent'], '#a99cff')
        # Settings defaults disable adaptation, even when the key is absent.
        missing = dict(settings); missing.pop('adaptivePalette')
        self.assertEqual(values(preferences=missing), disabled)
        enabled = dict(settings, adaptivePalette=True)
        self.assertEqual((values(preferences=enabled)['themeIdentity'], values(preferences=enabled)['themeMode']), ('ruby', 'light'))
        self.assertEqual(values(preferences=enabled)['accent'], '#123456')
        for stale in (dict(payload, source='/other.png'), dict(payload, seed='#ffffff')):
            self.assertEqual(values(stale, enabled), disabled)
        # An identity source may still be used when the cached material mode differs;
        # its material colors must not be applied until it matches the chosen mode.
        dark = values(preferences=dict(enabled, themeMode='dark'))
        self.assertEqual((dark['themeIdentity'], dark['themeMode'], dark['voidColor']), ('ruby', 'dark', '#080910'))
        for adaptive in (False, True):
            exact = values(preferences=dict(settings, adaptivePalette=adaptive, paletteSeedColor='#ffffff',
                           spectralColors={'accent': '#83dad9'}))
            self.assertEqual((exact['themeIdentity'], exact['themeMode'], exact['accent']), ('ice-cube', 'dark', '#83dad9'))
            manual = values(preferences=dict(settings, adaptivePalette=adaptive, themeIdentity='ink', themeMode='dark'))
            self.assertEqual((manual['themeIdentity'], manual['themeMode'], manual['identityColor']), ('ink', 'dark', '#000000'))
        # Preserve the helper's original palette-only API for callers without settings.
        self.assertEqual(values(preferences=None)['accent'], '#abcdef')

    def test_malformed_cache_and_settings_fall_back_without_injection_or_crash(self):
        exporter = module('umbra-greeter-palette')
        baseline = exporter.render({}, {})
        for payload in (None, [], 'bad', {'ok': True, 'palette': []},
                        {'ok': True, 'palette': {'colors': []}},
                        {'ok': True, 'palette': {'colors': {'primary': []}}},
                        {'ok': True, 'palette': {'colors': {'primary': {'dark': []}}}}):
            with self.subTest(payload=payload):
                self.assertEqual(exporter.render(payload, {}), baseline)
                self.assertEqual(exporter.render(payload), exporter.render({}))
        for settings in ([], 'bad', {'themeIdentity': []}, {'themeIdentity': {}},
                         {'themeIdentity':'auto', 'accentName': []}, {'spectralColors': []},
                         {'themeMode': []}, {'paletteSeedColor': {}}):
            with self.subTest(settings=settings):
                content = exporter.render({}, settings)
                self.assertIn('[General]', content)
                self.assertNotIn('extra=', content)

    def test_cli_ignores_invalid_utf8_cache_and_settings(self):
        import sys
        import tempfile
        with tempfile.TemporaryDirectory(prefix='identity-invalid-json-') as directory:
            folder = Path(directory)
            palette = folder/'palette.json'; settings = folder/'settings.json'
            palette.write_bytes(b'\xff'); settings.write_bytes(b'\xff')
            result = subprocess.run([sys.executable, str(ROOT/'src/libexec/umbra-greeter-palette.py'),
                                     '--palette', str(palette), '--settings', str(settings)],
                                    capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('themeIdentity=wabi-sabi', result.stdout)
        self.assertIn('themeMode=dark', result.stdout)
