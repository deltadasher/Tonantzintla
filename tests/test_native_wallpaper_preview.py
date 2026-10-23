import json
import shutil
import subprocess
import sys
import unittest
from unittest.mock import patch
import test_optical_preview as base
HELPER=base.HELPER
png=base.png

class NativeWallpaperPreviewTests(unittest.TestCase):
    setUp=base.OpticalPreviewTests.setUp
    @unittest.skipUnless(shutil.which('ffmpeg'), 'optional ffmpeg unavailable')
    def test_native_exact_file_resolution_cache_and_no_index(self):
        png(self.source, 3000, 1688)
        result=subprocess.run([sys.executable,str(HELPER),'--native-wallpaper-preview',str(self.source)],capture_output=True,text=True,timeout=15)
        self.assertEqual(result.returncode,0,result.stderr)
        data=json.loads(result.stdout);self.assertTrue(data['ok']);self.assertEqual(data['width'],2560);self.assertLessEqual(data['height'],2560)
        self.assertNotEqual(data['preview'],str(self.source))
        self.assertTrue(data['transitionPreview']);self.assertNotEqual(data['transitionPreview'],data['preview'])
        self.assertGreater(data['transitionWidth'],0);self.assertLessEqual(max(data['transitionWidth'],data['transitionHeight']),512)
        with patch.object(self.module,'index_library',side_effect=AssertionError('must not scan')):
            cached=self.module.native_wallpaper_preview(self.source)
        self.assertEqual(cached,data)
        self.assertNotEqual(self.module.optical_preview(self.source)['preview'],data['preview'])

    @unittest.skipUnless(shutil.which('ffmpeg'), 'optional ffmpeg unavailable')
    def test_native_never_upscales_small_sources(self):
        result=self.module.native_wallpaper_preview(self.source)
        self.assertTrue(result['ok']);self.assertEqual((result['width'],result['height']),(960,540))
        png(self.source,128,64)
        tiny=self.module.native_wallpaper_preview(self.source)
        self.assertEqual((tiny['width'],tiny['height']),(128,64))
        self.assertEqual((tiny['transitionWidth'],tiny['transitionHeight']),(128,64))

    def test_native_rejects_video_and_oversized_header_without_decoder(self):
        video=self.root/'input.mp4';video.write_bytes(b'video')
        with patch.object(self.module.subprocess,'run',side_effect=AssertionError('must not decode')):
            result=self.module.native_wallpaper_preview(video)
        self.assertFalse(result['ok']);self.assertFalse(result['preview'])
