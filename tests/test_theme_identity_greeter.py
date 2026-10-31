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
            self.assertIn('themeMode='+('light' if mark['light'] else 'dark'),content)
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
        self.assertEqual((mark['id'],mode),('ink','light'))
        self.assertEqual(settings,before)
        settings['themeMode']='dark'
        self.assertEqual(model.resolve(settings)[1],'dark')
        settings.update(themeIdentity='auto',themeMode='auto',spectralColors={'accent':'#d11e40'})
        self.assertEqual(model.resolve(settings)[0]['id'],'ruby')
