pragma ComponentBehavior: Bound
import QtQuick
import "../.."
import "../../services"
Item {
    id: root
    property bool active: visible
    property bool interactive: true
    property real phase: 0
    property real energy: 0
    readonly property real scaleFactor: Math.min(width / 470, height / 108)
    // Media hit targets stay at their final positions throughout arrival.

    UmbraDisc {
        id: mediaDisc
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 108 * root.scaleFactor
        height: width
        artSource: root.visible && root.active ? Media.artUrl : ""
        playing: root.active && Settings.motion && Settings.umbraMotion && Media.playing
        phase: root.phase
        energy: root.energy
        MouseArea {
            anchors.fill: parent
            enabled: root.interactive
            cursorShape: Qt.PointingHandCursor
            onClicked: Media.toggle()
        }
    }

    Text {
        anchors.right: mediaDisc.left
        anchors.rightMargin: 22 * root.scaleFactor
        y: 25 * root.scaleFactor
        width: parent.width - mediaDisc.width - 30 * root.scaleFactor
        horizontalAlignment: Text.AlignRight
        text: Media.title
        color: Theme.moon
        font.family: Theme.fontDisplay
        font.pixelSize: 15 * root.scaleFactor
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }
    Rectangle {
        anchors.right: mediaDisc.left
        anchors.rightMargin: 22 * root.scaleFactor
        y: 60 * root.scaleFactor
        width: (parent.width - mediaDisc.width - 30 * root.scaleFactor) * Media.progress
        height: 7 * root.scaleFactor
        radius: height / 2
        color: Theme.rose
        Behavior on width { enabled: root.active && Media.playing && Settings.motion && Settings.umbraMotion; NumberAnimation { duration: 700; easing.type: Easing.Linear } }
    }

    Row {
        anchors.right: mediaDisc.left
        anchors.rightMargin: 22 * root.scaleFactor
        y: Math.min(78 * root.scaleFactor, root.height - 32 * root.scaleFactor)
        spacing: 12 * root.scaleFactor

        Repeater {
            model: ["‹", Media.playing ? "Ⅱ" : "▶", "›"]
            Rectangle {
                required property string modelData
                required property int index
                width: 32 * root.scaleFactor
                height: width
                radius: width / 2
                color: controlPointer.containsMouse
                    ? (index === 1 ? Theme.accent : Theme.elevated)
                    : index === 1 ? Theme.accentVeil : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData
                    color: parent.index === 1 && controlPointer.containsMouse
                        ? Theme.void_ : Theme.moon
                    font.family: Theme.iconFamily(text)
                    font.pixelSize: 16 * root.scaleFactor
                    font.weight: Font.Normal
                }
                MouseArea {
                    id: controlPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.interactive
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (parent.index === 0) Media.previous();
                        else if (parent.index === 1) Media.toggle();
                        else Media.next();
                    }
                }
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            }
        }
    }
}
