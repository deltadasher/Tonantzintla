import QtQuick
import QtQuick.Window
import Quickshell
import "modules/aperture"

// Isolated rendering harness, not a live settings entrypoint.
Window {
    id: root
    visible: true
    width: 860; height: 710
    Rectangle { anchors.fill: parent; color: "#17141e" }
    DockSettings {
        id: panel
        anchors.fill: parent; anchors.margins: 24
        outputName: "preview"
        page: Quickshell.env("TONANTZINTLA_DOCK_PAGE") || "apps"
    }
    Timer {
        interval: 500; running: true
        onTriggered: root.contentItem.grabToImage(function(result) {
            result.saveToFile(Quickshell.env("TONANTZINTLA_DOCK_PREVIEW"));
            Qt.quit();
        })
    }
}
