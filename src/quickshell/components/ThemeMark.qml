// Render the approved artwork in its own colors, independent of Matugen.
import QtQuick
import ".."
import "ThemeIdentity.js" as Identity

Item {
    id: root
    property string identity: Theme.identity.id
    readonly property var mark: Identity.get(identity)
    implicitWidth: 32
    implicitHeight: 32
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        radius: width * .22
        visible: root.mark.light !== Theme.isLight
        color: root.mark.light ? "#f2f1ef" : "#1b1e26"
    }
    Image {
    anchors.fill: parent
    source: Qt.resolvedUrl("../assets/theme-marks/" + root.mark.id + ".svg")
    fillMode: Image.PreserveAspectFit
    sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
    sourceSize.height: Math.ceil(height * Screen.devicePixelRatio)
    smooth: true
    mipmap: true
    }
}
