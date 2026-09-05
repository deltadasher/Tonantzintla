import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property string code: "SYS"
    property string value: "--"
    property bool active: true
    property bool warning: false
    property color accentColor: Theme.accent
    property string accessibleLabel: code + " " + value
    signal activated()
    signal scrolled(real delta)

    implicitWidth: row.implicitWidth + 16
    implicitHeight: Settings.compact ? 34 : 38
    radius: 9
    color: root.warning
        ? Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
        : pointer.containsMouse ? Theme.barNeutralHover : "transparent"
    border.width: 0
    scale: pointer.containsMouse ? 1.03 : 1

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.code
            color: root.warning ? Theme.warning : root.active ? root.accentColor : Theme.muted
            font.family: Theme.fontText
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.45
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.value
            color: root.active ? Theme.moon : Theme.muted
            font.family: Theme.fontText
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
        onWheel: function(event) {
            root.scrolled(event.angleDelta.y);
            event.accepted = true;
        }
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutBack } }
}
