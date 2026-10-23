import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class InstrumentContextTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_native_context_handle_placement_keyboard_and_hidden_lifetime(self):
        repo = Path(__file__).resolve().parents[1]
        fixture = '''import QtQuick
import QtTest
import Quickshell
import "@ROOT@"
Window {
 id: window; width:640; height:480; visible:true
 property int calls:0
 property int stage:0
 property int failures:0
 function check(ok,msg) { if(!ok) { failures++; console.error("CONTEXT FAIL",msg); } }
 TextInput { id: input; x:30;y:220;width:200;height:30;text:"Other control owns focus" }
 TestEvent { id: events }
 Loader { id: handle; source: Quickshell.env("CONTEXT_HANDLE_SOURCE") }
 Timer { interval:150;repeat:true;running:true
  onTriggered: {
   if(window.stage===0) {
    window.check(handle.status===Loader.Ready,"context handle loads");
    if(!handle.item) { console.log("CONTEXT COMPLETE",window.failures);Qt.quit();return; }
    window.check(typeof ShellState.reconcileOutputs === "function", "output disappearance has a cleanup path");
    if (typeof ShellState.reconcileOutputs === "function") {
     ShellState.openEphemeris("calendar","HDMI-A-1",20,20,40,40,"top");
     ShellState.openWidgetSettings("calendar",20,20,300,200,"HDMI-A-1");
     ShellState.reconcileOutputs(["HDMI-A-1","DP-1"]);
     window.check(ShellState.widgetSettingsVisible,"connected output retains context");
     ShellState.reconcileOutputs(["DP-1"]);
     window.check(!ShellState.widgetSettingsVisible && ShellState.activeWidgetSettingsOutput === "", "unplug closes unreachable context");
     window.check(ShellState.ephemerisOutput === "" && !ShellState.ephemerisAnchorValid && ShellState.ephemerisVisible,"instrument falls back without stale anchor");
     ShellState.openWidgetSettings("calendar",20,20,300,200,"DP-1");
     ShellState.openEphemeris("media","DP-1");
     window.check(!ShellState.widgetSettingsVisible,"switching instruments dismisses stale context");
     ShellState.openWidgetSettings("media",20,20,300,200,"DP-1");
     ShellState.closeEphemeris();
     window.check(!ShellState.widgetSettingsVisible,"closing instrument dismisses its context");
    }
    handle.item.panelBounds=Qt.rect(120,100,300,200);handle.item.viewportSize=Qt.size(640,480);
    handle.item.customizationRequested.connect(function(){window.calls++;});
   } else if(window.stage===1) {
    const h=handle.item;
    window.check(h.x>=0 && h.x+h.width<=640 && h.y>=0 && h.y+h.height<=100,"handle stays outside content within viewport");
    window.requestActivate();input.forceActiveFocus();events.keyClick(Qt.Key_F10,Qt.NoModifier,-1);
    window.check(window.calls===1,"F10 works when text input owns focus");
    events.mouseClick(h,h.width/2,h.height/2,Qt.LeftButton,Qt.NoModifier,-1);
    window.check(window.calls===2,"pointer activates same action");
    h.viewportSize=Qt.size(320,200);h.panelBounds=Qt.rect(0,0,320,200);
   } else if(window.stage===2) {
    window.check(!handle.item.visible,"no overlay obscures content when there is no outside room");
    input.forceActiveFocus();events.keyClick(Qt.Key_F10,Qt.NoModifier,-1);
    window.check(window.calls===3,"shortcut remains usable without outside room");
    handle.item.active=false;
   } else {
    events.keyClick(Qt.Key_F10,Qt.NoModifier,-1);window.check(window.calls===3,"inactive instrument releases shortcut");
    console.log("CONTEXT COMPLETE",window.failures);Qt.quit();
   }
   window.stage++;
  }
 }
}
'''
        with tempfile.TemporaryDirectory(prefix='instrument-context-') as directory:
            source = Path(directory) / 'context.qml';source.write_text(fixture.replace("@ROOT@", (repo / "src/quickshell").as_uri()))
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory,
                       XDG_CACHE_HOME=directory, XDG_STATE_HOME=directory, XDG_RUNTIME_DIR=directory,
                       QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       CONTEXT_HANDLE_SOURCE=(repo / 'src/quickshell/components/InstrumentContextHandle.qml').as_uri())
            env.pop('WAYLAND_DISPLAY', None);env.pop('NIRI_SOCKET', None)
            result = subprocess.run(['qs', '-p', str(source), '--no-color'], env=env,
                                    capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertIn('CONTEXT COMPLETE 0', output)
        for error in ('CONTEXT FAIL', 'Binding loop', 'ReferenceError', 'TypeError'):
            self.assertNotIn(error, output)
