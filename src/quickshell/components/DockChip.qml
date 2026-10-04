import QtQuick
import QtQuick.Controls
import ".."

AbstractButton {
    id: root
    property bool selected: false
    implicitWidth: label.implicitWidth + 24
    implicitHeight: 30
    hoverEnabled: true
    Accessible.name: text
    background: Rectangle {
        radius: 10
        color: root.selected ? Theme.accent : root.hovered || root.visualFocus ? Theme.controlActive : Theme.controlRest
    }
    contentItem: Text {
        id: label
        text: root.text
        color: root.selected ? Theme.void_ : Theme.moon
        font.family: Theme.fontText
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
