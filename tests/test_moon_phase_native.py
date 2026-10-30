"""Check the real calendar's rendered lunar phases, not just its labels."""
import os, shutil, subprocess, tempfile, unittest
from pathlib import Path
try:
    from PIL import Image
except ImportError:
    Image = None

ROOT = Path(__file__).resolve().parents[1]

class MoonPhaseNativeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs') and Image, 'Quickshell or Pillow unavailable')
    def test_new_quarters_and_full_have_correct_lit_sides(self):
        with tempfile.TemporaryDirectory(prefix='moon-phase-') as directory:
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory,
                       XDG_CACHE_HOME=directory, XDG_STATE_HOME=directory,
                       XDG_RUNTIME_DIR=directory, QT_QPA_PLATFORM='offscreen',
                       QT_QUICK_BACKEND='software', DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',
                       MOON_CAPTURE=str(Path(directory)/'phase-'))
            for key in ('WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key, None)
            with tempfile.NamedTemporaryFile('w', suffix='.qml', dir=ROOT/'src/quickshell') as harness:
                harness.write((ROOT/'tests/moon-native.qml').read_text()); harness.flush()
                result = subprocess.run(['qs','-p',harness.name,'--no-color'], env=env,
                                        capture_output=True, text=True, timeout=12)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('MOON COMPLETE', result.stdout + result.stderr)
            # Sample each half away from the terminator and circumference.
            sides=[]
            fractions=[]
            for i in range(8):
                image=Image.open(Path(directory)/f'phase-{i}.png').convert('RGB')
                y=image.height//2
                sides.append(tuple(sum(image.getpixel((int(image.width*x),y))) for x in (0.25,0.75)))
                pixels = [image.getpixel((x,y)) for y in range(image.height) for x in range(image.width)
                          if (x-image.width/2)**2+(y-image.height/2)**2 < (image.width*.46)**2]
                fractions.append(sum(sum(pixel)>300 for pixel in pixels)/len(pixels))
            self.assertLess(max(sides[0]), 180, f'new moon should be dark: {sides}')
            self.assertLess(sides[1][0], sides[1][1], f'first quarter should be lit on the right: {sides}')
            self.assertGreater(min(sides[2]), 300, f'full moon should be bright: {sides}')
            self.assertGreater(sides[3][0], sides[3][1], f'last quarter should be lit on the left: {sides}')
            for i in (4, 7):
                self.assertLess(fractions[i], 0.4, f'crescent should be less than half lit: {fractions}')
            for i in (5, 6):
                self.assertGreater(fractions[i], 0.6, f'gibbous should be more than half lit: {fractions}')
