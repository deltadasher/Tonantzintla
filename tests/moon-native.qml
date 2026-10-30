import QtQuick
import Quickshell
import "."
import "modules/ephemeris/widgets/productivity"
Window {
    id: root
    width: 1480; height: 740; visible: true
    property int step: 0
    property var moonCanvas: null
    function find(item) {
        if (item.getContext !== undefined && item.anchors && item.anchors.margins === 7) return item;
        for (const child of item.children || []) { const found = find(child); if (found) return found; }
        return null;
    }
    CalendarWidget { id: calendar; anchors.fill: parent }
    Timer { interval: 500; repeat: true; running: true; onTriggered: {
        if (!Settings.persistenceReady) return;
        if (root.step === 0) {
            Settings.motion = false; Settings.adaptivePalette = false;
            root.moonCanvas = root.find(calendar);
            if (!root.moonCanvas) { console.error("MOON CANVAS MISSING"); Qt.exit(1); return; }
        }
        if (root.step < 8) {
            calendar.selectedDate = new Date(2000, 0, [6, 14, 21, 28, 10, 18, 25, 32][root.step]);
            root.moonCanvas.requestPaint(); capture.restart();
        } else { console.log("MOON COMPLETE"); Qt.exit(0); }
        stop();
    } }
    Timer { id: capture; interval: 180; onTriggered: {
        root.moonCanvas.grabToImage(function(result) {
            result.saveToFile(Quickshell.env("MOON_CAPTURE") + root.step + ".png");
            root.step++; next.start();
        });
    } }
    Timer { id: next; interval: 80; onTriggered: {
        if (root.step >= 8) { console.log("MOON COMPLETE"); Qt.exit(0); return; }
        calendar.selectedDate = new Date(2000, 0, [6, 14, 21, 28, 10, 18, 25, 32][root.step]);
        root.moonCanvas.requestPaint(); capture.restart();
    } }
    Timer { interval: 8000; running: true; onTriggered: Qt.exit(2) }
}
