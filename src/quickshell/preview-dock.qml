import QtQuick
import QtQuick.Window
import Quickshell
import "components"
import "modules/aperture"

Window {
    id: root
    width: 900; height: 340
    visible: true
    color: "#292438"
    Text { x: 36; y: 30; text: "APERTURE / EDGE DOCK"; color: "#cfbaff"; font.pixelSize: 20 }
    Text { x: 36; y: 65; text: "A fluid extension of the screen edge · no floating frame"; color: "#b6abc9"; font.pixelSize: 14 }
    DockFluidSurface { x: 215; y: 234; width: 470; height: 106; reveal: 1 }
    Row {
        x: 250; y: 248
        spacing: 8
        Repeater {
            model: ["⊞", "◷", "♫", "✦", "⌕", "⚙"]
            DockAppButton { required property string modelData; width: 58; height: 66; glyph: modelData; name: "Preview"; running: modelData === "♫"; active: running }
        }
    }
    Timer {
        interval: 400; running: true
        onTriggered: root.contentItem.grabToImage(function(result) {
            result.saveToFile(Quickshell.env("TONANTZINTLA_DOCK_PREVIEW"));
            Qt.quit();
        })
    }
}
