import QtQuick
import QtQuick.Layouts
import ".."

pragma ComponentBehavior: Bound

Rectangle {
    id: root

    implicitHeight: Math.max(52, content.implicitHeight + Theme.spaceXl)
    radius: Theme.radiusMedium
    color: Theme.controlRest
    border.width: 0
    opacity: enabled ? 1 : 0.45

    property string label: "Choice"
    property string detail: ""
    property var choices: []
    property var value
    signal selected(var value)
    property Item hoveredOption: null
    property Item focusedOption: null
    property Item activeOption: null

    GridLayout {
        id: content
        columns: root.width < 640 ? 1 : 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spaceLg
        anchors.rightMargin: Theme.spaceLg
        columnSpacing: Theme.spaceMd
        rowSpacing: Theme.spaceSm

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: content.columns === 1 ? root.width - 32 : root.width * 0.36
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.label
                wrapMode: Text.Wrap
                color: Theme.moon
                font.family: Theme.fontText
                font.pixelSize: Theme.textBody
                font.weight: Font.Medium
            }

            Text {
                visible: root.detail.length > 0
                Layout.fillWidth: true
                text: root.detail
                wrapMode: Text.Wrap
                color: Theme.muted
                font.family: Theme.fontText
                font.pixelSize: Theme.textCaption
            }
        }

        Item {
            implicitHeight: optionFlow.implicitHeight
            OpticalLens {
                targetItem: root.hoveredOption || root.focusedOption || root.activeOption
                outset: 1
            }
            Layout.fillWidth: true
            Layout.preferredWidth: content.columns === 1 ? root.width - 32 : root.width * 0.56
            Flow {
                id: optionFlow
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                spacing: Theme.spaceXs
                Repeater {
                    model: root.choices
                    Rectangle {
                        id: option
                        required property var modelData
                        readonly property bool active: modelData.value === root.value
                        onActiveChanged: { if (active) root.activeOption = option; else if (root.activeOption === option) root.activeOption = null; }
                        onActiveFocusChanged: { if (activeFocus) root.focusedOption = option; else if (root.focusedOption === option) root.focusedOption = null; }
                        Component.onCompleted: if (active) root.activeOption = option
                        Component.onDestruction: {
                            if (root.hoveredOption === option) root.hoveredOption = null;
                            if (root.focusedOption === option) root.focusedOption = null;
                            if (root.activeOption === option) root.activeOption = null;
                        }
                        width: Math.min(parent.width, optionLabel.implicitWidth + 20)
                        height: Theme.controlHeight
                        radius: Theme.radiusSmall
                        color: optionPointer.pressed ? Theme.controlPressed
                            : active ? Theme.accent : optionPointer.containsMouse || activeFocus
                            ? (Settings.opticalControls ? "transparent" : Theme.controlHover) : "transparent"
                        border.width: activeFocus ? 1 : 0
                        border.color: active ? Theme.moon : Theme.focusRing
                        activeFocusOnTab: root.enabled
                        Accessible.role: Accessible.Button
                        Accessible.name: root.label + ": " + (option.modelData.label || "")
                        Accessible.checked: active
                        Accessible.onPressAction: if (root.enabled) root.selected(option.modelData.value)
                        Keys.onReturnPressed: if (root.enabled) root.selected(option.modelData.value)
                        Keys.onSpacePressed: if (root.enabled) root.selected(option.modelData.value)

                        OpticalSurface {
                            anchors.fill: parent; radius: option.radius
                            hovered: optionPointer.containsMouse; pressed: optionPointer.pressed
                            selected: option.active; focused: option.activeFocus
                            visible: Settings.opticalControls && !option.active
                        }
                        Text {
                            id: optionLabel
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - 16)
                            elide: Text.ElideRight
                            text: option.modelData.label
                            color: option.active && !optionPointer.pressed ? (typeof Theme.onAccent === "undefined" ? Theme.void_ : Theme.onAccent) : optionPointer.containsMouse || option.activeFocus ? Theme.moon : Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.textCaption
                            font.weight: option.active ? Font.Bold : Font.Normal
                        }

                        MouseArea {
                            id: optionPointer
                            anchors.fill: parent
                            enabled: root.enabled
                            hoverEnabled: true
                            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onEntered: root.hoveredOption = option
                            onExited: if (root.hoveredOption === option) root.hoveredOption = null
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
}
