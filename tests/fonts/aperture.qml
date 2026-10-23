import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/modules/aperture"
Window {
    id: root
    width: 900; height: 100; visible: true
    property int failures: 0
    property int symbols: 0
    property int labels: 0
    function check(value, message) { if (!value) { failures++; console.error("APERTURE FONT FAIL", message); } }
    function inspect(item) {
        if (item.font && item.text !== undefined) {
            const text = String(item.text);
            if (["✦", "⇣"].indexOf(text) >= 0) {
                symbols++;
                console.log("APERTURE SYMBOL", text, item.font.family, item.font.weight, item.visible);
                check(item.font.family === Theme.iconFamily(text), "symbol honors configured icon family");
                check(item.font.weight === Font.Normal, "hidden symbol avoids bold fallback");
            } else if (["START", "CENTER", "END"].indexOf(text) >= 0) {
                labels++;
                check(item.font.family === Settings.fontMono && item.font.bold, "zone label retains typography");
            }
        }
        if (item.children) for (const child of item.children) inspect(child);
    }
    Loader {
        id: loader; anchors.fill: parent
        active: Settings.persistenceReady && !Settings.ensureDirectory.running
        sourceComponent: ApertureContents { outputName: Quickshell.screens[0].name; previewMode: true }
    }
    Timer {
        interval: 800; running: true
        onTriggered: {
            check(loader.status === Loader.Ready, "actual ApertureContents loaded");
            inspect(loader.item);
            check(symbols === 3 && labels === 3, "all three slots inspected");
            console.log("APERTURE FONT COMPLETE", failures, "failures");
        }
    }
    Timer { interval: 1700; running: true; onTriggered: Qt.quit() }
}
