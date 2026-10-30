import importlib.util,json,os,shutil,tempfile,unittest
from pathlib import Path
from unittest import mock
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('palette',ROOT/'src/libexec/palette-state.py')
palette=importlib.util.module_from_spec(spec);spec.loader.exec_module(palette)
class ExactPaletteTests(unittest.TestCase):
 @unittest.skipUnless(shutil.which('matugen'),'Matugen unavailable')
 def test_explicit_hex_is_primary_in_each_mode(self):
  with tempfile.TemporaryDirectory() as d,mock.patch.dict(os.environ,{'XDG_CACHE_HOME':d}):
   for mode in ['dark','light']:
    for seed,ink in [('#170823','#ffffff'),('#FFFFFF','#000000'),('#000000','#ffffff'),('#564697','#ffffff')]:
     with self.subTest(mode=mode,seed=seed):
      out=palette.generate(Path(d)/'unused',seed,mode)
      self.assertTrue(out['ok'],out)
      colors=out['palette']['colors']
      for variant in ['dark','light','default']:
       self.assertEqual(colors['primary'][variant]['color'],seed.lower())
       self.assertEqual(colors['on_primary'][variant]['color'],ink)
      self.assertNotEqual(colors['surface_container'][mode]['color'],seed.lower())
 def test_existing_seeded_cache_is_adapted_without_mutating_unrelated_colors(self):
  with tempfile.TemporaryDirectory() as d,mock.patch.dict(os.environ,{'XDG_CACHE_HOME':d}):
   path=palette.cached_palette();path.parent.mkdir()
   path.write_text(json.dumps({'ok':True,'seed':'#170823','palette':{'colors':{'primary':{'dark':{'color':'#deb9f7'}},'surface':{'dark':{'color':'#111111'}}}}}))
   out=palette.read_cached()
   self.assertEqual(out['palette']['colors']['primary']['dark']['color'],'#170823')
   self.assertEqual(out['palette']['colors']['surface']['dark']['color'],'#111111')
 def test_automatic_cache_keeps_generated_palette(self):
  with tempfile.TemporaryDirectory() as d,mock.patch.dict(os.environ,{'XDG_CACHE_HOME':d}):
   path=palette.cached_palette();path.parent.mkdir()
   data={'ok':True,'seed':'','palette':{'colors':{'primary':{'dark':{'color':'#deb9f7'}}}}}
   path.write_text(json.dumps(data));self.assertEqual(palette.read_cached(),data)
 @unittest.skipUnless(shutil.which('matugen'),'Matugen unavailable')
 def test_preview_accent_equals_selected_source_without_applying_it(self):
  import struct,zlib
  with tempfile.TemporaryDirectory() as d,mock.patch.dict(os.environ,{'XDG_CACHE_HOME':d}):
   def chunk(k,v):return struct.pack('>I',len(v))+k+v+struct.pack('>I',zlib.crc32(k+v))
   image=Path(d)/'image.png'
   image.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1,1,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b'\x00\x56\x46\x97'))+chunk(b'IEND',b''))
   for mode in ['dark','light']:
    out=palette.preview(image,'#170823',mode);self.assertTrue(out['ok'],out)
    accent=next(s for s in out['swatches'] if s['role']=='primary')
    self.assertEqual(accent['color'],'#170823');self.assertFalse(palette.cached_palette(mode).exists())
