import QtQuick
import QtQuick.Layouts
import "../../../.."
import "../../../../services"

Item {
    id: root

    readonly property color reactorColor: DeviceState.batteryLow ? Theme.danger
        : DeviceState.batteryCharging ? Theme.success : Theme.accent
    readonly property color profileColor: DeviceState.powerProfile === "performance"
        ? Theme.danger : DeviceState.powerProfile === "power-saver"
            ? Theme.success : Theme.cyan

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "POWER"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 23
                font.weight: Font.Black
            }

            Rectangle {
                Layout.preferredWidth: profileStatus.implicitWidth + 24
                Layout.preferredHeight: 34
                radius: 10
                color: Qt.rgba(root.profileColor.r, root.profileColor.g,
                    root.profileColor.b, 0.10)
                RowLayout {
                    id: profileStatus
                    anchors.centerIn: parent
                    spacing: 7
                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: DeviceState.powerProfileAvailable
                            ? root.profileColor : Theme.warning
                    }
                    Text {
                        text: DeviceState.powerProfileAvailable
                            ? DeviceState.powerProfile.toUpperCase() : "UNAVAILABLE"
                        color: DeviceState.powerProfileAvailable ? Theme.moon : Theme.warning
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            Rectangle {
                Layout.preferredWidth: 270
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: Theme.mantle
                border.width: 0
                border.color: Theme.barHairlineHover
                clip: true

                Rectangle {
                    anchors.centerIn: parent
                    width: 245
                    height: width
                    radius: width / 2
                    color: root.reactorColor
                    opacity: 0.045

                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: Settings.motion && root.visible
                        NumberAnimation { to: 1.07; duration: 2400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 2400; easing.type: Easing.InOutSine }
                    }
                }

                Item {
                    id: gauge
                    anchors.centerIn: parent
                    width: 222
                    height: 222

                    Canvas {
                        id: reactorCanvas
                        anchors.fill: parent
                        Connections {
                            target: DeviceState
                            function onBatteryPercentChanged() { reactorCanvas.requestPaint(); }
                            function onBatteryChargingChanged() { reactorCanvas.requestPaint(); }
                            function onBatteryLowChanged() { reactorCanvas.requestPaint(); }
                        }
                        Connections {
                            target: Theme
                            function onAccentChanged() { reactorCanvas.requestPaint(); }
                        }
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            const cx = width / 2;
                            const cy = height / 2;
                            const radius = width / 2 - 15;
                            const count = 48;
                            const active = DeviceState.batteryAvailable
                                ? Math.round(count * DeviceState.batteryPercent / 100) : 0;
                            ctx.lineCap = "round";
                            for (let index = 0; index < count; index++) {
                                const angle = -Math.PI / 2 + index * Math.PI * 2 / count;
                                const inner = radius - (index % 4 === 0 ? 9 : 5);
                                const outer = radius;
                                ctx.beginPath();
                                ctx.moveTo(cx + Math.cos(angle) * inner,
                                    cy + Math.sin(angle) * inner);
                                ctx.lineTo(cx + Math.cos(angle) * outer,
                                    cy + Math.sin(angle) * outer);
                                ctx.lineWidth = index < active ? 3 : 1.5;
                                ctx.strokeStyle = index < active
                                    ? root.reactorColor.toString() : Theme.line.toString();
                                ctx.globalAlpha = index < active ? 0.94 : 0.50;
                                ctx.stroke();
                            }
                            ctx.globalAlpha = 1;
                            ctx.beginPath();
                            ctx.arc(cx, cy, radius - 19, 0, Math.PI * 2);
                            ctx.lineWidth = 1;
                            ctx.setLineDash([3, 8]);
                            ctx.strokeStyle = Theme.barHairlineHover.toString();
                            ctx.stroke();
                            ctx.setLineDash([]);
                        }
                    }

                    Item {
                        anchors.centerIn: parent
                        width: 204
                        height: 204
                        rotation: 0

                        Rectangle {
                            anchors.centerIn: parent
                            width: 204
                            height: 78
                            radius: 39
                            color: "transparent"
                            border.width: 0
                            border.color: Qt.rgba(root.reactorColor.r,
                                root.reactorColor.g, root.reactorColor.b, 0.28)
                            rotation: -18
                        }
                        Rectangle {
                            x: 187
                            y: 85
                            width: 7
                            height: 7
                            radius: 4
                            color: root.reactorColor
                        }

                        NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 26000
                            loops: Animation.Infinite
                            running: Settings.motion && root.visible
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 138
                        height: 138
                        radius: width / 2
                        color: Theme.void_
                        border.width: 0
                        border.color: Qt.rgba(root.reactorColor.r,
                            root.reactorColor.g, root.reactorColor.b, 0.58)

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: DeviceState.batteryAvailable
                                    ? DeviceState.batteryPercent + "%" : "AC"
                                color: DeviceState.batteryAvailable
                                    ? root.reactorColor : Theme.moon
                                font.family: Theme.fontDisplay
                                font.pixelSize: 35
                                font.weight: Font.Black
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: DeviceState.batteryAvailable
                                    ? DeviceState.batteryCharging ? "CHARGING" : "CHARGE"
                                    : "DESKTOP"
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    text: DeviceState.batteryAvailable
                        ? DeviceState.batteryTimeLabel + " ESTIMATED" : "EXTERNAL POWER NOMINAL"
                    color: Theme.muted
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.letterSpacing: 0.8
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10

                    Repeater {
                        model: [
                            { "code": "HEALTH", "value": DeviceState.batteryHealthPercent >= 0 ? DeviceState.batteryHealthPercent + "%" : "NO SENSOR", "detail": "DESIGN CAPACITY" },
                            { "code": "ENERGY", "value": DeviceState.batteryAvailable ? DeviceState.batteryEnergy + " WH" : "EXTERNAL", "detail": DeviceState.batteryAvailable ? DeviceState.batteryCapacity + " WH FULL" : "WALL POWER" },
                            { "code": "RATE", "value": DeviceState.batteryAvailable ? DeviceState.batteryRate + " W" : "NOMINAL", "detail": DeviceState.batteryCharging ? "INPUT FLOW" : "POWER DRAW" },
                            { "code": "STATE", "value": DeviceState.batteryLow ? "LOW POWER" : DeviceState.batteryCharging ? "CHARGING" : DeviceState.batteryAvailable ? "ON CELL" : "DESKTOP", "detail": DeviceState.batteryTimeLabel }
                        ]

                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 104
                            radius: Theme.radiusMedium
                            color: Theme.mantle
                            border.width: 0
                            border.color: Theme.barHairline

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 13
                                spacing: 4
                                Text { text: modelData.code; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1 }
                                Text { text: modelData.value; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 16; font.weight: Font.Black }
                                Item { Layout.fillHeight: true }
                                Text { text: modelData.detail; color: Theme.lineBright; font.family: Theme.fontMono; font.pixelSize: 10; font.letterSpacing: 0.6 }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: "POWER MODE"
                    color: Theme.muted
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }

                Rectangle {
                    id: profileDock
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: 14
                    color: Theme.mantle
                    border.width: 0
                    border.color: Theme.barHairlineHover
                    opacity: DeviceState.powerProfileAvailable ? 1 : 0.55

                    Rectangle {
                        width: (parent.width - 4) / 3
                        height: parent.height - 4
                        y: 2
                        radius: 12
                        color: Qt.rgba(root.profileColor.r, root.profileColor.g,
                            root.profileColor.b, 0.82)
                        x: DeviceState.powerProfile === "performance" ? 2
                            : DeviceState.powerProfile === "balanced" ? width + 2
                            : width * 2 + 2
                        Behavior on x { NumberAnimation { duration: Settings.motion ? 330 : 0; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: Theme.motionNormal } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0
                        Repeater {
                            model: [
                                { "name": "performance", "glyph": "󰓅", "label": "PERFORM" },
                                { "name": "balanced", "glyph": "󰗑", "label": "BALANCE" },
                                { "name": "power-saver", "glyph": "󰌪", "label": "SAVER" }
                            ]
                            Item {
                                id: profileChoice
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                readonly property bool selected: DeviceState.powerProfile === modelData.name
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: profileChoice.modelData.glyph; color: profileChoice.selected ? Theme.void_ : Theme.muted; font.family: Theme.fontIcon; font.pixelSize: 16 }
                                    Text { text: profileChoice.modelData.label; color: profileChoice.selected ? Theme.void_ : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Black }
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

                Text {
                    Layout.fillWidth: true
                    text: DeviceState.powerProfileAvailable
                        ? "POWER-PROFILES-DAEMON ONLINE // CHANGES APPLY IMMEDIATELY"
                        : "POWER PROFILES UNAVAILABLE // BATTERY INFO IS READ-ONLY"
                    color: DeviceState.powerProfileAvailable ? Theme.success : Theme.warning
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
