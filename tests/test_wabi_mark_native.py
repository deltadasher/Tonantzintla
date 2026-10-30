"""The project mark's event horizon stays black across shell palette changes."""
import json,os,shutil,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class WabiMarkNativeTests(unittest.TestCase):
 @unittest.skipUnless(shutil.which('qs'),'Quickshell unavailable')
 def test_real_launcher_and_dock_keep_black_horizon(self):
  with tempfile.TemporaryDirectory(prefix='wabi-mark-') as directory:
   home=Path(directory);(home/'tonantzintla').mkdir()
   (home/'tonantzintla/settings.json').write_text(json.dumps(dict(motion=False,adaptivePalette=False,clipboardPaused=True,wallpaperPath='')))
   env=dict(os.environ,HOME=directory,XDG_CONFIG_HOME=directory,XDG_CACHE_HOME=directory,XDG_STATE_HOME=directory,XDG_RUNTIME_DIR=directory,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',LOGO_CAPTURE=str(home/'logo'))
   for name in ['WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(name,None)
   with tempfile.NamedTemporaryFile('w',suffix='.qml',dir=ROOT/'src/quickshell') as harness:
    harness.write((ROOT/'tests/theme-modes/logo.qml').read_text());harness.flush()
    p=subprocess.run(['qs','-p',harness.name,'--no-color'],env=env,capture_output=True,text=True,timeout=8)
   out=p.stdout+p.stderr
   self.assertEqual(p.returncode,0,out);self.assertIn('LOGO COMPLETE 0 failures',out)
   for error in ['TypeError','ReferenceError','Cannot assign','Unable to assign','Failed to load configuration']:self.assertNotIn(error,out)
   for mode in ['dark','light']:self.assertTrue((home/f'logo-{mode}.png').exists())
