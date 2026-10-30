import QtQuick
import QtQuick.Window
import Quickshell
import "."
import "components"
import "modules/aperture/islands"
import "modules/ephemeris/widgets/desktop"
Window {
    id: window
    width: 1000; height: 800; visible: true
    property int failures: 0
    property real phaseBefore: 0
    function check(value, message) { if (!value) { failures++; console.error("UI FAIL", message); } }
    BarButton { id: barButton; glyph: "" }
    StatusPill { id: statusPill; code: ""; value: "" }
    function hasVisibleOptical(item) {
        if (item.shaderActive !== undefined && item.visible) return true;
        for (const child of item.children || []) if (hasVisibleOptical(child)) return true;
        return false;
    }
    TrayIsland { id: tray }
    OpticalSurface { id: optical; width: 100; height: 40; material: "etched" }
    WallpaperWidget { id: wallpaper; width: 900; height: 700 }
    Timer { interval: 500; running: true; onTriggered: {
        Settings.motion = true;
        window.check(!window.hasVisibleOptical(barButton) && !window.hasVisibleOptical(statusPill), "bar buttons have no optical button surface");
        window.check(!tray.islandVisible && tray.implicitWidth === 0, "empty tray should collapse");
        window.check(optical.border.width === 0, "unfocused optical controls have no outline");
        wallpaper.hoveredSatellite = 0;
        window.phaseBefore = wallpaper.ambientPhase;
        finish.start();
    } }
    Timer { id: finish; interval: 700; onTriggered: {
        window.check(wallpaper.ambientPhase !== window.phaseBefore, "orbit moves while a satellite is hovered");
        console.log("UI REGRESSIONS COMPLETE", window.failures);
        Qt.exit(window.failures ? 1 : 0);
    } }
    Timer { interval: 8000; running: true; onTriggered: Qt.exit(2) }
}
