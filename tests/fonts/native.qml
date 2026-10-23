import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/components"
import "../../src/quickshell/services"
Window {
    width: 760; height: 180; visible: true; color: "#080910"
    property int failures: 0
    function check(value, message) { if (!value) { failures++; console.error("ICON FAIL", message); } }
    function inspect(item) {
        if (item.font && item.text !== undefined) {
            const text = String(item.text);
            if (["⌕", "⚙", "✦", "⊞", "▭", "◉", "♪", "‹", "Ⅱ", "▶", "›"].indexOf(text) >= 0) {
                check(item.font.family === Theme.iconFamily(text), "icon family for " + text);
                check(item.font.weight === Font.Normal, "regular icon weight for " + text);
            }
            if (text === "Orbital light") {
                check(item.font.family === Settings.fontText, "title retains configured text family");
                check(item.font.weight === Font.DemiBold, "title retains text emphasis");
            }
        }
        if (item.children) for (const child of item.children) inspect(child);
    }
    Column {
        id: scene; anchors.centerIn: parent; spacing: 16
        Row { spacing: 12; Repeater { model: ["⌕", "⚙", "✦", "⊞", "▭", "◉"]
            BarButton { required property string modelData; glyph: modelData }
        } }
        MediaPill { id: media; width: 460; height: 42 }
    }
    Timer {
        interval: 900; running: true
        onTriggered: {
            check(Theme.iconFontReady, "bundled font ready before icon resolution");
            check(Theme.iconFamily("⚙") === "Tonantzintla Symbols", "known glyph uses subset");
            check(Theme.iconFamily("ϟ") === Settings.fontIcon, "weather fallback stays configured family");
            check(Theme.iconFamily(String.fromCodePoint(0xf0001)) === Settings.fontIcon, "unknown icon stays configured family");
            check(Media.available, "private media fixture connected");
            inspect(scene);
            scene.grabToImage(function(result) { check(result.saveToFile(Quickshell.env("ICON_SCREENSHOT")), "native capture"); console.log("ICON COMPLETE", failures, "failures"); });
        }
    }
    Timer { interval: 2200; running: true; onTriggered: Qt.quit() }
}
