import QtQuick
import QtQuick.Controls
import Quickshell
import "../.."

Item {
    id: root
    property string name: ""
    property string icon: ""
    property string glyph: ""
    property real iconSize: 44
    property bool running: false
    property bool active: false
    property bool motion: true
    property bool lift: true
    signal activated()
    signal newInstance()
    Accessible.role: Accessible.Button
    Accessible.name: name + (active ? ", focused" : running ? ", running" : "")
    Accessible.onPressAction: activated()
    Item {
        anchors.centerIn: parent
        width: root.iconSize; height: width
        scale: root.lift && pointer.containsMouse ? 1.16 : 1
        Behavior on scale { NumberAnimation { duration: root.motion ? 150 : 0; easing.type: Easing.OutCubic } }
        Image {
            id: appIcon
            anchors.fill: parent
            source: root.icon ? Quickshell.iconPath(root.icon, "application-x-executable") : ""
            sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        Text {
            anchors.centerIn: parent
            visible: !root.icon || appIcon.status === Image.Error
            text: root.glyph || root.name.slice(0, 1).toUpperCase()
            color: Theme.moon
            font.family: Theme.fontText
            font.pixelSize: root.iconSize * 0.7
        }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        width: root.active ? 16 : 5; height: 3; radius: 2
        visible: root.running
        color: root.active ? Theme.accent : Theme.moon
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton || mouse.modifiers & Qt.ShiftModifier) root.newInstance();
            else root.activated();
        }
    }
    ToolTip.visible: pointer.containsMouse
    ToolTip.delay: 400
    ToolTip.text: root.name + (root.running ? " · click to focus / cycle" : "")
}
