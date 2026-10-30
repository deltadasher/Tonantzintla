import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from test_palette_preview import tiny_png

ROOT = Path(__file__).resolve().parents[1]

class PalettePreviewNativeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_selected_palette_lifetime_and_picker_render(self):
        with tempfile.TemporaryDirectory(prefix='palette-native-') as directory:
            root=Path(directory); (root/'tonantzintla').mkdir()
            (root/'tonantzintla/settings.json').write_text(json.dumps({'motion':False,'adaptivePalette':False,'clipboardPaused':True,'opticalControls':False,'wallpaperPath':''}))
            a=root/'a.png'; b=root/'b.png';tiny_png(a);tiny_png(b)
            fake=root/'bin';fake.mkdir()
            matugen=fake/'matugen'
            fake_source = r"""import json,sys,time
from pathlib import Path
if '--show-source-colors' in sys.argv:
    print('#445566\n#cc8844\n#6688cc');sys.exit(0)
if sys.argv[1]=='color':
    color=sys.argv[3]
    if color=='#badbad': sys.exit(1)
else:
    color='#112233' if Path(sys.argv[2]).name=='a.png' else '#445566'
if color=='#112233': time.sleep(.7)
colors=[color,'#9080aa','#ccbbaa','#222233','#eeeedd']
print(json.dumps({'colors':{name:{'dark':{'color':v},'light':{'color':v}} for name,v in zip(['primary','secondary','tertiary','surface_container','on_surface'],colors)}}))
"""
            matugen.write_text('#!'+sys.executable+'\n'+fake_source);matugen.chmod(0o755)
            copier=fake/'wl-copy';copier.write_text('#!/bin/sh\ncat > "$PALETTE_CLIPBOARD_CAPTURE"\n');copier.chmod(0o755)
            env=dict(os.environ,HOME=directory,XDG_CONFIG_HOME=directory,XDG_CACHE_HOME=directory,XDG_STATE_HOME=directory,XDG_RUNTIME_DIR=directory,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',PATH=str(fake)+':'+os.environ['PATH'],PALETTE_A=str(a),PALETTE_B=str(b),PALETTE_MISSING=str(root/'missing.png'),PALETTE_SCREENSHOT=str(root/'palette.png'),PALETTE_CLIPBOARD_CAPTURE=str(root/'copied.txt'))
            for key in ('WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):env.pop(key,None)
            source=(ROOT/'tests/palette/native.qml').read_text().replace('../../src/quickshell','.')
            with tempfile.NamedTemporaryFile('w',prefix='test-palette-',suffix='.qml',dir=ROOT/'src/quickshell') as harness:
                harness.write(source);harness.flush()
                result=subprocess.run(['qs','-p',harness.name,'--no-color'],env=env,capture_output=True,text=True,timeout=15)
            output=result.stdout+result.stderr
            artifact=os.environ.get('TONA_PALETTE_ARTIFACTS')
            if artifact:
                dest=Path(artifact);dest.mkdir(parents=True,exist_ok=True)
                (dest/'native.log').write_text(output)
                if (root/'palette.png').exists():shutil.copyfile(root/'palette.png',dest/'palette.png')
            self.assertEqual(result.returncode,0,output)
            self.assertIn('PALETTE COMPLETE 0 failures',output)
            for error in ('PALETTE FAIL','TypeError','ReferenceError','Unable to assign','Failed to load configuration'):
                self.assertNotIn(error,output)
            self.assertGreater((root/'palette.png').stat().st_size,10000)
            self.assertEqual(json.loads((root/'tonantzintla/palette.json').read_text())['seed'], '')
            self.assertFalse((root/'copied.txt').exists(), 'Theme selection must not copy colors')
            saved=json.loads((root/'tonantzintla/settings.json').read_text())
            self.assertEqual(saved['paletteSeedColor'],'')
            self.assertTrue(saved['adaptivePalette'])

if __name__=='__main__': unittest.main()
