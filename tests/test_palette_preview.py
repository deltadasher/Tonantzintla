"""Selected-wallpaper previews must never replace the applied theme palette."""
import importlib.util
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock
import zlib

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'src/libexec/palette-state.py'
spec = importlib.util.spec_from_file_location('palette_state', HELPER)
palette = importlib.util.module_from_spec(spec)
spec.loader.exec_module(palette)


def tiny_png(path):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(b'\x00\x80\x30\xa0')) + chunk(b'IEND', b''))


class PalettePreviewTests(unittest.TestCase):
    def test_selected_preview_does_not_change_global_applied_palette(self):
        self.assertTrue(hasattr(palette, 'preview'), 'preview mode is implemented')
        with tempfile.TemporaryDirectory() as directory, mock.patch.dict(os.environ, {'XDG_CACHE_HOME': directory}):
            root = Path(directory); image = root / 'sample.png'; tiny_png(image)
            global_cache = root / 'tonantzintla/palette.json'; global_cache.parent.mkdir()
            global_cache.write_text('applied-theme-sentinel')
            fake = root / 'matugen'
            colors = {key: {'dark': {'color': value}} for key, value in zip(['primary', 'secondary', 'tertiary', 'surface_container', 'on_surface'], ['#112233', '#445566', '#778899', '#101010', '#eeeeee'])}
            fake.write_text('#!' + sys.executable + '\nimport sys\nprint("#112233\\n#445566\\n#778899" if "--show-source-colors" in sys.argv else ' + repr(json.dumps({'colors': colors})) + ')\n'); fake.chmod(0o755)
            with mock.patch.dict(os.environ, {'PATH': directory}):
                result = palette.preview(image)
            self.assertTrue(result['ok'], result)
            self.assertEqual([entry['color'] for entry in result['swatches']], ['#112233', '#445566', '#778899', '#101010', '#eeeeee'])
            self.assertEqual(global_cache.read_text(), 'applied-theme-sentinel')
            fake.unlink()
            cached = palette.preview(image)
            self.assertEqual(cached['swatches'], result['swatches'])
            image.write_bytes(image.read_bytes() + b'changed')
            with mock.patch.dict(os.environ, {'PATH': directory}):
                self.assertFalse(palette.preview(image)['ok'], 'source change invalidates cache')

    def test_missing_or_invalid_sources_do_not_reuse_cached_colors(self):
        self.assertTrue(hasattr(palette, 'preview'), 'preview mode is implemented')
        with tempfile.TemporaryDirectory() as directory, mock.patch.dict(os.environ, {'XDG_CACHE_HOME': directory, 'PATH': directory}):
            root = Path(directory)
            for name in ('missing.png', 'video.mp4'):
                result = palette.preview(root / name)
                self.assertFalse(result['ok'])
                self.assertEqual(result.get('swatches', []), [])
            image = root / 'sample.png'; tiny_png(image)
            self.assertIn('Matugen', palette.preview(image)['error'])

    def test_swatch_validation_rejects_css_payloads_and_deduplicates_colors(self):
        self.assertTrue(hasattr(palette, 'preview_swatches'), 'preview palette validation exists')
        data = {'colors': {name: {'dark': {'color': color}} for name, color in [('primary', '#ABCDEF'), ('secondary', '#abcdef'), ('tertiary', 'red;anything'), ('surface_container', '#121212'), ('on_surface', '#eeeeee')]}}
        self.assertEqual([row['color'] for row in palette.preview_swatches(data)], ['#abcdef', '#121212', '#eeeeee'])
        self.assertEqual(palette.preview_swatches({'colors': {}}), [])

    def test_malformed_matugen_response_is_a_clear_preview_failure(self):
        self.assertTrue(hasattr(palette, 'preview'), 'preview mode is implemented')
        with tempfile.TemporaryDirectory() as directory, mock.patch.dict(os.environ, {'XDG_CACHE_HOME': directory, 'PATH': directory}):
            root = Path(directory); image = root / 'sample.png'; tiny_png(image)
            fake = root / 'matugen'; fake.write_text('#!' + sys.executable + '\nprint("not json")\n'); fake.chmod(0o755)
            result = palette.preview(image)
            self.assertFalse(result['ok']); self.assertTrue(result['error']); self.assertEqual(result['swatches'], [])

    def test_real_seed_changes_generated_palette_and_preview_does_not_apply(self):
        import shutil
        if not shutil.which("matugen"): self.skipTest("Matugen unavailable")
        with tempfile.TemporaryDirectory() as directory, mock.patch.dict(os.environ, {"XDG_CACHE_HOME": directory}):
            image=Path(directory)/"image.png"; tiny_png(image)
            red=palette.generate(image, "#cc3333")
            blue=palette.generate(image, "#3366cc")
            self.assertTrue(red["ok"], red); self.assertTrue(blue["ok"], blue)
            self.assertNotEqual(red["palette"]["colors"]["primary"], blue["palette"]["colors"]["primary"])
            self.assertEqual(blue["seed"], "#3366cc")
            saved=palette.cached_palette().read_bytes()
            preview=palette.preview(image, "#cc3333")
            self.assertTrue(preview["ok"], preview)
            self.assertEqual(preview["seed"], "#cc3333")
            self.assertTrue(preview["choices"])
            self.assertEqual(palette.cached_palette().read_bytes(), saved)
            self.assertFalse(palette.generate(image,"red; command")["ok"])
            self.assertEqual(palette.cached_palette().read_bytes(), saved)

    def test_canceling_preview_terminates_its_owned_matugen_child(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); image=root/'sample.png';tiny_png(image)
            pid_file=root/'child.pid';fake=root/'matugen'
            fake.write_text('#!'+sys.executable+'\nimport os,time\nfrom pathlib import Path\nPath('+repr(str(pid_file))+').write_text(str(os.getpid()))\ntime.sleep(30)\n');fake.chmod(0o755)
            env=dict(os.environ,XDG_CACHE_HOME=directory,PATH=directory)
            helper=subprocess.Popen([sys.executable,str(HELPER),'--preview',str(image)],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            try:
                deadline=time.monotonic()+3
                while not pid_file.exists() and time.monotonic()<deadline:time.sleep(.02)
                self.assertTrue(pid_file.exists(),'Matugen child starts')
                child=int(pid_file.read_text());helper.terminate();helper.communicate(timeout=3)
                with self.assertRaises(ProcessLookupError):os.kill(child,0)
                self.assertFalse((root/'tonantzintla/palette.json').exists())
            finally:
                if helper.poll() is None:helper.kill();helper.communicate()


if __name__ == '__main__': unittest.main()
