import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property string code: "SYS"
    property string value: "--"
    property bool active: true
    property bool warning: false
    property color accentColor: Theme.accent
    property string accessibleLabel: code + " " + value
    signal activated()
    signal scrolled(real delta)
    readonly property bool isVertical: root.parent && typeof root.parent.isVertical !== "undefined"
        ? root.parent.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")

    implicitWidth: root.isVertical ? (Settings.compact ? 36 : 40) : (layoutGrid.implicitWidth + 16)
    implicitHeight: root.isVertical ? (layoutGrid.implicitHeight + 8) : (Settings.compact ? 34 : 38)
    radius: 9
    color: root.warning
        ? Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
        : pointer.containsMouse ? Theme.barNeutralHover : "transparent"
    border.width: 0
    scale: pointer.containsMouse ? 1.03 : 1

    GridLayout {
        id: layoutGrid
        anchors.centerIn: parent
        columns: root.isVertical ? 1 : 2
        rowSpacing: root.isVertical ? 1 : 0
        columnSpacing: root.isVertical ? 0 : 5

        Text {
            Layout.alignment: root.isVertical ? Qt.AlignHCenter : Qt.AlignVCenter
            text: root.code
            color: root.warning ? Theme.warning : root.active ? root.accentColor : Theme.muted
            font.family: Theme.fontText
            font.pixelSize: root.isVertical ? 9 : 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.45
            horizontalAlignment: root.isVertical ? Text.AlignHCenter : Text.AlignLeft
        }
        Text {
            Layout.alignment: root.isVertical ? Qt.AlignHCenter : Qt.AlignVCenter
            text: root.value
            color: root.active ? Theme.moon : Theme.muted
            font.family: Theme.fontText
            font.pixelSize: root.isVertical ? 10 : 12
            font.weight: Font.DemiBold
            horizontalAlignment: root.isVertical ? Text.AlignHCenter : Text.AlignLeft
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
        onWheel: function(event) {
            root.scrolled(event.angleDelta.y);
            event.accepted = true;
        }
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutBack } }
}
