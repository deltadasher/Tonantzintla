import importlib.util
import io
import json
import os
import subprocess
import time
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import wave

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('notification_sound',ROOT/'src/libexec/notification-sound.py')
sound=importlib.util.module_from_spec(spec);spec.loader.exec_module(sound)

class NotificationSoundTests(unittest.TestCase):
    def fixture(self,folder,seconds=1):
        path=Path(folder)/'quiet fixture.wav'
        with wave.open(str(path),'wb') as f:
            f.setparams((1,2,8000,0,'NONE','not compressed'));f.writeframes(b'\0\0'*(8000*seconds))
        return path
    def test_check_validates_local_sound_without_starting_any_player(self):
        with tempfile.TemporaryDirectory() as d:
            p=self.fixture(d)
            with patch.object(sound.shutil,'which',return_value='/fake/pw-play'),patch.object(sound.subprocess,'run') as run:
                result=sound.run('check',p.as_uri(),.5)
            self.assertTrue(result['available']);self.assertEqual(result['state'],'ready');run.assert_not_called()
    def test_missing_player_invalid_remote_and_long_files_are_truthful(self):
        with patch.object(sound.shutil,'which',return_value=None):self.assertFalse(sound.run('check','',.5)['available'])
        with tempfile.TemporaryDirectory() as d,patch.object(sound.shutil,'which',return_value='/fake/pw-play'):
            for source in ['https://example.test/a.wav','file://remote/a.wav',str(self.fixture(d,6))]:
                self.assertFalse(sound.run('check',source,.5)['available'])
            p=Path(d)/'bad.wav';p.write_bytes(b'not an audio file');self.assertFalse(sound.run('check',str(p),.5)['available'])
    def test_play_is_bounded_uses_checked_descriptor_and_clamped_volume(self):
        with tempfile.TemporaryDirectory() as d,patch.object(sound.shutil,'which',return_value='/fake/pw-play'):
            p=self.fixture(d)
            with patch.object(sound.subprocess,'run') as run:
                run.return_value.returncode=0
                result=sound.run('play',str(p),9)
                self.assertEqual(result['state'],'played')
                args=run.call_args.args[0];options=run.call_args.kwargs
                self.assertEqual(args[:3],['/fake/pw-play','--volume','1.0'])
                self.assertIn('--sample-count',args);self.assertTrue(args[-1].startswith('/proc/self/fd/'))
                self.assertEqual(options['timeout'],7);self.assertEqual(len(options['pass_fds']),1)
    def test_player_failure_is_not_reported_as_success(self):
        with tempfile.TemporaryDirectory() as d,patch.object(sound.shutil,'which',return_value='/fake/pw-play'):
            with patch.object(sound.subprocess,'run') as run:
                run.return_value.returncode=1
                result=sound.run('play',str(self.fixture(d)),.5)
                self.assertEqual(result['state'],'error');self.assertFalse(result['available'])

    def test_cancelling_helper_reaps_only_its_mock_player(self):
        with tempfile.TemporaryDirectory() as d:
            folder=Path(d);binary=folder/'bin';binary.mkdir();marker=folder/'pid'
            player=binary/'pw-play';player.write_text('#!/usr/bin/python3\nimport os,time,pathlib\npathlib.Path(os.environ["SOUND_MOCK_PID"]).write_text(str(os.getpid()))\ntime.sleep(30)\n');player.chmod(0o755)
            env=dict(os.environ,PATH=str(binary)+':'+os.environ['PATH'],SOUND_MOCK_PID=str(marker))
            process=subprocess.Popen([os.sys.executable,str(ROOT/'src/libexec/notification-sound.py'),'play',str(self.fixture(d)),'.5'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
            try:
                deadline=time.monotonic()+3
                while not marker.exists() and time.monotonic()<deadline:time.sleep(.02)
                self.assertTrue(marker.exists(),'mock player never started')
                pid=int(marker.read_text());process.terminate();process.communicate(timeout=3)
                with self.assertRaises(ProcessLookupError):os.kill(pid,0)
            finally:
                if process.poll() is None:process.kill();process.communicate(timeout=3)
