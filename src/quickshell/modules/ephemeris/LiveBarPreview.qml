import QtQuick
import Quickshell
import "../.."
import "../aperture"
import "../../services"

Rectangle {
    id: root
    radius: Theme.radiusLarge
    color: Theme.mantle
    clip: true
    readonly property var previewScreen: Quickshell.screens.find(function(screen) {
        return screen.name === Compositor.focusedOutput;
    }) || Quickshell.screens[0]
    readonly property real desktopWidth: previewScreen ? previewScreen.width : 1920
    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 12
        text: "YOUR BAR · LIVE (" + Settings.barPosition.toUpperCase() + ")"
        color: Theme.muted
        font.family: Theme.fontMono
        font.pixelSize: 10
    }
    ApertureContents {
        previewMode: true
        width: root.desktopWidth
        height: implicitHeight
        x: 12
        y: 38
        scale: Math.min(1, (root.width - 24) / width)
        transformOrigin: Item.TopLeft
        outputName: root.previewScreen ? root.previewScreen.name : ""
        // These are the running bar's components, not a second PanelWindow.
        // Disable input so the miniature cannot launch or alter anything.
        enabled: false
    }
}
