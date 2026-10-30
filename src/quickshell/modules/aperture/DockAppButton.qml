import QtQuick
import QtQuick.Controls
import Quickshell
import "../.."
import "../../components"

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
    property real hoverAmount: 1.12
    property real neighborAmount: 0
    property bool showIndicator: true
    property string edge: "bottom"
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool hovered: pointer.containsMouse && enabled
    activeFocusOnTab: enabled
    opacity: enabled ? 1 : 0.45
    Keys.onReturnPressed: if (enabled) activated()
    Keys.onSpacePressed: if (enabled) activated()
    signal activated()
    signal newInstance()
    Accessible.role: Accessible.Button
    Accessible.name: name + (active ? ", focused" : running ? ", running" : "")
    Accessible.onPressAction: if (enabled) activated()
    Item {
        anchors.centerIn: parent
        width: root.iconSize; height: width
        scale: pointer.pressed ? 0.96 : root.lift
            ? 1 + (Math.max(1, Math.min(1.6, root.hoverAmount)) - 1)
                * (root.hovered ? 1 : Math.max(0, Math.min(0.5, root.neighborAmount))) : 1
        Behavior on scale { NumberAnimation { duration: root.motion ? 150 : 0; easing.type: Easing.OutCubic } }
        Image {
            id: appIcon
            anchors.fill: parent
            source: root.icon ? Quickshell.iconPath(root.icon, "application-x-executable") : ""
            sourceSize: Qt.size(Math.ceil(root.iconSize * Math.min(3, Math.max(1, Screen.devicePixelRatio))), Math.ceil(root.iconSize * Math.min(3, Math.max(1, Screen.devicePixelRatio))))
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
        x: root.vertical ? (root.edge === "right" ? parent.width - width - 1 : 1) : (parent.width - width) / 2
        y: root.vertical ? (parent.height - height) / 2 : (root.edge === "bottom" ? parent.height - height - 1 : 1)
        width: root.vertical ? 3 : root.active ? 16 : 5
        height: root.vertical ? (root.active ? 16 : 5) : 3
        radius: 2
        visible: root.activeFocus || (root.running && root.showIndicator)
        color: root.active || root.activeFocus ? Theme.accent : Theme.moon
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
    ToolTip.visible: root.hovered
    ToolTip.delay: 400
    ToolTip.text: root.name + (root.running ? " · click to focus / cycle" : "")
}
