import os
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

class ToolsNativeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'),'Quickshell unavailable')
    def test_native_tools_keyboard_persistence_and_render(self):
        project=Path(__file__).resolve().parents[1]
        source=(project/'tests/tools/native.qml').read_text().replace('../../src/quickshell/','').replace('"../../src/quickshell"','"."')
        with tempfile.TemporaryDirectory(prefix='tools-native-') as directory:
            root=Path(directory);(root/'fixture.txt').write_text('one folder only')
            (root/'tonantzintla').mkdir();(root/'tonantzintla/settings.json').write_text('{"clipboardPaused":true,"motion":false}')
            fake=root/'bin';fake.mkdir()
            for binary in ('cliphist','wl-paste','wl-copy','niri'):
                script=fake/binary
                script.write_text('#!/bin/sh\ncat > "$UNIT_CLIPBOARD_CAPTURE"\n' if binary == 'wl-copy' else '#!/bin/sh\nexit 0\n')
                script.chmod(0o755)
            screenshot=root/'tools.png'
            env=dict(os.environ,HOME=directory,XDG_CONFIG_HOME=directory,XDG_CACHE_HOME=directory,XDG_STATE_HOME=directory,XDG_RUNTIME_DIR=directory,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',PATH=str(fake)+':'+os.environ['PATH'],TOOLS_SCREENSHOT=str(screenshot),UNIT_CLIPBOARD_CAPTURE=str(root/"copied.txt"))
            for key in ('WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):env.pop(key,None)
            with tempfile.NamedTemporaryFile(mode='w',prefix='test-tools-',suffix='.qml',dir=project/'src/quickshell') as harness:
                harness.write(source);harness.flush()
                result=subprocess.run(['qs','-p',harness.name,'--no-color'],env=env,capture_output=True,text=True,timeout=15)
            output=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,output)
            self.assertIn('TOOLS COMPLETE 0 failures',output)
            for bad in ('TOOLS FAIL','ReferenceError','TypeError','Unable to assign','Failed to load configuration'):
                self.assertNotIn(bad,output)
            self.assertGreater(screenshot.stat().st_size,10000)
            self.assertEqual((root/"copied.txt").read_text(), "8 Mb")
            persisted=json.loads((root/"tonantzintla/settings.json").read_text())
            self.assertIn("!",persisted["toolboxState"]["notes"][0]["body"])
            self.assertEqual(persisted["toolboxState"]["history"][0]["result"],"15")
