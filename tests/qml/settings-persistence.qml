//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "../../src/quickshell"
import "../../src/quickshell/components/SettingsSearch.js" as Search
ShellRoot {
    id: root
    property int step: 0
    property string original: ""
    property string originalMaterial: ""
    property var originalFinish
    property var originalRadius
    property int failures: 0
    function check(ok, message) { if (!ok) { failures++; console.error("CHECK FAIL",message); } }
    FileView { id: external; path: Settings.configPath }
    Timer {
        interval: 700; running: true; repeat: true
        onTriggered: {
            if (root.step === 0) { root.check(typeof Settings.controlMaterial === "string", "control finish has a persisted preference"); if (typeof Settings.controlMaterial !== "string") { console.log("SETTINGS CHECK COMPLETE",root.failures); Qt.quit(); return; } root.originalFinish = Settings.controlMaterial; root.originalRadius = Settings.controlRadius; root.check(typeof Settings.constellationEnabled === "undefined", "removed desktop feature cannot be reenabled by an old preference"); root.check(Search.search("desktop instruments").length === 0, "settings search has no removed desktop destination"); root.original = Settings.accentName; root.originalMaterial = Settings.panelMaterial; Settings.checkpointAppearance(); Settings.accentName = "emerald"; Settings.panelMaterial = "classic"; Settings.controlMaterial = "lens"; Settings.controlRadius = 17; }
            else if (root.step === 1) { root.check(Settings.canUndoAppearance,"local changes can undo after save"); const saved = JSON.parse(Settings.settingsFile.text()); root.check(!Object.prototype.hasOwnProperty.call(saved,"constellationEnabled") && !Object.prototype.hasOwnProperty.call(saved,"constellationState"), "saving drops retired desktop preferences"); root.check(JSON.parse(Settings.settingsFile.text()).panelMaterial === "classic", "material choice saved"); root.check(saved.controlMaterial === "lens" && saved.controlRadius === 17, "optical finish and geometry reach persisted settings"); Settings.undoAppearance(); root.check(Settings.controlMaterial === root.originalFinish && Settings.controlRadius === root.originalRadius, "appearance undo restores optical settings"); root.check(Settings.panelMaterial === root.originalMaterial,"undo restores material"); root.check(Settings.accentName === root.original,"undo restores appearance"); }
            else if (root.step === 2) { Settings.toolboxState = {notes: [{id:"first", body:"first save"}]}; }
            else if (root.step === 3) { external.reload(); external.waitForJob(); root.check((JSON.parse(external.text()).toolboxState.notes || [])[0]?.body === "first save", "first delayed edit reaches disk"); Settings.toolboxState = {notes: [{id:"first", body:"second save"}]}; }
            else if (root.step === 4) { external.reload(); external.waitForJob(); root.check((JSON.parse(external.text()).toolboxState.notes || [])[0]?.body === "second save", "second delayed edit reaches disk"); root.check(!Settings.preferencesLoading, "self-save does not leave loading latched"); Settings.checkpointAppearance(); Settings.accentName = "cyan"; }
            else if (root.step === 5) { const data = JSON.parse(Settings.settingsFile.text()); data.accentName = "amber"; external.setText(JSON.stringify(data)); }
            else if (root.step === 6) { root.check(Settings.accentName === "amber","external update applied"); root.check(!Settings.canUndoAppearance,"external update invalidates old undo"); console.log("SETTINGS CHECK COMPLETE",root.failures); Qt.quit(); }
            root.step++;
        }
    }
}
