import QtQuick
import ".."
import "../services"

Rectangle {
    id: root

    signal activated()
    readonly property bool unread: Notifications.unreadCount > 0

    implicitWidth: Settings.compact ? 36 : 40
    implicitHeight: Settings.compact ? 36 : 40
    radius: 11
    color: unread ? Theme.barAccentVeil
        : pointer.containsMouse ? Theme.barNeutralHover : "transparent"
    border.width: 0
    scale: pointer.containsMouse ? 1.05 : 1
    clip: true

    Text {
        anchors.centerIn: parent
        text: root.unread ? "◉" : "◌"
        color: root.unread ? Theme.accent : Theme.moon
        font.family: Theme.fontMono
        font.pixelSize: Settings.compact ? 19 : 21
    }

    Rectangle {
        visible: root.unread
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 3
        width: 17
        height: 17
        radius: 9
        color: Theme.accent

        Text {
            anchors.centerIn: parent
            text: Math.min(9, Notifications.unreadCount)
            color: Theme.void_
            font.family: Theme.fontMono
            font.pixelSize: 10
            font.weight: Font.Black
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on scale { NumberAnimation { duration: Settings.motion ? 170 : 0; easing.type: Easing.OutBack } }
}
