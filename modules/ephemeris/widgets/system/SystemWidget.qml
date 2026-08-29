import QtQuick
import QtQuick.Layouts
import "../../../.."
import "../../../../services"

Item {
    id: root

    component GaugeCard: Rectangle {
        id: gauge
        required property string code
        required property string label
        required property string valueText
        required property string detail
        required property real value
        property color accentColor: Theme.accent
        property real phase: 0

        Layout.fillWidth: true
        Layout.preferredHeight: 184
        radius: Theme.radiusLarge
        color: Theme.mantle
        border.width: 0
        border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.42)
        clip: true

        Rectangle {
            width: 130; height: 130; radius: 65
            x: gauge.width - 82 + Math.cos(gauge.phase) * 8
            y: -54 + Math.sin(gauge.phase) * 8
            color: gauge.accentColor
            opacity: 0.075
        }
        NumberAnimation on phase {
            from: 0; to: Math.PI * 2; duration: 18000
            loops: Animation.Infinite
            running: Settings.motion && root.visible
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Text { text: gauge.code; color: gauge.accentColor; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1 }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 7; Layout.preferredHeight: 7; radius: 4
                    color: gauge.value >= 0.9 ? Theme.danger : gauge.value >= 0.72 ? Theme.warning : Theme.success
                }
            }
            Text { text: gauge.valueText; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 29; font.weight: Font.Bold }
            Text { text: gauge.label.toUpperCase(); color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.letterSpacing: 0.8 }
            Item { Layout.fillHeight: true }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 7; radius: 4
                color: Theme.line; clip: true
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, gauge.value))
                    height: parent.height; radius: parent.radius; color: gauge.accentColor
                    Behavior on width { NumberAnimation { duration: 650; easing.type: Easing.OutQuint } }
                }
            }
            Text { text: gauge.detail; color: Theme.lineBright; font.family: Theme.fontMono; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "SYSTEM"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 23
                font.weight: Font.DemiBold
            }
            RowLayout {
                spacing: 14
                Repeater {
                    model: [
                        { "code": "UPTIME", "value": SysStats.uptimeLabel },
                        { "code": "LOAD", "value": SysStats.loadAverage.toFixed(2) },
                        { "code": "PROCS", "value": SysStats.processCount.toString() }
                    ]
                    ColumnLayout {
                        required property var modelData
                        spacing: 1
                        Text { text: modelData.code; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.letterSpacing: 0.8 }
                        Text { text: modelData.value; color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 10
            rowSpacing: 10
            GaugeCard { code: "CPU"; label: "CPU load"; valueText: SysStats.cpuPercent + "%"; detail: SysStats.cpuTemperature > 0 ? SysStats.cpuTemperature + "°C CPU" : "NO SENSOR"; value: SysStats.cpuPercent / 100; accentColor: Theme.violet }
            GaugeCard { code: "MEM"; label: "Memory"; valueText: SysStats.memoryPercent + "%"; detail: SysStats.memoryUsedGb + " / " + SysStats.memoryTotalGb + " GB"; value: SysStats.memoryPercent / 100; accentColor: Theme.cyan }
            GaugeCard { code: "THERM"; label: "Temperature"; valueText: (SysStats.gpuTemperature || SysStats.cpuTemperature) + "°C"; detail: SysStats.gpuTemperature > 0 ? "GPU " + SysStats.gpuTemperature + "° // CPU " + SysStats.cpuTemperature + "°" : "CPU SENSOR"; value: (SysStats.gpuTemperature || SysStats.cpuTemperature) / 100; accentColor: Theme.rose }
            GaugeCard { code: "DISK"; label: "Storage"; valueText: SysStats.diskPercent + "%"; detail: SysStats.diskUsedGb + " / " + SysStats.diskTotalGb + " GB"; value: SysStats.diskPercent / 100; accentColor: Theme.warning }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                radius: Theme.radiusLarge; color: Theme.mantle; border.width: 0; border.color: Theme.line
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 15; spacing: 10
                    Text { text: "SPEED"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1 }
                    Repeater {
                        model: [
                            { "glyph": "↓", "label": "RECEIVE", "value": SysStats.networkDownLabel, "color": Theme.cyan },
                            { "glyph": "↑", "label": "TRANSMIT", "value": SysStats.networkUpLabel, "color": Theme.rose }
                        ]
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.radiusMedium; color: Theme.elevated; border.width: 0; border.color: Theme.line
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                                Text { text: modelData.glyph; color: modelData.color; font.family: Theme.fontDisplay; font.pixelSize: 23; font.weight: Font.Bold }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 1
                                    Text { text: modelData.label; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.letterSpacing: 0.8 }
                                    Text { text: modelData.value; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 16; font.weight: Font.DemiBold }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 430; Layout.fillHeight: true
                radius: Theme.radiusLarge; color: Theme.mantle; border.width: 0; border.color: Theme.line
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 15; spacing: 7
                    Text { text: "LARGEST FOLDERS"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1 }
                    Repeater {
                        model: SysStats.folders
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: 9; color: Theme.elevated
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                Text { Layout.fillWidth: true; text: modelData.name.toUpperCase(); color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 10; elide: Text.ElideRight }
                                Text { text: SysStats.formatBytes(modelData.bytes); color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                            }
                        }
                    }
                    Text {
                        visible: SysStats.folders.length === 0
                        Layout.fillWidth: true; Layout.fillHeight: true
                        text: "SCANNING…"
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10
                    }
                }
            }
        }
    }
}
