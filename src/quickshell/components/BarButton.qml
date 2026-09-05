import QtQuick
import ".."

Rectangle {
    id: root

    implicitWidth: Settings.compact ? 36 : 40
    implicitHeight: Settings.compact ? 36 : 40
    radius: 11
    color: pointer.containsMouse ? Theme.barAccentVeil : "transparent"
    border.width: 0
    scale: pointer.containsMouse ? 1.06 : 1

    property string glyph: "⌕"
    property string accessibleLabel: "Action"
    signal activated

    Text {
        anchors.centerIn: parent
        text: root.glyph
        color: pointer.containsMouse ? Theme.accent : Theme.moon
        font.family: Theme.fontIcon
        font.pixelSize: Settings.compact ? 19 : 21
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on scale {
        NumberAnimation {
            duration: Settings.motion ? Theme.motionFast : 0
            easing.type: Easing.OutBack
        }
    }
}
