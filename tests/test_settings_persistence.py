import os
from pathlib import Path
import subprocess
import tempfile
import unittest

class SettingsPersistenceTests(unittest.TestCase):
    def test_undo_survives_own_save_but_not_external_edits(self):
        root=Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as temporary:
            fixture=Path(temporary)/'settings-persistence.qml'
            fixture.write_text((root/'tests/qml/settings-persistence.qml').read_text().replace('../../src/quickshell',(root/'src/quickshell').as_uri()))
            env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',
                     XDG_CONFIG_HOME=temporary+'/config',XDG_RUNTIME_DIR=temporary+'/runtime')
            env.pop('WAYLAND_DISPLAY',None)
            result=subprocess.run(['qs','-p',str(fixture),'--no-color'],
                                  env=env,capture_output=True,text=True,timeout=12)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('SETTINGS CHECK COMPLETE 0',result.stdout+result.stderr)
        self.assertNotIn('CHECK FAIL',result.stdout+result.stderr)
