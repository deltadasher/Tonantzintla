import QtQuick
import ".."

Rectangle {
    id: root
    property string text: ""
    property bool selected: false
    property bool pending: false
    property bool destructive: false
    signal clicked()
    implicitWidth: label.implicitWidth + 28
    implicitHeight: 36
    radius: 11
    activeFocusOnTab: enabled && visible
    color: selected ? Theme.accent : pointer.containsMouse || activeFocus ? Theme.controlHover : Theme.controlRest
    border.width: activeFocus ? 2 : 0
    border.color: Theme.accent
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: if (enabled && !pending) clicked()
    Keys.onReturnPressed: if (!pending) clicked()
    Keys.onEnterPressed: if (!pending) clicked()
    Keys.onSpacePressed: if (!pending) clicked()
    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - 20)
        text: root.pending ? "Working…" : root.text
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: root.selected ? Theme.void_ : root.destructive ? Theme.danger : Theme.moon
        font.family: Theme.fontText
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: { root.forceActiveFocus(); if (!root.pending) root.clicked(); }
    }
    Behavior on color { ColorAnimation { duration: Settings.motion ? Theme.motionFast : 0 } }
}
