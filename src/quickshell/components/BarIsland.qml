import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    default property alias contents: contentRow.data
    property real reveal: 1
    property bool luminous: false
    property bool reactive: true
    readonly property bool separate: Settings.barMode === "capsules"

    implicitWidth: contentRow.implicitWidth + (Settings.compact ? 10 : 14)
    implicitHeight: Settings.compact ? 36 : Theme.barHeight
    radius: Settings.compact ? 11 : 14
    color: separate
        ? surfaceHover.hovered && reactive
            ? Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b,
                Math.min(0.88, Settings.barOpacity * 0.86))
            : Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b,
                Math.min(0.82, Settings.barOpacity * 0.78))
        : "transparent"
    border.width: 0
    border.color: Theme.barHairlineHover
    opacity: reveal
    scale: (0.96 + reveal * 0.04) * (surfaceHover.hovered && reactive ? 1.01 : 1)

    HoverHandler {
        id: surfaceHover
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: Settings.compact ? 2 : 4
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.separate && surfaceHover.hovered ? Math.min(28, root.width * 0.28) : 0
        height: 1
        color: Theme.accent
        opacity: 0.72
        Behavior on width { NumberAnimation { duration: Settings.motion ? 180 : 0; easing.type: Easing.OutCubic } }
    }

    transform: Translate { y: (1 - root.reveal) * -12 }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on scale { NumberAnimation { duration: Settings.motion ? 180 : 0; easing.type: Easing.OutCubic } }
}
