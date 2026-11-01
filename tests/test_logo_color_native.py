"""Render actual logos through two real Matugen updates, overrides and reset."""
import json, os, shutil, subprocess, tempfile, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

class LogoColorNativeTests(unittest.TestCase):
 @unittest.skipUnless(shutil.which('qs') and shutil.which('matugen'), 'Quickshell and Matugen required')
 def test_matugen_colors_pixels_preserves_black_transparency_and_originals(self):
  from PIL import Image
  names=['ruby','seashell','fire','wabi-sabi','sun','leaf','ice-cube','water-droplet','ringed-planet','night-sky','snowflake','moon','cloud','ink']
  with tempfile.TemporaryDirectory(prefix='logo-colors-') as tmp:
   folder=Path(tmp);(folder/'tonantzintla').mkdir()
   config=folder/'tonantzintla/settings.json'
   config.write_text(json.dumps(dict(motion=False,adaptivePalette=False,clipboardPaused=True,wallpaperPath='',themeIdentity='leaf',themeMode='dark',paletteSeedColor='',spectralColors={},logoColorMode='original')))
   env=dict(os.environ,HOME=tmp,XDG_CONFIG_HOME=tmp,XDG_CACHE_HOME=tmp,XDG_DATA_HOME=tmp,XDG_STATE_HOME=tmp,XDG_RUNTIME_DIR=tmp,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
   for key in ('WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):env.pop(key,None)
   qml='''import QtQuick
import "."
import "components"
Window {
 id:win; width:840; height:80; visible:true
 property int step:0
 property bool capturing:false
 property var results:[]
 property var colors:[]
 Row { id:row; width:840; height:60
  Repeater { id:marks; model:NAMES
   Item { required property string modelData; width:60;height:60
    ThemeMark { id:mark; anchors.centerIn:parent;width:44;height:44;identity:parent.modelData }
    property alias icon:mark
   }
  }
 }
 function check(ok,msg) { if(!ok){console.error("LOGO_FAIL",msg);Qt.exit(1);} }
 function capture() {
  capturing=true;
  check(Settings.themeIdentity==="leaf" && Settings.themeMode==="dark","logo color must not select identity or mode");
  if(step>=1&&step<=4) {
   for(let i=0;i<marks.count;i++)check(String(marks.itemAt(i).icon.artworkSource).indexOf("data:image/svg+xml")===0,"colored SVG ready "+i);
  }
  colors.push(String(Theme.accent));
  row.grabToImage(function(result){
   result.saveToFile("OUTPUT/"+step+".png");
   step++;
   if(step===1){Settings.logoColorMode="theme";AdaptivePalette.setSeed("#112233");}
   else if(step===2)AdaptivePalette.setSeed("#d11e40");
   else if(step===3)Settings.spectralColors=({accent:"#ffffff"});
   else if(step===4)Settings.spectralColors=({accent:"#010101"});
   else if(step===5)Settings.logoColorMode="original";
   else {Settings.logoColorMode="theme";console.log("LOGO_COLORS",JSON.stringify(colors));finish.start();return;}
   settle.restart();
  });
 }
 Timer {interval:50;running:true;repeat:true;onTriggered:{if(Settings.persistenceReady){stop();settle.start();}}}
 Timer {id:settle;interval:220;onTriggered:{
  if(AdaptivePalette.busy || ((win.step===1||win.step===2)&&(!Theme.adaptive||AdaptivePalette.appliedSeed!==(win.step===1?"#112233":"#d11e40")))) {restart();return;}
  if(win.step===1||win.step===2)win.check(String(Theme.accent)===String(AdaptivePalette.accent),"actual Matugen accent reaches theme");
  win.capture();
 }}
 Timer{id:finish;interval:1200;onTriggered:Qt.quit()}
 Timer{interval:18000;running:true;onTriggered:{console.error("LOGO_FAIL timeout",AdaptivePalette.error);Qt.exit(2);}}
}
'''.replace('NAMES',json.dumps(names)).replace('OUTPUT',tmp)
   with tempfile.NamedTemporaryFile('w',suffix='.qml',dir=ROOT/'src/quickshell') as f:
    f.write(qml);f.flush();p=subprocess.run(['qs','-p',f.name,'--no-color'],env=env,capture_output=True,text=True,timeout=22)
   log=p.stdout+p.stderr
   self.assertEqual(p.returncode,0,log)
   for error in ['LOGO_FAIL','TypeError','ReferenceError','Unable to assign','Binding loop','Failed to load configuration','Cannot open:']:self.assertNotIn(error,log)
   colors=json.loads(next(line.split('LOGO_COLORS ',1)[1] for line in log.splitlines() if 'LOGO_COLORS ' in line))
   self.assertNotEqual(colors[1],colors[2])
   self.assertEqual(colors[3:5],['#ffffff','#010101'])
   imgs=[Image.open(folder/f'{i}.png').convert('RGBA') for i in range(6)]
   self.assertEqual(imgs[0].tobytes(),imgs[5].tobytes(),'Original restores the exact approved artwork')
   for step in range(1,5):
    rgb=tuple(bytes.fromhex(colors[step][1:]))
    for i,name in enumerate(names):
     with self.subTest(step=step,identity=name):
      tile=imgs[step].crop((i*60,0,(i+1)*60,60));pixels=list(tile.getdata())
      self.assertGreater(sum(1 for p in pixels if p[:3]==rgb and p[3]>250),15,'Actual pixels must use the selected accent')
      self.assertEqual(tile.getpixel((0,0))[3],0,'No square backing')
      if step==3 and name in ('fire','ink','ringed-planet'):
       self.assertGreater(sum(1 for p in pixels if p[3]>250 and p[:3] not in ((255,255,255),(0,0,0))),15,'Secondary shapes survive a white accent')
      if name=='wabi-sabi':self.assertGreater(sum(1 for p in pixels if p[:3]==(0,0,0) and p[3]>250),30,'Black horizon remains black')
   saved=json.loads(config.read_text());self.assertEqual(saved['logoColorMode'],'theme')
   self.assertEqual(saved['themeIdentity'],'leaf');self.assertEqual(saved['themeMode'],'dark')
   if os.environ.get('LOGO_REVIEW_DIR'):
    out=Path(os.environ['LOGO_REVIEW_DIR']);out.mkdir(parents=True,exist_ok=True)
    for i,img in enumerate(imgs):img.save(out/f'row-{i}.png')
    (out/'colors.json').write_text(json.dumps(colors));(out/'native.log').write_text(log)
