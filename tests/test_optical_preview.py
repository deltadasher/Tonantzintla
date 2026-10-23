import importlib.util
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zlib

ROOT=Path(__file__).resolve().parents[1]
HELPER=ROOT/'src/libexec/wallpaper-library.py'
def png(path,width,height):
    def chunk(kind,data): return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress((b'\0'+b'\x80\x40\x20'*width)*height))+chunk(b'IEND',b''))

class OpticalPreviewTests(unittest.TestCase):
    def setUp(self):
        spec=importlib.util.spec_from_file_location('wallpaper_library',HELPER)
        self.module=importlib.util.module_from_spec(spec);spec.loader.exec_module(self.module)
        self.temp=tempfile.TemporaryDirectory(prefix='optical-preview-');self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.source=self.root/'source image.png';png(self.source,960,540)
        self.environment=patch.dict(os.environ,{'HOME':str(self.root),'XDG_CACHE_HOME':str(self.root/'cache')});self.environment.start();self.addCleanup(self.environment.stop)

    @unittest.skipUnless(shutil.which('ffmpeg'),'optional ffmpeg unavailable')
    def test_one_file_cli_bounded_cache_and_same_path_replacement(self):
        def run():
            completed=subprocess.run([sys.executable,str(HELPER),'--optical-preview',str(self.source)],capture_output=True,text=True,timeout=15)
            self.assertEqual(completed.returncode,0,completed.stderr);return json.loads(completed.stdout)
        first=run();self.assertTrue(first['ok']);self.assertEqual((first['width'],first['height']),(768,432));self.assertNotEqual(first['preview'],str(self.source))
        stamp=Path(first['preview']).stat().st_mtime_ns
        second=run();self.assertEqual(first,second);self.assertEqual(Path(second['preview']).stat().st_mtime_ns,stamp)
        png(self.source,540,960)
        third=run();self.assertNotEqual(first['preview'],third['preview']);self.assertEqual((third['width'],third['height']),(432,768))
        self.assertFalse((self.root/'state').exists())

    @unittest.skipUnless(shutil.which('ffmpeg'),'optional ffmpeg unavailable')
    def test_picker_and_optical_cache_are_distinct_and_do_not_scan(self):
        with patch.object(self.module,'index_library',side_effect=AssertionError('must not index')):
            picker=self.module.image_preview(self.source)
            optical=self.module.optical_preview(self.source)
        self.assertNotEqual(picker,optical['preview']);self.assertTrue(optical['ok'])
        with patch.object(self.module.shutil,'which',return_value=None):
            self.assertEqual(self.module.optical_preview(self.source),optical)

    def test_bad_video_oversized_and_missing_sources_never_decode(self):
        video=self.root/'input.mp4';video.write_bytes(b'video')
        oversized=self.root/'large.png';oversized.write_bytes(b'\x89PNG\r\n\x1a\n\0\0\0\rIHDR'+struct.pack('>II',90000,90000))
        for source in (video,oversized,self.root/'missing.png'):
            with patch.object(self.module.subprocess,'run',side_effect=AssertionError('must not decode')):
                result=self.module.optical_preview(source)
            self.assertFalse(result['ok']);self.assertEqual(result['preview'],'');self.assertTrue(result['message'])

    def test_missing_converter_is_explicit_fallback(self):
        with patch.object(self.module.shutil,'which',return_value=None):result=self.module.optical_preview(self.source)
        self.assertFalse(result['ok']);self.assertEqual(result['preview'],'')

if __name__=='__main__':unittest.main()
