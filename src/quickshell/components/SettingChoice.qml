import QtQuick
import QtQuick.Layouts
import ".."

pragma ComponentBehavior: Bound

Rectangle {
    id: root

    implicitHeight: Math.max(48, content.implicitHeight + 20)
    radius: Theme.radiusMedium
    color: Theme.controlRest
    border.width: 0
    opacity: enabled ? 1 : 0.45

    property string label: "Choice"
    property string detail: ""
    property var choices: []
    property var value
    signal selected(var value)

    GridLayout {
        id: content
        columns: root.width < 640 ? 1 : 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 9
        columnSpacing: 12
        rowSpacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: content.columns === 1 ? root.width - 28 : root.width * 0.4
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.label
                wrapMode: Text.Wrap
                color: Theme.moon
                font.family: Theme.fontText
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            Text {
                visible: root.detail.length > 0
                Layout.fillWidth: true
                text: root.detail
                wrapMode: Text.Wrap
                color: Theme.muted
                font.family: Theme.fontText
                font.pixelSize: 10
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.preferredWidth: content.columns === 1 ? root.width - 28 : root.width * 0.5
            spacing: 4
            Repeater {
                model: root.choices
                Rectangle {
                    id: option
                    required property var modelData
                    readonly property bool active: modelData.value === root.value
                    width: Math.min(parent.width, optionLabel.implicitWidth + 16)
                    height: 30
                    radius: Theme.radiusSmall
                    color: active ? Theme.accent : optionPointer.containsMouse || activeFocus
                        ? Theme.controlHover : "transparent"
                    border.width: 0
                    activeFocusOnTab: root.enabled
                    Accessible.role: Accessible.Button
                    Accessible.name: root.label + ": " + (option.modelData.label || "")
                    Accessible.checked: active
                    Accessible.onPressAction: if (root.enabled) root.selected(option.modelData.value)
                    Keys.onReturnPressed: if (root.enabled) root.selected(option.modelData.value)
                    Keys.onSpacePressed: if (root.enabled) root.selected(option.modelData.value)

                    Text {
                        id: optionLabel
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 16)
                        elide: Text.ElideRight
                        text: option.modelData.label
                        color: option.active ? Theme.void_ : optionPointer.containsMouse || option.activeFocus ? Theme.moon : Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: option.active ? Font.Bold : Font.Normal
                    }

                    MouseArea {
                        id: optionPointer
                        anchors.fill: parent
                        enabled: root.enabled
                        hoverEnabled: true
                        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            option.forceActiveFocus();
                            root.selected(option.modelData.value);
                        }
                    }

                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }
            }
        }
    }
}
