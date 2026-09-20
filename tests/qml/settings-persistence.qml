//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "../../src/quickshell"
ShellRoot {
    id: root
    property int step: 0
    property string original: ""
    property int failures: 0
    function check(ok, message) { if (!ok) { failures++; console.error("CHECK FAIL",message); } }
    FileView { id: external; path: Settings.configPath }
    Timer {
        interval: 700; running: true; repeat: true
        onTriggered: {
            if (root.step === 0) { root.original = Settings.accentName; Settings.checkpointAppearance(); Settings.accentName = "emerald"; }
            else if (root.step === 1) { root.check(Settings.canUndoAppearance,"local changes can undo after save"); Settings.undoAppearance(); root.check(Settings.accentName === root.original,"undo restores appearance"); }
            else if (root.step === 2) { Settings.checkpointAppearance(); Settings.accentName = "cyan"; }
            else if (root.step === 3) { const data = JSON.parse(Settings.settingsFile.text()); data.accentName = "amber"; external.setText(JSON.stringify(data)); }
            else if (root.step === 4) { root.check(Settings.accentName === "amber","external update applied"); root.check(!Settings.canUndoAppearance,"external update invalidates old undo"); console.log("SETTINGS CHECK COMPLETE",root.failures); Qt.quit(); }
            root.step++;
        }
    }
}
