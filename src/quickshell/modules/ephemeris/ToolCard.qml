import QtQuick
import QtQuick.Layouts
import "../.."

Rectangle {
    id: root
    implicitHeight: 96
    radius: Theme.radiusMedium
    color: pointer.containsMouse && root.available ? Theme.controlHover : Theme.controlRest
    border.width: 0
    opacity: root.available ? 1 : 0.52

    property string code: "SYS/00"
    property string title: "Tool"
    property string detail: "Tool description"
    property string status: "READY"
    property bool available: true
    signal activated

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: root.available ? Theme.success : Theme.warning
                opacity: root.status === "READY" || root.status === "ONLINE" ? 0.7 : 1
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.detail
            color: Theme.muted
            font.family: Theme.fontText
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
}
