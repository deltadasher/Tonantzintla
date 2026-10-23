"""Bound preview allocations without changing the original apply source."""
import importlib.util
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
from unittest import mock
import zlib

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('wallpaper_library', ROOT / 'src/libexec/wallpaper-library.py')
library = importlib.util.module_from_spec(spec)
spec.loader.exec_module(library)


def png(path, width, height):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress((b'\x00' + b'\x40\x60\x80' * width) * height)) + chunk(b'IEND', b''))


class PreviewTests(unittest.TestCase):
    def test_jpeg_header_selects_reduced_decode_without_undersizing(self):
        options = getattr(library, 'preview_decode_options', None)
        self.assertTrue(callable(options), 'Preview decoding must inspect bounded image headers first')
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'source.jpg'
            for width, height, expected in [(320,180,[]),(768,512,[]),(1024,512,['-lowres','1']),
                                             (2048,1024,['-lowres','2']),(16000,16000,['-lowres','3'])]:
                frame = struct.pack('>BHHB',8,height,width,3) + b'\x01\x11\x00\x02\x11\x00\x03\x11\x00'
                source.write_bytes(b'\xff\xd8\xff\xe0\x00\x06test\xff\xc0' + struct.pack('>H',len(frame)+2) + frame)
                self.assertEqual(options(source),expected,(width,height))
            source.write_bytes(source.read_bytes().replace(b'\xff\xc0',b'\xff\xc2'))
            self.assertIsNone(options(source), 'Huge progressive coefficients must not bypass the decode budget')

    def test_malformed_and_oversize_headers_skip_decoder(self):
        options = getattr(library, 'preview_decode_options', None)
        self.assertTrue(callable(options), 'Malformed or unsafe previews must fall back before decode')
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'unsafe.jpg'
            for header in (b'\xff\xd8\xff\xe0\x00\x01', b'\xff\xd8\xff\xc0\x00\x11\x08',
                           b'\xff\xd8\xff\xda\x00\x02', b'\x89PNG\r\n\x1a\n'+b'\x00\x00\x00\rIHDR'+struct.pack('>II',16000,16000)):
                source.write_bytes(header)
                self.assertIsNone(options(source))
                with mock.patch.object(library, 'cache_home', return_value=Path(directory)/'cache'), mock.patch.object(library.subprocess,'run') as run:
                    self.assertEqual(library.image_preview(source),'')
                    run.assert_not_called()

    def test_other_supported_headers_bound_source_pixels(self):
        with tempfile.TemporaryDirectory() as directory:
            source=Path(directory)/'fixture'
            packed=(640-1)|((360-1)<<14)
            for header in (
                b'GIF89a'+struct.pack('<HH',640,360),
                b'BM'+bytes(12)+struct.pack('<Iii',40,640,-360),
                b'RIFF'+bytes(4)+b'WEBPVP8X'+struct.pack('<I',10)+bytes(4)+(639).to_bytes(3,'little')+(359).to_bytes(3,'little'),
                b'RIFF'+bytes(4)+b'WEBPVP8L'+struct.pack('<I',5)+b'\x2f'+struct.pack('<I',packed),
                b'RIFF'+bytes(4)+b'WEBPVP8 '+struct.pack('<I',10)+bytes(3)+b'\x9d\x01\x2a'+struct.pack('<HH',640,360)):
                source.write_bytes(header)
                self.assertEqual(library.preview_decode_options(source),[])
            source.write_bytes(b'GIF89a'+struct.pack('<HH',16000,16000))
            self.assertIsNone(library.preview_decode_options(source))
            source.write_bytes(b'\x00\x00\x00\x20ftypavif'+bytes(24))
            self.assertIsNone(library.preview_decode_options(source), 'Unknown geometry must fail closed')

    @unittest.skipUnless(shutil.which('ffmpeg') and (ROOT/'src/assets/wallpapers/nasa-observatory/PIA18164.jpg').is_file(), 'Bundled NASA fixture or ffmpeg unavailable')
    def test_bundled_large_nasa_jpeg_reduced_preview(self):
        source=ROOT/'src/assets/wallpapers/nasa-observatory/PIA18164.jpg'
        before=source.stat()
        self.assertEqual(library.preview_decode_options(source),['-lowres','3'])
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(library,'cache_home',return_value=Path(directory)):
            preview=Path(library.image_preview(source))
            self.assertTrue(preview.is_file())
            self.assertEqual(struct.unpack('>II',preview.read_bytes()[16:24]),(512,512))
        after=source.stat()
        self.assertEqual((before.st_size,before.st_mtime_ns),(after.st_size,after.st_mtime_ns))

    @unittest.skipUnless(shutil.which('ffmpeg'), 'existing optional ffmpeg unavailable')
    def test_real_jpeg_uses_reduced_decode_and_keeps_original(self):
        with tempfile.TemporaryDirectory() as directory:
            source=Path(directory)/'large.jpg'
            subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','color=c=blue:s=2048x1024',
                            '-frames:v','1','-threads','1',str(source)],check=True,capture_output=True,timeout=12)
            original=source.read_bytes()
            with mock.patch.object(library,'cache_home',return_value=Path(directory)/'cache'):
                preview=Path(library.image_preview(source))
                self.assertTrue(preview.is_file())
                self.assertEqual(struct.unpack('>II',preview.read_bytes()[16:24]),(512,256))
            self.assertEqual(source.read_bytes(),original)

    def test_missing_converter_never_returns_original(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'large source.png'
            png(source, 64, 32)
            self.assertTrue(callable(getattr(library, 'image_preview', None)), 'Local stills need bounded previews')
            with mock.patch.object(library, 'cache_home', return_value=Path(directory) / 'cache'), mock.patch.object(library.shutil, 'which', return_value=None):
                self.assertEqual(library.image_preview(source), '')

    @unittest.skipUnless(shutil.which('ffmpeg'), 'existing optional ffmpeg unavailable')
    def test_real_preview_is_bounded_cached_and_invalidated(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'large source.png'
            png(source, 2048, 1024)
            original = source.read_bytes()
            self.assertTrue(callable(getattr(library, 'image_preview', None)), 'Local stills need bounded previews')
            with mock.patch.object(library, 'cache_home', return_value=Path(directory) / 'cache'):
                preview = Path(library.image_preview(source))
                self.assertNotEqual(preview, source)
                width, height = struct.unpack('>II', preview.read_bytes()[16:24])
                self.assertLessEqual(max(width, height), 512)
                self.assertAlmostEqual(width / height, 2)
                modified = preview.stat().st_mtime_ns
                self.assertEqual(library.image_preview(source), str(preview))
                self.assertEqual(preview.stat().st_mtime_ns, modified)
                os.utime(source, ns=(source.stat().st_atime_ns, source.stat().st_mtime_ns + 1000000))
                self.assertNotEqual(library.image_preview(source), str(preview))
            self.assertEqual(source.read_bytes(), original)

    def test_corrupt_image_falls_back_without_full_decode(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'broken.png'
            source.write_bytes(b'broken')
            self.assertTrue(callable(getattr(library, 'image_preview', None)), 'Local stills need bounded previews')
            with mock.patch.object(library, 'cache_home', return_value=Path(directory) / 'cache'):
                self.assertEqual(library.image_preview(source), '')
