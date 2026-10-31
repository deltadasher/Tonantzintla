import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib
ROOT=Path(__file__).resolve().parents[1]

def tiny_png(path):
    def chunk(kind,data): return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1,1,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b'\x00\x80\x30\xa0'))+chunk(b'IEND',b''))

class NativeModes(unittest.TestCase):
 def test_real_qml_async_mode_and_seed_lifetimes(self):
  for tree in ('src',):
   with self.subTest(tree=tree),tempfile.TemporaryDirectory(prefix='tona-modes-') as temp:
    base=Path(temp);src=ROOT/tree/'quickshell';(base/'services').mkdir();(base/'components').mkdir();(base/'bin').mkdir()
    for name in ('Theme.qml','AdaptivePalette.qml'): shutil.copyfile(src/name,base/name)
    for name in ('ThemeMode.js','SpectralPalette.js','IconFontGlyphs.js','ThemeIdentity.js','ThemeIdentities.js'):
     if (src/'components'/name).exists():shutil.copyfile(src/'components'/name,base/'components'/name)
    shutil.copyfile(src/'services/WallpaperPalettePreview.qml',base/'services/WallpaperPalettePreview.qml')
    shutil.copyfile(ROOT/'tests/theme-modes/native.qml',base/'native.qml')
    (base/'qmldir').write_text('singleton Settings 1.0 Settings.qml\nsingleton Theme 1.0 Theme.qml\nsingleton AdaptivePalette 1.0 AdaptivePalette.qml\n')
    (base/'services/qmldir').write_text('singleton Environment 1.0 Environment.qml\nWallpaperPalettePreview 1.0 WallpaperPalettePreview.qml\n')
    helper=ROOT/tree/'libexec/palette-state.py'
    (base/'services/Environment.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { function script(name) { return '+repr(str(helper))+'; } }')
    (base/'Settings.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
 property string themeIdentity: "wabi-sabi"
 property string themeMode: "auto"
 property string paletteSeedColor: ""
 property string wallpaperPath: "/test-wallpaper"
 property bool adaptivePalette: false
 property bool persistenceReady: true
 property string accentName: "violet"
 property var spectralColors: ({})
 property real controlOpacity: 1
 property int controlRadius: 8
 property string barHeightProfile: "normal"
 property bool motion: false
 property string motionSpeedProfile: "normal"
 property string fontText: "sans-serif"
 property string fontDisplay: "sans-serif"
 property string fontMono: "monospace"
 property string fontIcon: "sans-serif"
}''')
    fake=base/'bin/matugen';real=shutil.which('matugen')
    fake.write_text('#!'+sys.executable+'\nimport os,sys,time\nif "--show-source-colors" in sys.argv: print("#ffffff\\n#010101\\n#112233");sys.exit(0)\nif "#badbad" in sys.argv: sys.exit(1)\nif "#112233" in sys.argv: time.sleep(.7)\nos.execv('+repr(real)+',["matugen"]+sys.argv[1:])\n');fake.chmod(0o755)
    png=base/'image.png';tiny_png(png)
    env=dict(os.environ,HOME=temp,XDG_CONFIG_HOME=temp,XDG_CACHE_HOME=temp,XDG_STATE_HOME=temp,XDG_RUNTIME_DIR=temp,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',PATH=str(base/'bin')+':'+os.environ['PATH'],MODE_IMAGE=str(png))
    for key in ('WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):env.pop(key,None)
    proc=subprocess.run(['qs','-p',str(base/'native.qml'),'--no-color'],env=env,text=True,capture_output=True,timeout=15)
    output=proc.stdout+proc.stderr
    # Captured output is included in any assertion failure.
    self.assertEqual(proc.returncode,0,output)
    self.assertIn('MODE COMPLETE 0 failures',output)
    for error in ('MODE FAIL','TypeError','ReferenceError','Unable to assign','Failed to load configuration'):self.assertNotIn(error,output)

if __name__=='__main__':unittest.main()
