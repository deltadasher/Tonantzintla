"""Actual five clock faces at a fixed afternoon time; no clock acquisition/auth."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

class ClockNotationNativeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_global_notation_and_classic_miniature_composition(self):
        repo=Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory(prefix='clock-notation-') as directory:
            capture=Path(directory)/'clocks.png'
            env=dict(os.environ,HOME=directory,XDG_STATE_HOME=directory,XDG_DATA_HOME=directory,
                     XDG_RUNTIME_DIR=directory,XDG_CONFIG_HOME=directory,XDG_CACHE_HOME=directory,
                     QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',CLOCK_CAPTURE=str(capture),
                     DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent',DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
            for key in ('WAYLAND_DISPLAY','NIRI_SOCKET'):env.pop(key,None)
            result=subprocess.run(['qs','-p',str(repo/'src/quickshell/preview-clock-notation.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=10)
            output=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,output)
            self.assertIn('CLOCK_COMPLETE 0',output)
            for error in ('CLOCK_FAILED','TypeError','ReferenceError','Binding loop','Unable to assign'):self.assertNotIn(error,output)
            self.assertGreater(capture.stat().st_size,1000)
            artifacts=os.environ.get('TONA_CLOCK_ARTIFACTS')
            if artifacts:
                dest=Path(artifacts);dest.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(capture,dest/'clocks.png');(dest/'native.log').write_text(output)
