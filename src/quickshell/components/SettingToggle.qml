import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    implicitHeight: Math.max(46, copy.implicitHeight + 20)
    radius: Theme.radiusMedium
    color: root.checked ? Theme.controlActive
        : pointer.containsMouse || activeFocus ? Theme.controlHover : Theme.controlRest
    border.width: 0
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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 12

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

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 18
            radius: 9
            color: root.checked ? Theme.accent : Theme.elevated
            border.width: 0

            Rectangle {
                y: 3
                x: root.checked ? 19 : 3
                width: 12
                height: 12
                radius: 6
                color: root.checked ? Theme.void_ : Theme.muted
                Behavior on x {
                    NumberAnimation {
                        duration: Settings.motion ? Theme.motionNormal : 0
                        easing.type: Easing.OutBack
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
