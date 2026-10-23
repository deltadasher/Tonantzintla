import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import wave

ROOT=Path(__file__).resolve().parents[1]

class FeedbackNativeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'),'Quickshell unavailable')
    def test_editor_body_settings_and_silent_sound_lifecycle(self):
        with tempfile.TemporaryDirectory(prefix='feedback-native-') as directory:
            folder=Path(directory);binary=folder/'bin';binary.mkdir();marker=folder/'calls.txt'
            player=binary/'pw-play';player.write_text('#!/bin/sh\nprintf "mock\\n" >> "$FEEDBACK_MOCK_CALLS"\n');player.chmod(0o755)
            for name in ('niri','wl-paste','cliphist'):
                p=binary/name;p.write_text('#!/bin/sh\nexit 0\n');p.chmod(0o755)
            wav=folder/'silent.wav'
            with wave.open(str(wav),'wb') as f:f.setparams((1,2,8000,0,'NONE','not compressed'));f.writeframes(b'\0\0'*8000)
            config=folder/'tonantzintla';config.mkdir();(config/'settings.json').write_text(json.dumps({'motion':False,'clipboardPaused':True,'notificationSoundPath':str(wav)}))
            env=dict(os.environ,HOME=directory,XDG_CONFIG_HOME=directory,XDG_CACHE_HOME=directory,XDG_STATE_HOME=directory,XDG_DATA_HOME=directory,XDG_RUNTIME_DIR=directory,
                QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',PATH=str(binary)+':'+os.environ['PATH'],FEEDBACK_MOCK_CALLS=str(marker))
            for key in ('WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):env.pop(key,None)
            with tempfile.NamedTemporaryFile(mode='w',prefix='test-feedback-',suffix='.qml',dir=ROOT/'src/quickshell') as fixture:
                fixture.write((ROOT/'tests/feedback/native.qml').read_text().replace('../../src/quickshell','.'));fixture.flush()
                result=subprocess.run(['qs','-p',fixture.name,'--no-color'],env=env,capture_output=True,text=True,timeout=12)
            output=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,output);self.assertIn('FEEDBACK_COMPLETE 0',output)
            for error in ('FEEDBACK_FAILED','ReferenceError','TypeError','Unable to assign','Binding loop'):self.assertNotIn(error,output)
            self.assertEqual(marker.read_text().splitlines(),['mock'])
