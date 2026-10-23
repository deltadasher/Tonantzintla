import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    implicitHeight: Math.max(48, copy.implicitHeight + Theme.spaceXl)
    radius: Theme.radiusMedium
    color: pointer.pressed ? Theme.controlPressed
        : pointer.containsMouse || activeFocus ? Theme.controlHover : Theme.controlRest
    border.width: activeFocus ? 1 : 0
    border.color: Theme.focusRing
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: enabled
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.label + (root.detail.length > 0 ? " — " + root.detail : "")
    Accessible.checked: root.checked
    Accessible.onPressAction: if (enabled) root.toggled()
    Keys.onReturnPressed: if (enabled) root.toggled()
    Keys.onSpacePressed: if (enabled) root.toggled()

    property string label: "Setting"
    property string detail: ""
    property bool checked: false
    signal toggled

    OpticalSurface {
        parent: root
        anchors.fill: parent; radius: root.radius
        hovered: pointer.containsMouse; pressed: pointer.pressed; selected: root.checked; focused: root.activeFocus
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceLg
        anchors.rightMargin: Theme.spaceLg
        spacing: Theme.spaceMd

        ColumnLayout {
            id: copy
            Layout.fillWidth: true
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

        Rectangle {
            Layout.preferredWidth: Theme.switchWidth
            Layout.preferredHeight: Theme.switchHeight
            radius: Math.min(Theme.radiusSmall, height / 2)
            color: root.checked ? Theme.accent : Theme.elevated
            border.width: 0

            Rectangle {
                objectName: "switchThumb"
                y: (Theme.switchHeight - Theme.switchKnob) / 2
                x: root.checked ? Theme.switchWidth - width - y : y
                width: Theme.switchKnob + (pointer.pressed && Theme.motionEnabled ? 6 : 0)
                height: Theme.switchKnob
                radius: Math.min(Theme.radiusSmall, height / 2)
                color: root.checked ? Theme.void_ : Theme.muted
                Behavior on width { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
                Behavior on radius { NumberAnimation { duration: Theme.motionFast } }
                Behavior on x {
                    NumberAnimation {
                        duration: Settings.motion ? Theme.motionNormal : 0
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.forceActiveFocus();
            root.toggled();
        }
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
}
