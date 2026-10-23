import QtQuick
import "../.."

Rectangle {
    id: root

    property string accessibleLabel: ""
    readonly property bool hovered: pointer.containsMouse
    signal activated()

    implicitHeight: Theme.controlHeight
    radius: Theme.radiusSmall
    color: Theme.controlRest
    border.width: activeFocus ? 1 : 0
    border.color: Theme.accent
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: accessibleLabel
    Accessible.onPressAction: activated()
    Keys.onReturnPressed: activated()
    Keys.onSpacePressed: activated()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius
        color: pointer.pressed ? Theme.controlPressed : Theme.controlHover
        opacity: pointer.pressed || root.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
