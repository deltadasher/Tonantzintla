import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/modules/ephemeris"
Window {
    id: window
    width: 1686; height: 1348; visible: true; color: "#080910"
    property int step: 0
    property int failures: 0
    function check(ok, label) { if (!ok) { failures++; console.error("PLACEMENT FAIL", label); } }
    function body() { return overlay.children.find(function(child) { return child.widgetId !== undefined; }); }
    function bounded(label) {
        const card = body();
        check(card !== undefined, "context body exists");
        check(card.x >= 0 && card.y >= 0 && card.x + card.width <= overlay.width && card.y + card.height <= overlay.height, label);
    }
    Item {
        id: viewport
        x: 16; y: 76; width: window.width - 32; height: window.height - 92
        WidgetQuickSettings { id: overlay; modelData: ({name: "fixture"}); viewportOrigin: Qt.point(viewport.x, viewport.y) }
    }
    Timer {
        interval: 150; repeat: true; running: true
        onTriggered: {
            if (!Settings.persistenceReady) return;
            if (window.step === 0) {
                ShellState.openWidgetSettings("media", 322, 330, 1040, 680, "fixture");
            } else if (window.step === 1) {
                window.bounded("wide popup remains in safe viewport");
                const card = window.body(), panel = overlay.instrumentRect;
                const overlapWidth = Math.max(0, Math.min(card.x + card.width, panel.x + panel.width) - Math.max(card.x, panel.x));
                const overlapHeight = Math.max(0, Math.min(card.y + card.height, panel.y + panel.height) - Math.max(card.y, panel.y));
                window.check(overlapWidth * overlapHeight < 100 * card.height, "fallback uses empty margins instead of covering the orbit");
                window.width = 800; window.height = 600;
                ShellState.openWidgetSettings("media", 1116, 876, 800, 680, "fixture");
            } else if (window.step === 2) {
                window.bounded("stale instrument bounds cannot push popup outside resized output");
                window.width = 320; window.height = 280;
                ShellState.openWidgetSettings("calendar", 16, 76, 288, 188, "fixture");
            } else if (window.step === 3) {
                window.bounded("320px short viewport stays bounded");
                window.width = 1200; window.height = 900;
                ShellState.openWidgetSettings("apps", 100, 150, 300, 400, "fixture");
            } else {
                window.bounded("spacious placement stays bounded");
                const card = window.body(), panel = overlay.instrumentRect;
                window.check(card.x >= panel.x + panel.width || card.x + card.width <= panel.x || card.y >= panel.y + panel.height || card.y + card.height <= panel.y, "no overlap when popup can fit outside");
                console.log("PLACEMENT COMPLETE", window.failures, "failures"); Qt.quit();
            }
            window.step++;
        }
    }
}
