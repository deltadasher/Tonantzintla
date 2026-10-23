"""Exercise the real wallpaper state machine in an isolated native QQuickWindow.

Only the LayerShell wrapper is replaced for offscreen CI; no session wallpaper
service, lock or compositor is accessed. The GPU/LayerShell memory experiment is
recorded separately in work/reports/native-wallpaper.md.
"""
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]


def png(path, width, height, color):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    data = b''.join(b'\0' + bytes(color) * width for _ in range(height))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(data)) + chunk(b'IEND', b''))


class NativeWallpaperSurfaceTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_prepared_sizes_proxy_replacement_failure_and_unload(self):
        qmlroot = ROOT / 'src/quickshell'
        source = (qmlroot / 'components/NativeWallpaper.qml').read_text()
        source = source.replace('PanelWindow {', 'Window {\n width: 640; height: 360; visible: true')
        for line in ['    screen: modelData\n', '    anchors { top: true; bottom: true; left: true; right: true }\n', '    exclusionMode: ExclusionMode.Ignore\n', '    WlrLayershell.layer: WlrLayer.Background\n', '    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None\n', '    WlrLayershell.namespace: "tonantzintla-wallpaper"\n', '    mask: Region {}\n']:
            source = source.replace(line, '')
        with tempfile.TemporaryDirectory(prefix='native-wall-surface-') as directory:
            tmp = Path(directory)
            for name, size, color in [('a',(960,540),(180,20,30)),('b',(320,240),(10,160,30)),('proxy',(512,288),(180,20,30))]:
                png(tmp / (name+'.png'), *size, color)
            env = dict(os.environ, HOME=directory, XDG_RUNTIME_DIR=directory,
                       XDG_CONFIG_HOME=directory, XDG_CACHE_HOME=directory, XDG_STATE_HOME=directory,
                       QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent', DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent')
            for key in ('WAYLAND_DISPLAY','NIRI_SOCKET'): env.pop(key,None)
            with tempfile.NamedTemporaryFile(mode='w', prefix='NativeWallpaperCheck',suffix='.qml',dir=qmlroot/'components') as component, tempfile.NamedTemporaryFile(mode='w',prefix='native-wall-check-',suffix='.qml',dir=qmlroot) as fixture:
                component.write(source); component.flush()
                fixture.write('''import QtQuick
import Quickshell
ShellRoot {
 property var surface
 property int step: 0
 property int ticks: 0
 property int acks: 0
 property int failures: 0
 function check(ok, message) { if (!ok) { console.error("WALL_FAIL", message); Qt.exit(1); } }
 Component.onCompleted: {
  const c=Qt.createComponent("COMPONENT"); check(c.status===Component.Ready,c.errorString());
  surface=c.createObject(null,{modelData:{name:"fixture"},preparedPath:"BASE/a.png",preparedWidth:960,preparedHeight:540,transitionPreview:"BASE/proxy.png",transitionWidth:512,transitionHeight:288,motionEnabled:false,generation:1});
  check(!!surface,"created"); surface.sourcePresented.connect(function(){acks++}); surface.sourceFailed.connect(function(output,generation,message){check(output==="fixture" && generation>=3 && message.length>0,"failure generation");failures++});
 }
 Timer { interval:20; running:true; repeat:true; onTriggered: {
  ticks++; if(ticks>250){console.error("WALL_FAIL timeout",step,surface.phase);Qt.exit(2);}
  if(step===0 && surface.ready){
   check(surface.loadedImageCount===1,"one idle image");
   check(surface.stableImage.implicitWidth===960 && surface.stableImage.implicitHeight===540,"exact small decode");
   check(acks===1 && surface.presentedGeneration===1,"actual frame ack");
   surface.preparedWidth=320;surface.preparedHeight=240;surface.preparedPath="BASE/b.png";surface.generation=2;step++;
  } else if(step===1 && surface.ready && surface.presentedGeneration===2){
   check(surface.loadedImageCount===1 && !surface.transitioning,"proxy destroyed reduced motion");
   check(surface.stableImage.implicitWidth===320 && surface.stableImage.implicitHeight===240,"replacement dimensions");
   surface.preparedPath="BASE/missing.png";surface.generation=3;step++;
  } else if(step===2 && surface.failedPath.length && surface.phase==="stable"){
   check(surface.stablePath==="BASE/b.png" && !surface.ready,"last good restored, failed generation unacknowledged");
   check(surface.stableImage.status===Image.Ready,"restored image decoded");
   check(failures===1,"one actionable failure");
   surface.preparedPath="BASE/a.png";surface.preparedWidth=960;surface.preparedHeight=540;surface.generation=4;step++;
  } else if(step===3 && surface.ready){
   check(surface.presentedGeneration===4,"recovery acknowledged");
   surface.transitionPreview="BASE/missing-proxy.png";surface.generation=5;step++;
  } else if(step===4 && surface.ready && surface.presentedGeneration===5){
   surface.preparedPath="BASE/b.png";surface.generation=6;step++;
  } else if(step===5 && surface.failedPath.length && failures===2){
   check(surface.stablePath==="BASE/a.png" && surface.loadedImageCount===1 && surface.stableImage.status===Image.Ready,"corrupt proxy retains full old image");
   surface.preparedPath="BASE/a.png";surface.transitionPreview="";surface.generation=7;step++;
  } else if(step===6 && surface.ready && surface.presentedGeneration===7){
   surface.preparedPath="BASE/b.png";surface.generation=8;step++;
  } else if(step===7 && surface.failedPath.length && failures===3){
   check(surface.stablePath==="BASE/a.png" && surface.loadedImageCount===1 && surface.stableImage.status===Image.Ready,"missing proxy retains full old image");
   surface.preparedPath="";step++;
  } else if(step===8 && surface.loadedImageCount===0){
   check(!surface.ready && surface.phase==="empty","unloaded");surface.destroy();console.log("WALL_COMPLETE 0");Qt.quit();
  }
  check(surface.loadedImageCount<=2,"bounded image slots");
 }}
}
'''.replace('COMPONENT','components/'+Path(component.name).name).replace('BASE',str(tmp)))
                fixture.flush()
                result=subprocess.run(['qs','-n','-p',fixture.name,'--no-color'],env=env,capture_output=True,text=True,timeout=10)
            output=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,output)
            self.assertIn('WALL_COMPLETE 0',output)
            for error in ('WALL_FAIL','TypeError','ReferenceError','Binding loop','Unable to assign'):
                self.assertNotIn(error,output)
