"""Exercise the real identity controls and durable settings without locking."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]

class IdentityNativeTests(unittest.TestCase):
 @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
 def test_manual_auto_keyboard_and_persistence(self):
  with tempfile.TemporaryDirectory(prefix='identity-controls-') as tmp:
   home=Path(tmp);(home/'tonantzintla').mkdir()
   config=home/'tonantzintla/settings.json'
   config.write_text(json.dumps(dict(motion=False,adaptivePalette=False,clipboardPaused=True,wallpaperPath='',themeIdentity='wabi-sabi',themeMode='auto',paletteSeedColor='#d11e40')))
   env=dict(os.environ,HOME=tmp,XDG_CONFIG_HOME=tmp,XDG_CACHE_HOME=tmp,XDG_STATE_HOME=tmp,XDG_RUNTIME_DIR=tmp,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
   for key in ('WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):env.pop(key,None)
   with tempfile.NamedTemporaryFile('w',suffix='.qml',prefix='identity-controls-',dir=ROOT/'src/quickshell') as f:
    f.write('''import QtQuick
import QtTest
import Quickshell
import "."
import "components"
Window {
 id:w;width:440;height:760;visible:true
 property int step:0
 property int failures:0
 function check(ok,message){if(!ok){failures++;console.error("IDENTITY_FAIL",message);}}
 function find(item,name){
  if(item.Accessible && item.Accessible.name===name)return item;
  for(const child of item.children||[]){const result=find(child,name);if(result)return result;}return null;
 }
 function press(name){const item=find(picker,name);check(!!item,name);if(item){item.forceActiveFocus();events.keyClick(Qt.Key_Space,Qt.NoModifier,-1);}}
 TestEvent{id:events}
 ThemeIdentityPicker{id:picker;width:parent.width}
 ThemeMark{id:mark;visible:false}
 Timer{interval:160;running:true;repeat:true;onTriggered:{
  if(!Settings.persistenceReady)return;
  if(w.step===0){w.requestActivate();w.press("Leaf, #467B50");}
  else if(w.step===1){
   w.check(Settings.themeIdentity==="leaf" && Theme.identity.id==="leaf","manual choice applies");
   w.check(Settings.paletteSeedColor==="#d11e40","choosing a logo does not change Matugen seed");
   w.check(Theme.isLight,"dark leaf gets a light background");Settings.themeMode="dark";
  } else if(w.step===2){
   w.check(!Theme.isLight,"explicit appearance overrides identity default");
   Settings.themeMode="auto";w.press("Logo selection: Follow theme color");
  } else if(w.step===3){
   w.check(Settings.themeIdentity==="auto" && Theme.identity.id==="ruby","auto uses exact seed");
   Settings.spectralColors=({accent:"#83dad9"});
  } else if(w.step===4){
   w.check(Theme.identity.id==="ice-cube" && !Theme.isLight,"exact action color wins");
   w.press("Ink, #000000");
  } else if(w.step===5){
   w.check(Theme.identity.id==="ink" && mark.mark.color==="#000000" && Theme.isLight,"manual ink remains black with light mode");
   w.check(Settings.spectralColors.accent==="#83dad9","manual logo preserves separate exact accent");
  } else if(w.step>8 && !Settings.saveTimer.running && !Settings.preferencesLoading){
   console.log("IDENTITY_COMPLETE",w.failures);Qt.exit(w.failures?1:0);stop();
  }
  w.step++;
 }}
 Timer{interval:8000;running:true;onTriggered:Qt.exit(2)}
}
''');f.flush()
    result=subprocess.run(['qs','-p',f.name,'--no-color'],env=env,capture_output=True,text=True,timeout=12)
   log=result.stdout+result.stderr
   self.assertEqual(result.returncode,0,log)
   self.assertIn('IDENTITY_COMPLETE 0',log)
   for error in ['TypeError','ReferenceError','Unable to assign','Binding loop','Failed to load configuration']:
    self.assertNotIn(error,log)
   saved=json.loads(config.read_text())
   self.assertEqual(saved['themeIdentity'],'ink')
   self.assertEqual(saved['paletteSeedColor'],'#d11e40')
   self.assertEqual(saved['spectralColors']['accent'],'#83dad9')
