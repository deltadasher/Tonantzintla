"""Parallax opens on the current wallpaper and samples unique alternatives."""
import json,os,shutil,struct,subprocess,tempfile,unittest,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class ParallaxSelectionNativeTests(unittest.TestCase):
 @unittest.skipUnless(shutil.which('qs'),'Quickshell unavailable')
 def test_current_wallpaper_randomized_orbit_and_shuffle_lifecycle(self):
  with tempfile.TemporaryDirectory(prefix='parallax-selection-') as directory:
   home=Path(directory);(home/'tonantzintla').mkdir()
   (home/'tonantzintla/settings.json').write_text(json.dumps(dict(motion=False,adaptivePalette=False,clipboardPaused=True,opticalControls=False,wallpaperPath='')))
   def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
   entries=[]
   for n in range(11):
    p=home/f'world-{n}.png'
    p.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1,1,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(bytes([0,40+n*10,60+n*5,120+n*8])))+chunk(b'IEND',b''))
    entries.append(dict(path=str(p),preview=str(p),name=f'World {n+1}',source='Local',kind='image'))
   env=dict(os.environ,HOME=directory,XDG_CONFIG_HOME=directory,XDG_CACHE_HOME=directory,XDG_STATE_HOME=directory,XDG_RUNTIME_DIR=directory,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',PARALLAX_ENTRIES=json.dumps(entries[:10]),PARALLAX_EXTERNAL=entries[10]['path'],PARALLAX_CAPTURE=str(home/'orbit.png'))
   for key in ['WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(key,None)
   with tempfile.NamedTemporaryFile('w',suffix='.qml',dir=ROOT/'src/quickshell') as harness:
    harness.write((ROOT/'tests/parallax/native.qml').read_text());harness.flush()
    p=subprocess.run(['qs','-p',harness.name,'--no-color'],env=env,capture_output=True,text=True,timeout=12)
   out=p.stdout+p.stderr
   self.assertEqual(p.returncode,0,out);self.assertIn('PARALLAX COMPLETE 0 failures',out)
   for error in ['TypeError','ReferenceError','Unable to assign','Failed to load configuration']:self.assertNotIn(error,out)
   self.assertTrue((home/'orbit.png').exists())
