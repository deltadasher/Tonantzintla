"""Exercise local extraction, its privacy limits, and real decoder behavior."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

HAS_PIL = importlib.util.find_spec('PIL') is not None

HELPER = Path(__file__).resolve().parents[1] / 'src/libexec/screen-extract.py'


class ScreenExtractTests(unittest.TestCase):
    def cli(self, *args, env=None):
        result = subprocess.run([sys.executable, str(HELPER), *args], capture_output=True,
                                text=True, timeout=40, env=env or {**os.environ, 'XDG_DATA_HOME': '/nonexistent-screen-extract-test-data'})
        self.assertEqual(result.stderr, '')
        self.assertEqual(len(result.stdout.splitlines()), 1)
        return result.returncode, json.loads(result.stdout)

    def test_capabilities_returns_actual_tools_and_languages(self):
        code, result = self.cli('capabilities')
        self.assertEqual(code, 0)
        self.assertEqual(result['kind'], 'capabilities')
        self.assertEqual(result['tools']['tesseract'], bool(shutil.which('tesseract')))
        self.assertIsInstance(result['languages'], list)
        self.assertNotIn('osd', result['languages'])

    def test_missing_dependency_is_json_error(self):
        code, result = self.cli('qr', '--image', '/does-not-exist', env={**os.environ, 'PATH': ''})
        self.assertEqual((code, result['state']), (1, 'error'))
        self.assertIn('zbarimg', result['message'])

    def test_invalid_arguments_are_json(self):
        code, result = self.cli('ocr', '--unexpected')
        self.assertEqual((code, result['state']), (1, 'error'))

    def test_uninstalled_language_fails_without_capture(self):
        code, result = self.cli('ocr', '--language', 'missing_test_language')
        self.assertEqual((code, result['state']), (1, 'error'))
        self.assertIn('language', result['message'].lower())

    def test_bad_image_and_oversized_image(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'image.png'
            path.write_bytes(b'not a PNG')
            self.assertEqual(self.cli('qr', '--image', str(path))[1]['state'], 'error')
            with path.open('wb') as stream:
                stream.truncate(34 * 1024 * 1024)
            self.assertEqual(self.cli('qr', '--image', str(path))[1]['state'], 'error')

    @unittest.skipUnless(HAS_PIL and shutil.which('qrencode') and shutil.which('zbarimg'), 'QR tools unavailable')
    def test_real_qr_preserves_unicode_multiline_and_multiple_values(self):
        from PIL import Image
        values = ['雪猫\nhttps://example.com/?a=1&b=2', 'QR-Code:literal prefix']
        with tempfile.TemporaryDirectory() as folder:
            images = []
            for index, value in enumerate(values):
                path = Path(folder) / f'{index}.png'
                subprocess.run(['qrencode', '-s', '6', '-o', str(path), value], check=True)
                with Image.open(path) as image:
                    images.append(image.convert('RGBA').convert('RGB'))
            canvas = Image.new('RGB', (sum(i.width for i in images) + 80, max(i.height for i in images) + 40), 'white')
            x = 20
            for image in images:
                canvas.paste(image, (x, 20))
                x += image.width + 40
            path = Path(folder) / 'multiple.png'
            canvas.save(path)
            code, result = self.cli('qr', '--image', str(path))
            self.assertEqual((code, result['state']), (0, 'ready'))
            self.assertCountEqual(result['values'], values)
            self.assertEqual(result['text'], '\n'.join(result['values']))

    @unittest.skipUnless(HAS_PIL and shutil.which('tesseract'), 'Tesseract unavailable')
    def test_real_ocr_and_empty_image(self):
        from PIL import Image, ImageDraw, ImageFont
        _, caps = self.cli('capabilities')
        if not caps['languages']:
            self.skipTest('No OCR language installed')
        language = 'eng' if 'eng' in caps['languages'] else caps['languages'][0]
        font_path = next((str(path) for path in [Path('/usr/share/fonts/TTF/DejaVuSans.ttf'), Path('/usr/share/fonts/noto/NotoSans-Regular.ttf')] if path.exists()), '')
        if not Path(font_path).exists():
            self.skipTest('Fixture font unavailable')
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'text.png'
            image = Image.new('RGB', (1100, 180), 'white')
            ImageDraw.Draw(image).text((30, 40), 'HELLO SCREEN 12345', fill='black', font=ImageFont.truetype(font_path, 64))
            image.save(path)
            code, result = self.cli('ocr', '--language', language, '--image', str(path))
            self.assertEqual((code, result['state']), (0, 'ready'))
            self.assertIn('HELLO SCREEN 12345', result['text'])
            Image.new('RGB', (300, 200), 'white').save(path)
            self.assertEqual(self.cli('ocr', '--language', language, '--image', str(path))[1]['state'], 'empty')
            self.assertEqual(self.cli('qr', '--image', str(path))[1]['state'], 'empty')


class ScreenExtractBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('screen_extract', HELPER)
        cls.helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.helper)

    def test_geometry_rejects_shell_text_zero_and_huge_sizes(self):
        for geometry in ['0,0 0x10', '0,0 999999x10', '1,2 30x40; id', '1,2 30x40\n1,2 3x4']:
            with self.subTest(geometry=geometry), self.assertRaises(self.helper.ExtractError):
                self.helper.validate_geometry(geometry)
        self.assertEqual(self.helper.validate_geometry('-1920,0 1920x1080\n'), '-1920,0 1920x1080')

    @unittest.skipUnless(all(shutil.which(tool) for tool in ('slurp', 'grim', 'zbarimg')), 'Capture tools unavailable')
    def test_cancelled_selection_does_not_create_image(self):
        with patch.object(self.helper, 'run_tool', return_value=(1, b'', b'selection cancelled\n')):
            result = self.helper.extract('qr', None, 'eng')
        self.assertEqual(result['state'], 'cancelled')
        self.assertEqual(result['text'], '')

    @unittest.skipUnless(all(shutil.which(tool) for tool in ('slurp', 'grim', 'zbarimg')), 'Capture tools unavailable')
    def test_failed_capture_cleans_private_folder(self):
        captured = []
        def run(args, **kwargs):
            if args[0] == 'slurp':
                return 0, b'0,0 100x100\n', b''
            captured.append(Path(args[-1]))
            captured[-1].write_bytes(b'secret screenshot')
            self.assertEqual(captured[-1].parent.stat().st_mode & 0o777, 0o700)
            return 1, b'', b'sensitive diagnostics'
        with patch.object(self.helper, 'run_tool', side_effect=run):
            result = self.helper.extract('qr', None, 'eng')
        self.assertEqual(result['state'], 'error')
        self.assertNotIn('sensitive', result['message'])
        self.assertFalse(captured[0].parent.exists())

    @unittest.skipUnless(HAS_PIL and shutil.which('tesseract'), 'OCR fixture tools unavailable')
    def test_user_models_add_to_system_languages_and_select_directory(self):
        from PIL import Image
        with tempfile.TemporaryDirectory() as folder:
            models = Path(folder) / 'tonantzintla/ocr'
            models.mkdir(parents=True)
            (models / 'custom.traineddata').write_bytes(b'fixture model')
            image = Path(folder) / 'input.png'
            Image.new('RGB', (20, 20), 'white').save(image)
            def run(args, **kwargs):
                if args == ['tesseract', '--list-langs']:
                    return 0, b'List of available languages (2):\neng\nosd\n', b''
                self.assertEqual(args[-2:], ['--tessdata-dir', str(models)])
                self.assertIn('custom', args)
                return 0, b'Local model text\n', b''
            with patch.dict(os.environ, {'XDG_DATA_HOME': folder}), patch.object(self.helper, 'run_tool', side_effect=run):
                caps = self.helper.capabilities()
                self.assertEqual(caps['languages'], ['custom', 'eng'])
                self.assertEqual(caps['defaultLanguage'], 'eng')
                self.assertEqual(self.helper.extract('ocr', str(image), 'custom')['text'], 'Local model text')

    def test_huge_png_dimensions_are_rejected_before_decoding(self):
        import struct
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'bomb.png'
            path.write_bytes(b'\x89PNG\r\n\x1a\n' + b'\x00\x00\x00\rIHDR' + struct.pack('>II', 100000, 100000) + b'\x00' * 20)
            with self.assertRaises(self.helper.ExtractError):
                self.helper.read_png(path)

    def test_qr_output_limit_is_explicit(self):
        with self.assertRaises(self.helper.ExtractError):
            self.helper.decode_qr(b'<barcodes><symbol type="QR-Code"><data>' + b'a' * 65537 + b'</data></symbol></barcodes>')

    def test_runner_timeout_and_output_limit(self):
        with self.assertRaises(self.helper.ExtractError):
            self.helper.run_tool([sys.executable, '-c', 'import time; time.sleep(3)'], timeout=.05)
        with self.assertRaises(self.helper.ExtractError):
            self.helper.run_tool([sys.executable, '-c', 'print("x" * 2000000)'], timeout=3)

    def test_qr_binary_and_malformed_xml_fail_explicitly(self):
        for data in [b'not xml', b'<!DOCTYPE x><barcodes/>',
                     b'<barcodes><symbol type="QR-Code"><data format="base64">/w==</data></symbol></barcodes>']:
            with self.subTest(data=data), self.assertRaises(self.helper.ExtractError):
                self.helper.decode_qr(data)


if __name__ == '__main__':
    unittest.main()
