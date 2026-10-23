import QtQuick
import "../.."

Item {
    id: root

    property string label: ""
    property bool checked: false
    signal toggled()

    implicitWidth: labelText.implicitWidth + Theme.switchWidth + Theme.spaceLg
    implicitHeight: Theme.controlHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onToggleAction: toggled()
    Keys.onReturnPressed: toggled()
    Keys.onSpacePressed: toggled()

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Theme.spaceXs
        anchors.rightMargin: -Theme.spaceXs
        radius: Theme.radiusSmall
        color: pointer.pressed ? Theme.controlActive : pointer.containsMouse ? Theme.controlHover : "transparent"
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    }

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.right: track.left
        anchors.rightMargin: Theme.spaceMd
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.moon
        font.family: Theme.fontText
        font.pixelSize: Theme.textLabel
        elide: Text.ElideRight
    }

    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.switchWidth
        height: Theme.switchHeight
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.controlRest
        border.width: root.checked ? 0 : 1
        border.color: Theme.lineBright
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

        Rectangle {
            x: root.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.switchKnob
            height: Theme.switchKnob
            radius: width / 2
            color: root.checked ? Theme.void_ : Theme.muted
            Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
