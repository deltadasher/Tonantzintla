import QtQuick
import ".."

Item {
    id: root

    property string module: "apps"
    property real presentation: 1
    readonly property color tone: Theme.moduleAccent(module)
    readonly property bool cinematic: Settings.atmosphereStyle === "cinematic"

    opacity: presentation

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: 11
        Repeater {
            model: 7
            Rectangle {
                required property int index
                width: index === 3 ? 14 : 5
                height: 1
                color: index === 3 ? root.tone : Theme.lineBright
                opacity: index === 3 ? 0.62 : 0.3
            }
        }
    }

    Rectangle {
        visible: root.cinematic && Settings.motion
        y: 1
        width: 80
        height: 1
        color: root.tone
        opacity: 0.45
        x: -width
        NumberAnimation on x {
            from: -80
            to: root.width
            duration: 5200
            loops: Animation.Infinite
            easing.type: Easing.InOutSine
            running: root.visible && root.cinematic && Settings.motion
        }
    }
}
