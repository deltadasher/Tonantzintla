"""Exercise the real output host's reactive native QML membership/lifetimes."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / 'src/quickshell'


class ApertureOutputLifetimeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_occupied_edges_edit_targets_and_dock_lifetime(self):
        with tempfile.TemporaryDirectory(prefix='aperture-membership-') as directory:
            folder = Path(directory)
            (folder / 'tonantzintla').mkdir()
            (folder / 'tonantzintla/settings.json').write_text(json.dumps({
                'clipboardPaused': True, 'motion': False, 'weatherEnabled': False,
                'dockEnabled': False, 'barPosition': 'top',
                'barLayoutHorizontal': json.dumps({'start': ['clock'], 'center': [], 'end': []})}))
            # Only the platform-specific native window leaves are substituted;
            # Variants, its delegate lifetimes and Settings remain production QML.
            source = (QML / 'modules/aperture/ApertureOutput.qml').read_text()
            source = source.replace('import "../.."', 'import "file://' + str(QML) + '"')
            (folder / 'ApertureOutput.qml').write_text(source)
            (folder / 'qmldir').write_text('singleton Tracker 1.0 Tracker.qml\nApertureOutput 1.0 ApertureOutput.qml\nApertureBar 1.0 ApertureBar.qml\nApertureDock 1.0 ApertureDock.qml\n')
            (folder / 'Tracker.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    property var live: ({})
    property int serial: 0
    function add(key) { const next=Object.assign({},live);next[key]=++serial;live=next; }
    function remove(key) { const next=Object.assign({},live);delete next[key];live=next; }
}
''')
            for component in ['ApertureBar', 'ApertureDock']:
                bar = component == 'ApertureBar'
                (folder / (component + '.qml')).write_text('''import QtQuick
import Quickshell
Scope {
    required property var modelData
    %s
    readonly property string key: modelData.name + ":" + %s
    Component.onCompleted: Tracker.add(key)
    Component.onDestruction: Tracker.remove(key)
}
''' % ('required property string edge' if bar else '', 'edge' if bar else '"dock"'))
            (folder / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "file://QML_PATH"
import "."
ShellRoot {
    id: root
    property int stage: 0
    property int failures: 0
    property int retainedTop: 0
    QtObject { id: screen; property string name: "fixture" }
    ApertureOutput { modelData: screen }
    function check(ok,text) { if(!ok) { failures++;console.error("MEMBERSHIP FAIL",text,JSON.stringify(Tracker.live)); } }
    function keys(expected) { check(Object.keys(Tracker.live).sort().join(",")===expected.sort().join(","),"expected "+expected); }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if(root.stage===0) {
                root.keys(["fixture:top"]);root.retainedTop=Tracker.live["fixture:top"];
                ShellState.barEditMode=true;
            } else if(root.stage===1) {
                root.keys(["fixture:top","fixture:right","fixture:bottom","fixture:left"]);
                root.check(Tracker.live["fixture:top"]===root.retainedTop,"retained occupied edge identity entering edit");
                Settings.barIslandPlacements=JSON.stringify({fixture:{clock:{edge:"left",zone:"start",order:0}}});
            } else if(root.stage===2) {
                root.keys(["fixture:top","fixture:right","fixture:bottom","fixture:left"]);
                ShellState.barEditMode=false;
            } else if(root.stage===3) {
                root.keys(["fixture:left"]);
                Settings.dockOutput="*";Settings.dockEnabled=true;
            } else if(root.stage===4) {
                root.keys(["fixture:left","fixture:dock"]);
                Settings.dockOutput=Quickshell.screens[0].name;
            } else if(root.stage===5) {
                root.keys(["fixture:left"]);
                Settings.dockOutput="*";
            } else if(root.stage===6) {
                root.keys(["fixture:left","fixture:dock"]);
                Settings.dockEnabled=false;
            } else if(root.stage===7) {
                root.keys(["fixture:left"]);
                Settings.barIslandPlacements="{}";
            } else if(root.stage===8) {
                root.keys(["fixture:top"]);
                root.check(Tracker.live["fixture:top"]!==root.retainedTop,"removed host was destroyed and reconstructed");
                console.log("MEMBERSHIP COMPLETE",root.failures,"failures");Qt.quit();
            }
            root.stage++;
        }
    }
}
'''.replace('QML_PATH', str(QML)))
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory,
                       XDG_CACHE_HOME=directory, XDG_STATE_HOME=directory,
                       XDG_DATA_HOME=directory, XDG_RUNTIME_DIR=directory,
                       QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
            for key in ('WAYLAND_DISPLAY', 'NIRI_SOCKET', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key, None)
            result = subprocess.run(['qs', '-p', str(folder / 'shell.qml'), '--no-color'],
                                    env=env, capture_output=True, text=True, timeout=12)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('MEMBERSHIP COMPLETE 0 failures', output)
            for bad in ('MEMBERSHIP FAIL', 'ReferenceError', 'TypeError', 'Binding loop', 'Unable to assign'):
                self.assertNotIn(bad, output)
