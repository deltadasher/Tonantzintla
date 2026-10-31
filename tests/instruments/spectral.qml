import QtQuick
import QtTest
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/components"
Window {
    id: window
    width: 320; height: 720; visible: true; color: Theme.void_
    property int step: 0
    property int failures: 0
    property bool inTick: false
    function check(ok, label) { if (!ok) { failures++; console.error("SPECTRAL FAIL", label); } }
    function find(item, name) {
        if (item.Accessible && item.Accessible.name === name) return item;
        for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
        return null;
    }
    function press(name) {
        const control = find(panel, name); check(control !== null, "accessible " + name);
        if (!control) return;
        control.forceActiveFocus(); events.keyClick(Qt.Key_Space, Qt.NoModifier, -1);
    }
    function typeColor(value) {
        const editor = find(panel, "Hex color"); check(editor !== null, "editable hex field");
        if (!editor) return;
        editor.forceActiveFocus(); events.keyClick(Qt.Key_A, Qt.ControlModifier, -1);
        for (const character of value) events.keyClickChar(character, Qt.NoModifier, -1);
        events.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
    }
    TestEvent { id: events }
    Item {
        id: scene; anchors.fill: parent
        Rectangle { anchors.fill: parent; color: Theme.void_ }
        SpectralControls { id: panel; x: 12; y: 12; width: window.width - 24 }
    }
    Timer {
        interval: 180; running: true; repeat: true
        onTriggered: {
            if (window.inTick || !Settings.persistenceReady) return;
            window.inTick = true;
            try {
                if (window.step === 0) {
                    window.requestActivate(); Settings.spectralColors = {}; Settings.checkpointAppearance();
                    typeColor("#ffeedd");
                    window.check(String(Theme.accent) === "#ffeedd", "valid input changes live theme");
                    window.check(Settings.canUndoAppearance, "palette included in appearance undo");
                    typeColor("#797979");
                    window.check(String(Theme.accent) === "#797979" && panel.statusOk, "gray exact accent accepted");
                    typeColor("#080910");
                    window.check(String(Theme.accent) === "#080910", "dark exact accent accepted");
                    window.check(panel.statusOk && Theme.isLight, "dark accent selects contrasting light automatic mode");
                    typeColor("#xyzxyz");
                    window.check(String(Theme.accent) === "#080910" && !panel.statusOk, "invalid hex preserves exact accent");
                    Settings.undoAppearance();
                    window.check(Object.keys(Settings.spectralColors).length === 0, "appearance undo restores palette");
                    typeColor("#080910");
                    press("Reset this channel");
                    window.check(find(panel, "Hex color").text === "#a99cff", "reset discards invalid draft even if effective color did not change");
                } else if (window.step === 1) {
                    press("Channel: Media / signals");
                    press("Use Amber for Media / signals");
                    window.check(String(Theme.rose) === "#e9b872", "swatch changes selected channel");
                    press("Reset this channel");
                    window.check(!Settings.spectralColors.rose && String(Theme.rose) === "#ec8eae", "channel reset restores fallback");
                    press("Channel: Success"); typeColor("#ffffff");
                    press("Channel: Warning"); typeColor("#ffffff");
                    press("Reset all channels");
                    window.check(Object.keys(Settings.spectralColors).length === 0, "reset all clears overrides");
                    press("Channel: Cool telemetry");
                    const swatch = find(panel, "Use Silver for Cool telemetry");
                    events.mouseClick(swatch, swatch.width / 2, swatch.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
                    window.check(String(Theme.cyan) === "#d4d8e8", "native swatch click changes telemetry color");
                } else if (window.step === 2) {
                    window.check(panel.width <= 320 && panel.height <= 696, "compact 320px content fits fixture");
                    const editor = find(panel, "Hex color"); editor.forceActiveFocus();
                    events.keyClick(Qt.Key_Tab, Qt.NoModifier, -1);
                    window.check(window.activeFocusItem !== editor, "native Tab exits editor");
                } else {
                    if (Settings.saveTimer.running || Settings.preferencesLoading) return;
                    stop();
                    scene.grabToImage(function(result) {
                        result.saveToFile(Quickshell.env("SPECTRAL_SCREENSHOT"));
                        console.log("SPECTRAL COMPLETE", window.failures, "failures"); Qt.quit();
                    });
                }
                window.step++;
            } finally { window.inTick = false; }
        }
    }
}
