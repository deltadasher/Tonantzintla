"""Bundled asset identity/notices and optional offline pinned-source regeneration."""
import ctypes.util
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]
FONTS=ROOT/'src/assets/fonts'
class IconSubsetAssetTests(unittest.TestCase):
    def test_asset_identity_repertoire_and_notices(self):
        raw=(FONTS/'TonantzintlaSymbols-Regular.ttf').read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(),'d45688f2b7bbcc497ec31159c2c4690d9fea3df798a53338da834c2d4f1ae511')
        self.assertLess(len(raw),600000)
        count=struct.unpack_from('>H',raw,4)[0]
        tables={tag:raw[offset:offset+size] for tag,_,offset,size in
                (struct.unpack_from('>4sIII',raw,12+16*i) for i in range(count))}
        name=tables[b'name'];_,count,start=struct.unpack_from('>HHH',name)
        names=[]
        for i in range(count):
            p,e,l,k,size,offset=struct.unpack_from('>6H',name,6+12*i)
            value=name[start+offset:start+offset+size].decode('utf-16-be' if p in (0,3) else 'mac_roman')
            names.append((k,value))
        for key,value in names:
            if key in (1,3,4,6,16,18,21):
                self.assertNotIn('Iosevka',value)
                self.assertIn('Tonantzintla',value)
        self.assertTrue(any(k==0 and 'Renzhi Li' in v for k,v in names))
        self.assertTrue(any(k==13 and 'SIL Open Font License' in v for k,v in names))
        for file in ('NOTICE.md','IOSEVKA-OFL.md','NERD-FONTS-LICENSE.md','IEC-MIT.txt','MATERIALDESIGN-LICENSE.md','APACHE-2.0.txt'):
            self.assertGreater((FONTS/file).stat().st_size,500)

    def test_pinned_source_regenerates_identically_when_available(self):
        source=Path('/usr/share/fonts/TTF/IosevkaNerdFont-Regular.ttf')
        manifest=json.loads((FONTS/'glyphs.json').read_text())
        if not source.exists() or hashlib.sha256(source.read_bytes()).hexdigest()!=manifest['source_sha256']:
            self.skipTest('Pinned original font unavailable; asset identity remains checked')
        if not ctypes.util.find_library('harfbuzz-subset'):
            self.skipTest('Optional build-time HarfBuzz subset library unavailable')
        result=subprocess.run(['python3',str(ROOT/'tools/build-icon-font.py'),'--source',str(source),'--check'],capture_output=True,text=True,timeout=10)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
