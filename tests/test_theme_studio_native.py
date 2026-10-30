import json, os, shutil, subprocess, tempfile, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class ThemeStudioNativeTests(unittest.TestCase):
 @unittest.skipUnless(shutil.which('qs'),'Quickshell unavailable')
 def test_real_controls_materials_modes_and_persistence(self):
  with tempfile.TemporaryDirectory(prefix='theme-studio-') as directory:
   home=Path(directory);(home/'tonantzintla').mkdir()
   config=home/'tonantzintla/settings.json'
   config.write_text(json.dumps({'motion':False,'adaptivePalette':False,'clipboardPaused':True,'wallpaperPath':''}))
   env=dict(os.environ,HOME=directory,XDG_CONFIG_HOME=directory,XDG_CACHE_HOME=directory,XDG_STATE_HOME=directory,XDG_RUNTIME_DIR=directory,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
   for key in ('WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):env.pop(key,None)
   source=(ROOT/'tests/theme-modes/studio.qml').read_text().replace('../../src/quickshell','.')
   with tempfile.NamedTemporaryFile('w',suffix='.qml',prefix='studio-test-',dir=ROOT/'src/quickshell') as harness:
    harness.write(source);harness.flush()
    result=subprocess.run(['qs','-p',harness.name,'--no-color'],env=env,capture_output=True,text=True,timeout=15)
   output=result.stdout+result.stderr
   self.assertEqual(result.returncode,0,output)
   self.assertIn('STUDIO COMPLETE 0 failures',output)
   for error in ('TypeError','ReferenceError','Unable to assign','Failed to load configuration','Binding loop'):self.assertNotIn(error,output)
   saved=json.loads(config.read_text())
   self.assertEqual(saved['themeMode'],'auto');self.assertEqual(saved['spectralColors']['accent'],'#010101')
   self.assertEqual(saved['barWorkspaceStyle'],'track');self.assertEqual(saved['barClockFace'],'matrix')
   self.assertEqual(saved['barCornerRadius'],0);self.assertEqual(saved['panelMaterial'],'frosted')
