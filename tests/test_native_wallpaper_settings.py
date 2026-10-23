import json, os
from pathlib import Path
import shutil, subprocess, tempfile, unittest
ROOT=Path(__file__).resolve().parents[1]
class NativeWallpaperSettingsTests(unittest.TestCase):
 @unittest.skipUnless(shutil.which('qs'),'Quickshell unavailable')
 def test_actual_short_options_keyboard_and_persistent_renderer_assignments(self):
  source=(ROOT/'tests/instruments/native-wallpaper-settings.qml').read_text().replace('../../src/quickshell/', '').replace('"../../src/quickshell"','"."')
  with tempfile.TemporaryDirectory(prefix='native-wall-ui-') as directory:
   root=Path(directory);(root/'tonantzintla').mkdir();(root/'bin').mkdir()
   (root/'tonantzintla/settings.json').write_text(json.dumps({'adaptivePalette':False,'motion':False,'clipboardPaused':True}))
   (root/'bin/sh').write_text('#!/bin/sh\nexit 0\n');(root/'bin/sh').chmod(0o755)
   screenshot=root/'options.png'
   env=dict(os.environ,HOME=directory,XDG_CONFIG_HOME=directory,XDG_CACHE_HOME=directory,XDG_STATE_HOME=directory,XDG_RUNTIME_DIR=directory,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',NATIVE_UI_SCREENSHOT=str(screenshot),PATH=str(root/'bin')+':'+os.environ['PATH'])
   for key in ('WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):env.pop(key,None)
   with tempfile.NamedTemporaryFile(mode='w',prefix='test-native-wall-ui-',suffix='.qml',dir=ROOT/'src/quickshell') as harness:
    harness.write(source);harness.flush();result=subprocess.run(['qs','-p',harness.name,'--no-color'],env=env,capture_output=True,text=True,timeout=10)
   output=result.stdout+result.stderr
   self.assertEqual(result.returncode,0,output);self.assertIn('NATIVE UI COMPLETE 0',output)
   for bad in ('NATIVE UI FAIL','ReferenceError','TypeError','Binding loop','Unable to assign','Failed to load configuration'):self.assertNotIn(bad,output)
   self.assertGreater(screenshot.stat().st_size,1000)
   if os.environ.get('NATIVE_UI_CAPTURE'):shutil.copyfile(screenshot,os.environ['NATIVE_UI_CAPTURE'])
