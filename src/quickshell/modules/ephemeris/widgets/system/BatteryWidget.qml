import QtQuick
import QtQuick.Layouts
import "../../../.."
import "../../../../services"
import "../shared" as Shared

Item {
    id: root

    readonly property color powerColor: DeviceState.batteryLow ? Theme.danger
        : DeviceState.batteryCharging ? Theme.success : Theme.accent
    readonly property color profileColor: DeviceState.powerProfile === "performance"
        ? Theme.danger : DeviceState.powerProfile === "power-saver"
            ? Theme.success : Theme.cyan

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "POWER"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 23
                font.weight: Font.Black
            }
            Text {
                text: DeviceState.batteryAvailable
                    ? DeviceState.batteryCharging ? "CHARGING"
                        : DeviceState.batteryPercent + "% REMAINING"
                    : "WALL POWER"
                color: root.powerColor
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.weight: Font.Black
            }
        }

        Shared.BatteryTimeline {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 240
            available: DeviceState.batteryAvailable
            charging: DeviceState.batteryCharging
            percent: DeviceState.batteryPercent
            secondsRemaining: DeviceState.batterySecondsRemaining
            energy: DeviceState.batteryEnergy
            capacity: DeviceState.batteryCapacity
            rate: DeviceState.batteryRate
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { "code": "DRAW", "value": DeviceState.batteryAvailable
                        ? DeviceState.batteryRate + " W" : "AC" },
                    { "code": "HEALTH", "value": DeviceState.batteryHealthPercent >= 0
                        ? DeviceState.batteryHealthPercent + "%" : "—" },
                    { "code": "RESERVE", "value": DeviceState.batteryAvailable
                        ? DeviceState.batteryEnergy + " WH" : "—" },
                    { "code": "CELL", "value": DeviceState.batteryAvailable
                        ? DeviceState.batteryCapacity + " WH" : "DESKTOP" }
                ]
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68
                    radius: 18
                    color: Theme.mantle
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.value
                            color: Theme.moon
                            font.family: Theme.fontDisplay
                            font.pixelSize: 15
                            font.weight: Font.Black
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.code
                            color: Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 16
            color: Theme.mantle
            opacity: DeviceState.powerProfileAvailable ? 1 : 0.55

            Rectangle {
                width: (parent.width - 4) / 3
                height: parent.height - 4
                y: 2
                radius: 14
                color: Qt.rgba(root.profileColor.r, root.profileColor.g,
                    root.profileColor.b, 0.82)
                x: DeviceState.powerProfile === "performance" ? 2
                    : DeviceState.powerProfile === "balanced" ? width + 2
                    : width * 2 + 2
                Behavior on x {
                    NumberAnimation { duration: Settings.motion ? 300 : 0; easing.type: Easing.OutCubic }
                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0
                Repeater {
                    model: [
                        { "name": "performance", "label": "PERFORM" },
                        { "name": "balanced", "label": "BALANCE" },
                        { "name": "power-saver", "label": "SAVER" }
                    ]
                    Item {
                        id: profileChoice
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        readonly property bool selected: DeviceState.powerProfile
                            === modelData.name
                        Text {
                            anchors.centerIn: parent
                            text: profileChoice.modelData.label
                            color: profileChoice.selected ? Theme.void_ : Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.Black
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: DeviceState.powerProfileAvailable
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: DeviceState.setPowerProfile(profileChoice.modelData.name)
                        }
                    }
                }
            }
        }
    }
}
