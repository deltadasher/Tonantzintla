"""Render real ThemeMark consumers: visible artwork fits, stays transparent, and keeps its colors."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ThemeMarkRenderTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_approved_shapes_fill_bar_slots_without_backing_in_both_modes(self):
        from PIL import Image
        registry = (ROOT/'src/quickshell/components/ThemeIdentities.js').read_text()
        marks = json.loads(registry.split('var identities = ', 1)[1].strip().rstrip(';'))
        jobs = [dict(identity=mark['id'], mode=mode, w=w, h=h)
                for mark in marks for mode in ('light', 'dark') for w,h in ((28,20),(34,34))]
        with tempfile.TemporaryDirectory(prefix='theme-mark-render-') as directory:
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory, XDG_CACHE_HOME=directory,
                       XDG_STATE_HOME=directory, XDG_DATA_HOME=directory, XDG_RUNTIME_DIR=directory,
                       QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent', DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent')
            for key in ('WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key, None)
            qml = '''import QtQuick
import "."
import "components"
Window {
 id: window; width: 100; height: 100; visible: true
 property var jobs: JOBS
 property int index: -1
 Item { id: capture; width: 48; height: 40
  ThemeMark { id: mark; anchors.centerIn: parent }
 }
 function advance() {
  index++;
  if(index===jobs.length) { Qt.quit(); return; }
  const job=jobs[index]; Settings.themeMode=job.mode;
  mark.identity=job.identity; mark.width=job.w; mark.height=job.h;
  settle.start();
 }
 Timer { interval:30;running:true;repeat:true;onTriggered:{
  if(!Settings.persistenceReady)return;
  stop();Settings.motion=false;Settings.adaptivePalette=false;window.advance();
 }}
 Timer { id:settle;interval:40;onTriggered:capture.grabToImage(function(result){
  result.saveToFile("OUTPUT/"+window.index+".png");window.advance();
 }) }
 Timer { interval:12000;running:true;onTriggered:Qt.exit(2) }
}
'''.replace('JOBS',json.dumps(jobs)).replace('OUTPUT',directory)
            with tempfile.NamedTemporaryFile('w', suffix='.qml', dir=ROOT/'src/quickshell') as harness:
                harness.write(qml);harness.flush()
                result=subprocess.run(['qs','-p',harness.name,'--no-color'],env=env,capture_output=True,text=True,timeout=15)
            output=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,output)
            for error in ('TypeError','ReferenceError','Unable to assign','Binding loop','Failed to load configuration'):
                self.assertNotIn(error,output)
            images={}
            for index,job in enumerate(jobs):
                with self.subTest(**job):
                    image=Image.open(Path(directory)/f'{index}.png').convert('RGBA')
                    alpha=image.getchannel('A');bounds=alpha.point(lambda v:255 if v>20 else 0).getbbox()
                    self.assertIsNotNone(bounds)
                    dpr=image.width/48
                    x,y,x2,y2=[value/dpr for value in bounds]
                    self.assertLessEqual(abs((x+x2)/2-24),1)
                    self.assertLessEqual(abs((y+y2)/2-20),1)
                    self.assertGreaterEqual(max((x2-x)/job['w'],(y2-y)/job['h']),.88)
                    self.assertLessEqual(x2-x,job['w']+1)
                    self.assertLessEqual(y2-y,job['h']+1)
                    # No square badge: a substantial part of each fitted art rectangle remains transparent.
                    box=alpha.crop(bounds);empty=sum(box.histogram()[:10])
                    self.assertGreater(empty/(box.width*box.height),.13)
                    self.assertEqual(alpha.getpixel((0,0)),0)
                    key=(job['identity'],job['w'],job['h'])
                    if job['mode']=='light':images[key]=image.tobytes()
                    else:self.assertEqual(image.tobytes(),images[key], 'desktop mode altered the approved icon')
