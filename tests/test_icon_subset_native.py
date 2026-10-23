"""Pixel equality for the full source Unicode corpus through actual Theme."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]

class IconSubsetNativeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_source_glyphs_and_custom_fallback_are_pixel_identical(self):
        try:
            from PIL import Image,ImageChops
        except ImportError:
            self.skipTest('Pillow unavailable for native pixel comparison')
        source=Path('/usr/share/fonts/TTF/IosevkaNerdFont-Regular.ttf')
        if not source.exists():self.skipTest('Original font unavailable for matched comparison')
        points=set(range(32,127))|{0xf0001}
        for path in (ROOT/'src').rglob('*'):
            if path.suffix in ('.qml','.js','.py'):
                points.update(ord(c) for c in path.read_text() if ord(c)>127)
        fixture='''import QtQuick
import Quickshell
import "."
Window {
 id:root; width:800; height:1000; visible:true; color:"#080910"
 property bool configured:false
 Component.onCompleted: { Settings.fontIcon=Quickshell.env("ICON_FAMILY"); configured=true; }
 Loader { id:loader; anchors.centerIn:parent; active:root.configured
  sourceComponent: Flow { width:760; spacing:0
   Repeater { model:GLYPHS
    Text { required property int modelData; width:38; height:40
     text:String.fromCodePoint(modelData); color:"#eee9dc"; font.pixelSize:24
     font.family:Theme.iconFamily(text); font.weight:Font.Normal }
   }
  }
 }
 Timer { interval:500; running:true; onTriggered: {
  if(Theme.fontIcon!==Settings.fontIcon || Theme.iconFamily(String.fromCodePoint(0xf0001))!==Settings.fontIcon)
   console.error("SUBSET_FAILED configured fallback");
  if(Settings.fontIcon==="Iosevka Nerd Font" && (!Theme.iconFontReady || Theme.iconFamily("⚙")!=="Tonantzintla Symbols"))
   console.error("SUBSET_FAILED bundled resolver");
  loader.item.grabToImage(function(result) {
   result.saveToFile(Quickshell.env("ICON_CAPTURE"));console.log("SUBSET_COMPLETE");Qt.quit();
  });
 } }
}'''.replace('GLYPHS',json.dumps(sorted(points)))
        with tempfile.TemporaryDirectory(prefix='subset-pixels-') as directory:
            images=[]
            for index,family in enumerate(('Iosevka NF','Iosevka Nerd Font')):
                folder=Path(directory)/str(index);folder.mkdir()
                (folder/'tonantzintla').mkdir()
                (folder/'tonantzintla/settings.json').write_text(json.dumps({'motion':False,'adaptivePalette':False}))
                capture=folder/'glyphs.png'
                env=dict(os.environ,HOME=str(folder),XDG_CONFIG_HOME=str(folder),XDG_CACHE_HOME=str(folder),XDG_DATA_HOME=str(folder),XDG_STATE_HOME=str(folder),XDG_RUNTIME_DIR=str(folder),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent',ICON_FAMILY=family,ICON_CAPTURE=str(capture))
                for key in ('WAYLAND_DISPLAY','NIRI_SOCKET'):env.pop(key,None)
                with tempfile.NamedTemporaryFile(mode='w',prefix='test-subset-',suffix='.qml',dir=ROOT/'src/quickshell') as qml:
                    qml.write(fixture);qml.flush()
                    result=subprocess.run(['qs','-p',qml.name,'--no-color'],env=env,capture_output=True,text=True,timeout=10)
                output=result.stdout+result.stderr
                self.assertEqual(result.returncode,0,output)
                self.assertIn('SUBSET_COMPLETE',output)
                for error in ('SUBSET_FAILED','TypeError','ReferenceError','Unable to assign','Cannot load font'):self.assertNotIn(error,output)
                images.append(Image.open(capture).convert('RGB'))
            self.assertEqual(images[0].size,images[1].size)
            self.assertIsNone(ImageChops.difference(*images).getbbox(),'Bundled/fallback glyph pixels changed')
