import QtQuick
import Quickshell
import "../../src/quickshell"

Window {
    id: window
    visible: true
    width: Number(Quickshell.env("BAR_WIDTH") || "830")
    height: editor ? editor.implicitHeight + 110 : 600
    color: "#201d23"
    Rectangle { anchors.fill: parent; color: window.color }
    property var editor: null
    property var button: null
    property var logo: null
    function check(ok, message) { if (!ok) console.error("BAR_FAILED", message); }
    function create(path, parent, props) {
        const component = Qt.createComponent(Quickshell.env("BAR_ROOT") + "/" + path);
        if (component.status !== Component.Ready) { console.error("BAR_FAILED", component.errorString()); Qt.quit(); return null; }
        const result = component.createObject(parent, props);
        check(result !== null, "create " + path);
        return result;
    }
    Component.onCompleted: {
        editor = create("modules/ephemeris/IslandArrangementEditor.qml", contentItem, {x: 14, y: 14, width: width - 28});
        if (!editor) return;
        const styles = [["", "orbit", "guide"], ["⌕", "lens", "apps"], ["✦", "star", "walls"], ["⚙", "gear", "settings"], ["⊞", "workspace", "workspaces"]];
        styles.forEach(function(style, index) {
            const item = create("components/BarButton.qml", contentItem, {
                x: 20 + index * 52, y: Qt.binding(function() { return editor.implicitHeight + 32; }),
                glyph: style[0], motionKind: style[1], targetPanel: style[2]});
            if (index === 0) button = item;
        });
        if (!button) return;
        logo = create("components/WabiSabiBlackHole.qml", button.iconContents[0].parent,
                      {x: 6, y: 10, width: 28, height: 20, diskColor: Theme.accent, horizonColor: Theme.void_});
        Settings.resetBarLayout(false);
        Settings.barPosition = "top";
        editor.selection = "clock";
        editor.place("start");
        check(editor.selectedLocation.zone === "start" && editor.canUndo, "transfer/Undo state");
        editor.undo();
        check(editor.selectedLocation.zone === "center" && Settings.barLayoutHorizontal === "", "Undo restores default representation");
        editor.place("end");
        Settings.barLayoutHorizontal = JSON.stringify({start: ["launcher"], center: ["clock"], end: ["controls"]});
        check(!editor.canUndo, "external changes invalidate Undo");
        editor.selection = "controls";
        editor.place("center");
        editor.move(-1);
        check(editor.currentLayout.center.join(",") === "controls,clock", "reorder center zone");
        const horizontalBefore = Settings.barLayoutHorizontal;
        Settings.barPosition = "left";
        check(!editor.canUndo, "orientation change invalidates Undo");
        editor.selection = "clock";
        editor.place("end");
        check(Settings.barLayoutHorizontal === horizontalBefore, "vertical moves preserve horizontal layout");
        Settings.barPosition = "top";
        Settings.resetBarLayout(false);

        // Test addIslandToZone and removeIslandFromLayout
        Settings.addIslandToZone(false, "start", "tray", 0);
        check(Settings.activeLayoutHorizontal.start[0] === "tray", "addIslandToZone prepends tray");
        Settings.removeIslandFromLayout(false, "tray");
        check(Settings.activeLayoutHorizontal.start.indexOf("tray") === -1, "removeIslandFromLayout removes tray");

        // Test per-output overrides
        check(Settings.getEffectiveBarPosition("DP-1") === "top", "fallback position");
        Settings.setOutputOverride("DP-1", "barPosition", "bottom");
        check(Settings.getEffectiveBarPosition("DP-1") === "bottom", "overridden position");
        check(Settings.getEffectiveBarPosition("HDMI-A-1") === "top", "other output retains fallback");
        Settings.clearOutputOverrides("DP-1");
        check(Settings.getEffectiveBarPosition("DP-1") === "top", "cleared override reverts to fallback");

        // Test barEditMode state machine
        check(!ShellState.barEditMode, "barEditMode defaults to false");
        ShellState.enterBarEditMode();
        check(ShellState.barEditMode, "enterBarEditMode activates");
        ShellState.exitBarEditMode();
        check(!ShellState.barEditMode, "exitBarEditMode deactivates");
        ShellState.toggleBarEditMode();
        check(ShellState.barEditMode, "toggleBarEditMode activates");
        ShellState.toggleBarEditMode();
        check(!ShellState.barEditMode, "toggleBarEditMode deactivates");

        editor.selection = "clock";
        Settings.barIconMotion = true;
        Settings.motion = true;
        ShellState.ephemerisTab = "guide";
        ShellState.ephemerisVisible = true;
        check(button.panelOpen, "button tracks panel state");
        pulseCheck.start();
    }
    Timer {
        id: pulseCheck; interval: 80
        onTriggered: {
            check(button.iconPulse > 0, "panel opening animates icon");
            check(button.scale === 1 && button.rotation === 0, "hit target stays stationary");
            check(logo.parent.scale !== 1, "custom logo is animated too");
            Settings.barIconMotion = false;
            check(button.iconPulse === 0 && !button.motionAllowed, "motion toggle stops animation");
            Settings.barIconMotion = true;
            Settings.motion = false;
            check(!button.motionAllowed, "global reduced motion respected");
            Settings.motion = true;
            Settings.motionSpeedProfile = "instant";
            check(!button.motionAllowed, "instant motion profile respected");
            ShellState.ephemerisVisible = false;
            capture.start();
        }
    }
    Timer {
        id: capture; interval: 250
        onTriggered: {
            if (!Quickshell.env("BAR_IMAGE")) { console.log("BAR_LAYOUT_OK"); Qt.quit(); return; }
            window.contentItem.grabToImage(function(result) {
                check(result.saveToFile(Quickshell.env("BAR_IMAGE")), "save preview");
                console.log("BAR_LAYOUT_OK"); Qt.quit();
            });
        }
    }
}
