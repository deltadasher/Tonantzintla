import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root
    property string title: ""
    property string detail: ""
    property string actionText: ""
    signal activated()
    spacing: 12
    Text {
        text: root.title; color: Theme.moon; font.family: Theme.fontDisplay
        font.pixelSize: 18; font.bold: true; wrapMode: Text.Wrap
        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
    }
    Text {
        text: root.detail; color: Theme.muted; font.family: Theme.fontText
        font.pixelSize: 12; wrapMode: Text.Wrap
        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
    }
    Rectangle {
        visible: root.actionText.length > 0
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: actionLabel.implicitWidth + 28; implicitHeight: 40; radius: 20
        color: hover.hovered || activeFocus ? Theme.accent : Theme.controlActive
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: root.actionText
        Accessible.onPressAction: root.activated()
        Keys.onReturnPressed: root.activated()
        Keys.onSpacePressed: root.activated()
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.activated() }
        Text {
            id: actionLabel; anchors.centerIn: parent; text: root.actionText
            color: hover.hovered || parent.activeFocus ? Theme.void_ : Theme.moon
            font.family: Theme.fontMono; font.pixelSize: 12
        }
    }
}
