import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../.."

Rectangle {
    id: root
    height: matched ? Math.min(88, 48 + Math.log(launchCount + 1) * 9) : 2
    radius: Theme.radiusMedium
    color: root.selected ? Theme.controlActive
        : pointer.containsMouse ? Theme.controlHover : "transparent"
    border.width: 0

    required property var modelData
    required property int index
    property bool selected: false
    property bool matched: true
    property int launchCount: 0
    signal activated
    signal hovered(int index)
    opacity: matched ? Math.min(1, 0.56 + Math.log(launchCount + 1) * 0.16) : 0
    clip: true

    IconImage {
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: Math.min(96, root.height * 1.55)
        source: Quickshell.iconPath(root.modelData.icon, "application-x-executable")
        opacity: pointer.containsMouse || root.selected ? 0.22 : 0.08
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 11
        anchors.rightMargin: 12
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 10
            color: root.selected ? Theme.accent : Theme.elevated
            border.width: 0

            IconImage {
                anchors.centerIn: parent
                implicitSize: 25
                source: Quickshell.iconPath(root.modelData.icon, "application-x-executable")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: root.modelData.name
                color: Theme.moon
                font.family: Theme.fontText
                font.pixelSize: Math.min(27, 12 + Math.log(root.launchCount + 1) * 3.2)
                font.weight: root.selected || root.launchCount > 5 ? Font.Bold : Font.Normal
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: Settings.showAppDescriptions
                text: root.modelData.genericName || root.modelData.comment || root.modelData.id
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Text {
            visible: root.selected
            text: "↵"
            color: Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: 14
            font.letterSpacing: 1
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered(root.index)
        onClicked: root.activated()
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on height { NumberAnimation { duration: Settings.motion ? 260 : 0; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Settings.motion ? 220 : 0 } }
}
