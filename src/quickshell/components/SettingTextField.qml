import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    implicitHeight: Math.max(56, content.implicitHeight + Theme.spaceXl)
    radius: Theme.radiusMedium
    color: Theme.controlRest
    border.width: editor.activeFocus ? 1 : 0
    border.color: Theme.focusRing
    opacity: enabled ? 1 : 0.45

    property string label: "Command"
    property string detail: ""
    property string value: ""
    property string status: ""
    property bool statusOk: true
    readonly property bool stacked: width < 360
    signal committed(string value)

    OpticalSurface {
        parent: root
        anchors.fill: parent; radius: root.radius
        focused: editor.activeFocus
    }

    GridLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spaceLg
        anchors.rightMargin: Theme.spaceLg
        columns: root.stacked ? 1 : 2
        columnSpacing: Theme.spaceMd
        rowSpacing: Theme.spaceSm

        Text {
            Layout.fillWidth: true
            Layout.preferredWidth: root.stacked ? root.width - 32 : root.width * 0.36
            text: root.label
            wrapMode: Text.Wrap
            color: Theme.moon
            font.family: Theme.fontText
            font.pixelSize: Theme.textBody
            font.weight: Font.Medium
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: root.stacked ? root.width - 32 : root.width * 0.56
            Layout.minimumWidth: 0
            spacing: Theme.spaceXs

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.controlHeight
                radius: Theme.radiusSmall
                color: editor.activeFocus ? Theme.fieldFocus : Theme.fieldRest
                border.width: 0

                TextInput {
                    id: editor
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spaceMd
                    anchors.rightMargin: Theme.spaceMd
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.value
                    color: Theme.moon
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.void_
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.textLabel
                    clip: true
                    activeFocusOnTab: root.enabled
                    Accessible.role: Accessible.EditableText
                    Accessible.name: root.label
                    Accessible.description: root.detail
                    onEditingFinished: root.committed(text.trim())
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.status.length > 0
                text: root.status
                color: root.statusOk ? Theme.muted : Theme.warning
                font.family: Theme.fontMono
                font.pixelSize: Theme.textMicro
                elide: Text.ElideRight
            }
        }
    }
}
