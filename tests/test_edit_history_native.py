"""Exercise the real studio with isolated settings and an offscreen window."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class EditHistoryTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_preset_undo_redo_and_external_changes(self):
        studio = ROOT/'src/quickshell/modules/aperture'
        source = (studio/'BarEditStudio.qml').read_text().replace('import QtQuick\n', 'import QtQuick\nimport "."\n', 1)
        source = source.replace('PanelWindow {', 'Window {\n    width: '+os.environ.get('STUDIO_WIDTH','1366')+'; height: 768')
        source = source.replace('required property var modelData', 'property var modelData: Quickshell.screens[0]')
        source = re.sub(r'(?m)^    (screen:|exclusionMode:|focusable:|WlrLayershell\.|anchors \{).*\n', '', source)
        source = re.sub(r'    mask: Region \{.*?\n    \}', '', source, flags=re.S)
        with tempfile.TemporaryDirectory(prefix='studio-history-') as tmp:
            folder=Path(tmp); (folder/'tonantzintla').mkdir()
            (folder/'tonantzintla/settings.json').write_text(json.dumps({'motion':False,'clipboardPaused':True,'weatherEnabled':False}))
            env=dict(os.environ, HOME=tmp, XDG_CONFIG_HOME=tmp, XDG_STATE_HOME=tmp,
                     XDG_CACHE_HOME=tmp, XDG_DATA_HOME=tmp, XDG_RUNTIME_DIR=tmp,
                     QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                     DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
            for key in ('WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key,None)
            with tempfile.NamedTemporaryFile('w',suffix='.qml',dir=studio) as native, tempfile.NamedTemporaryFile('w',suffix='.qml',dir=ROOT/'src/quickshell') as harness:
                native.write(source); native.flush()
                harness.write('''import QtQuick
import Quickshell
import "."
import "./modules/aperture"
import "./modules/aperture/islands"
import "./components"
ShellRoot {
    Loader { id: loader; source: "modules/aperture/'''+Path(native.name).name+'''" }
    property int step: 0
    property var initial
    property var changed
    property int failures: 0
    function check(value, label) { if (!value) { failures++; console.error("HISTORY FAIL",label); } }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (!loader.item || !Settings.persistenceReady) return;
            const editor=loader.item;
            if (step === 0) {
                editor.show();
                initial=editor.layoutSnapshot();
                editor.applyPresetLayout({name:"Test",start:["clock"],center:["media"],end:["tray"]});
                changed=editor.layoutSnapshot();
                check(editor.hasUndo,"preset recorded");
                check(changed.horizontal!==initial.horizontal && changed.vertical!==initial.vertical,"preset changed both axes");
            } else if (step === 1) {
                check(editor.hasUndo,"own persistence preserves history");
                editor.applyUndo();
                check(JSON.stringify(editor.layoutSnapshot())===JSON.stringify(initial),"undo restores entire snapshot");
                check(editor.hasRedo,"redo available");
            } else if (step === 2) {
                editor.applyRedo();
                check(JSON.stringify(editor.layoutSnapshot())===JSON.stringify(changed),"redo restores entire preset");
                editor.removeIsland("clock");
                editor.applyUndo();
                check(JSON.stringify(editor.layoutSnapshot())===JSON.stringify(changed),"second edit undo");
                editor.contentItem.grabToImage(function(result) { result.saveToFile("'''+str(folder/'studio.png')+'''"); });
            } else if (step === 4) {
                Settings.dockEnabled=!Settings.dockEnabled;
                check(!editor.hasUndo && !editor.hasRedo,"external edit invalidates history");
                console.log("HISTORY COMPLETE",failures,"failures"); Qt.quit();
            }
            step++;
        }
    }
    Timer { interval:8000; running:true; onTriggered: { console.error("HISTORY TIMEOUT"); Qt.quit(); } }
}
'''); harness.flush()
                result=subprocess.run(['qs','-p',harness.name,'--no-color'],env=env,capture_output=True,text=True,timeout=12)
            output=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,output)
            self.assertIn('HISTORY COMPLETE 0 failures',output)
            for error in ('HISTORY FAIL','ReferenceError','TypeError','Binding loop','Unable to assign','Failed to load configuration'):
                self.assertNotIn(error,output)
            self.assertTrue((folder/'studio.png').exists(),output)
            self.assertGreater((folder/'studio.png').stat().st_size,3000)
            if os.environ.get('STUDIO_CAPTURE'):
                shutil.copyfile(folder/'studio.png',os.environ['STUDIO_CAPTURE'])
