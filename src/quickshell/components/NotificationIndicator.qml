import QtQuick
import ".."
import "../services"

Rectangle {
    id: root

    signal activated()
    readonly property bool unread: Notifications.unreadCount > 0
    readonly property bool isVertical: root.parent && typeof root.parent.isVertical !== "undefined"
        ? root.parent.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")
    readonly property bool sourceActive: ShellState.ephemerisVisible
        && ShellState.ephemerisAnchorTarget === root
    readonly property bool hovered: pointer.containsMouse && !pointer.hoverSuppressed
        && !sourceActive

    implicitWidth: isVertical ? (Settings.compact ? 32 : 36) : (Settings.compact ? 36 : 40)
    implicitHeight: isVertical ? (Settings.compact ? 32 : 36) : (Settings.compact ? 36 : 40)
    radius: 11
    color: sourceActive ? Theme.void_ : unread ? Theme.barAccentVeil
        : hovered ? Theme.barNeutralHover : "transparent"
    border.width: 0
    scale: hovered ? 1.05 : 1
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
        property bool hoverSuppressed: false
        cursorShape: Qt.PointingHandCursor
        onClicked: { hoverSuppressed = true; root.activated(); }
        onExited: hoverSuppressed = false
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on scale { NumberAnimation { duration: Settings.motion ? 170 : 0; easing.type: Easing.OutBack } }
}
