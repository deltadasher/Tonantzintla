import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

class UmbraPreviewTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_editor_roundtrip_and_native_render_without_lock(self):
        repo=Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory(prefix='umbra-editor-') as directory:
            capture=Path(directory)/'preview.png'
            env=dict(os.environ,HOME=directory,XDG_STATE_HOME=directory,XDG_DATA_HOME=directory,
                QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',
                XDG_RUNTIME_DIR=directory,XDG_CONFIG_HOME=directory,XDG_CACHE_HOME=directory,
                UMBRA_CAPTURE=str(capture),UMBRA_SURFACE_SOURCE=(repo/'src/quickshell/modules/umbra/UmbraSurface.qml').as_uri(),UMBRA_EDITOR_SOURCE=(repo/'src/quickshell/modules/umbra/UmbraLayoutEditor.qml').as_uri())
            env.pop('WAYLAND_DISPLAY',None);env.pop('NIRI_SOCKET',None)
            result=subprocess.run(['qs','-p',str(repo/'src/quickshell/preview-umbra-layout.qml'),'--no-color'],
                env=env,capture_output=True,text=True,timeout=15)
            output=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,output)
            self.assertIn('UMBRA_PREVIEW_OK',output)
            for error in ('UMBRA_PREVIEW_FAILED','Binding loop','ReferenceError','TypeError','Unable to assign'):
                self.assertNotIn(error,output)
            self.assertGreater(capture.stat().st_size,1000)

    @unittest.skipUnless(shutil.which('qs') and shutil.which('ffmpeg') and shutil.which('ffprobe'), 'Optional video tools unavailable')
    def test_prepared_loop_unloads_over_repeated_preview_cycles(self):
        repo=Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory(prefix='umbra-video-') as directory:
            video=Path(directory)/'fixture with spaces.mp4'
            subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','color=c=blue:s=320x180:r=12',
                '-t','1','-c:v','mpeg4',str(video)],check=True,capture_output=True,timeout=10)
            env=dict(os.environ,HOME=directory,XDG_STATE_HOME=directory,XDG_DATA_HOME=directory,
                QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',
                XDG_RUNTIME_DIR=directory,XDG_CONFIG_HOME=directory,XDG_CACHE_HOME=directory,
                UMBRA_TEST_VIDEO=str(video))
            env.pop('WAYLAND_DISPLAY',None);env.pop('NIRI_SOCKET',None)
            result=subprocess.run(['qs','-p',str(repo/'src/quickshell/preview-umbra-media.qml'),'--no-color'],
                env=env,capture_output=True,text=True,timeout=20)
            output=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,output)
            self.assertIn('UMBRA_VIDEO_OK 5',output)
            self.assertNotIn('UMBRA_VIDEO_FAILED',output)
            self.assertNotIn('qt.multimedia',output.lower())
            self.assertNotIn('qs-blackhole',output)
            self.assertNotIn('ReferenceError',output)

    @unittest.skipUnless(shutil.which('qs') and shutil.which('ffmpeg') and shutil.which('ffprobe'), 'Optional video tools unavailable')
    def test_same_path_video_is_rechecked_after_replacement_and_repair(self):
        repo=Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory(prefix='umbra-validation-') as directory:
            valid=Path(directory)/'valid.mp4'
            oversize=Path(directory)/'oversize.mp4'
            current=Path(directory)/'current.mp4'
            for path,size in ((valid,'320x180'),(oversize,'1920x1080')):
                subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i',f'color=c=blue:s={size}:r=12',
                    '-frames:v','1','-c:v','mpeg4',str(path)],check=True,capture_output=True,timeout=10)
            shutil.copyfile(valid,current)
            env=dict(os.environ,HOME=directory,XDG_STATE_HOME=directory,XDG_DATA_HOME=directory,
                QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',
                XDG_RUNTIME_DIR=directory,XDG_CONFIG_HOME=directory,XDG_CACHE_HOME=directory,
                UMBRA_TEST_VIDEO=str(current),UMBRA_TEST_VALID=str(valid),UMBRA_TEST_OVERSIZE=str(oversize))
            env.pop('WAYLAND_DISPLAY',None);env.pop('NIRI_SOCKET',None)
            result=subprocess.run(['qs','-p',str(repo/'src/quickshell/preview-umbra-validation.qml'),'--no-color'],
                env=env,capture_output=True,text=True,timeout=15)
            output=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,output)
            self.assertIn('UMBRA_VALIDATION_OK',output)
            self.assertNotIn('UMBRA_VALIDATION_FAILED',output)
