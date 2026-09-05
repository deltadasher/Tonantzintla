import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

Rectangle {
    id: root
    implicitWidth: row.implicitWidth + 18
    implicitHeight: Settings.compact ? 34 : 38
    radius: 9
    color: hover.hovered ? Theme.barNeutralHover : "transparent"
    border.width: 0

    HoverHandler { id: hover }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 12

        Repeater {
            model: Settings.showSystemStats ? [
                { "code": "CPU", "value": SysStats.cpuPercent + "%" },
                { "code": "MEM", "value": SysStats.memoryPercent + "%" }
            ] : []

            Item {
                id: statHitbox
                required property var modelData
                Layout.preferredWidth: stat.implicitWidth
                Layout.preferredHeight: root.implicitHeight

                RowLayout {
                    id: stat
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: statHitbox.modelData.code
                        color: Theme.muted
                        font.family: Theme.fontText
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.45
                    }
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: statHitbox.modelData.value
                        color: Theme.moon
                        font.family: Theme.fontText
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
                TapHandler { onTapped: ShellState.toggleEphemeris("system") }
            }
        }

        Rectangle {
            visible: Settings.showAudio && Settings.showSystemStats
            Layout.preferredWidth: 1
            Layout.preferredHeight: 13
            color: Theme.barHairlineHover
        }

        Item {
            visible: Settings.showAudio
            Layout.preferredWidth: audioReadout.implicitWidth
            Layout.preferredHeight: root.implicitHeight

            RowLayout {
                id: audioReadout
                anchors.centerIn: parent
                spacing: 4
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Audio.muted ? "MUT" : "VOL"
                    color: Audio.muted ? Theme.warning : Theme.muted
                    font.family: Theme.fontText
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.45
                }
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Audio.percent + "%"
                    color: Theme.moon
                    font.family: Theme.fontText
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
            TapHandler { onTapped: ShellState.toggleEphemeris("audio") }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onWheel: function(event) {
            Audio.change(event.angleDelta.y > 0 ? 5 : -5);
            event.accepted = true;
        }
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
}
