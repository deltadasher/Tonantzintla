import QtQuick
import QtQuick.Controls
import ".."
import "../services"

Rectangle {
    id: root

    property string accessibleLabel: "Open notifications · " + (unread ? Notifications.unreadCount + " unread" : "No unread notifications")
    signal activated()
    readonly property bool unread: Notifications.unreadCount > 0
    readonly property bool isVertical: root.parent && typeof root.parent.isVertical !== "undefined"
        ? root.parent.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")
    readonly property bool sourceActive: ShellState.ephemerisVisible
        && ShellState.ephemerisAnchorTarget === root
    readonly property bool hovered: pointer.containsMouse && !pointer.hoverSuppressed
        && !sourceActive

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: accessibleLabel
    Accessible.onPressAction: activated()
    Keys.onReturnPressed: activated()
    Keys.onSpacePressed: activated()

    ToolTip {
        visible: root.hovered
        delay: 500
        text: root.accessibleLabel
        background: Rectangle { color: Theme.mantle; radius: Theme.radiusSmall; border.color: Theme.accentLine }
        contentItem: Text { text: root.accessibleLabel; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: Theme.textLabel }
    }

    implicitWidth: isVertical ? (Settings.compact ? 32 : 36) : (Settings.compact ? 36 : 40)
    implicitHeight: isVertical ? (Settings.compact ? 32 : 36) : (Settings.compact ? 36 : 40)
    radius: 11
    color: "transparent"
    border.width: activeFocus ? 1 : 0
    border.color: Theme.accent
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
            font.pixelSize: Theme.textMicro
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
}
