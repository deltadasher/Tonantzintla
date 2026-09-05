import QtQuick
import QtQuick.Layouts
import ".."

pragma ComponentBehavior: Bound

Rectangle {
    id: root

    implicitHeight: 48
    radius: Theme.radiusMedium
    color: Theme.controlRest
    border.width: 0

    property string label: "Choice"
    property string detail: ""
    property var choices: []
    property var value
    signal selected(var value)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 9
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: root.label
            color: Theme.moon
            font.family: Theme.fontText
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        RowLayout {
            spacing: 4
            Repeater {
                model: root.choices
                Rectangle {
                    id: option
                    required property var modelData
                    readonly property bool active: modelData.value === root.value
                    implicitWidth: optionLabel.implicitWidth + 16
                    implicitHeight: 30
                    radius: Theme.radiusSmall
                    color: active ? Theme.accent : optionPointer.containsMouse
                        ? Theme.controlHover : "transparent"
                    border.width: 0

                    Text {
                        id: optionLabel
                        anchors.centerIn: parent
                        text: option.modelData.label
                        color: option.active ? Theme.void_ : Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: option.active ? Font.Bold : Font.Normal
                    }

                    MouseArea {
                        id: optionPointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected(option.modelData.value)
                    }

                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }
            }
        }
    }
}
