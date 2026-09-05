import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"

Item {
    id: root

    property int activeTab: 0
    property bool railMode: false
    readonly property real currentProgress: activeTab === 0 ? Timekeeper.timerProgress
        : activeTab === 2 ? Focus.progress : 0
    readonly property bool currentRunning: activeTab === 0 ? Timekeeper.timerRunning
        : activeTab === 1 ? Timekeeper.stopwatchRunning : Focus.running

    component CapsuleButton: Rectangle {
        id: button
        property string label: "ACTION"
        property bool primary: false
        property bool enabled: true
        signal activated
        implicitWidth: Math.max(76, buttonLabel.implicitWidth + 24)
        implicitHeight: 38
        radius: 12
        color: !enabled ? Theme.mantle : primary
            ? (buttonPointer.containsMouse ? Theme.accent : Theme.accentVeil)
            : buttonPointer.containsMouse ? Theme.elevated : Theme.mantle
        border.width: 0
        border.color: primary ? Theme.accentLine : Theme.line
        opacity: enabled ? 1 : 0.4
        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: button.label
            color: button.primary && buttonPointer.containsMouse ? Theme.void_
                : button.primary ? Theme.accent : Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 0.5
        }
        MouseArea {
            id: buttonPointer
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.activated()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: "TIMERS"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 21
                font.weight: Font.Black
            }
            Rectangle {
                Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4
                color: root.currentRunning ? Theme.success : Theme.lineBright
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.currentRunning && Settings.motion
                    NumberAnimation { to: 0.25; duration: 650 }
                    NumberAnimation { to: 1; duration: 650 }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 12
            color: Theme.mantle
            border.width: 0
            border.color: Theme.line
            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 3
                Repeater {
                    model: ["TIMER", "STOPWATCH", "FOCUS"]
                    Rectangle {
                        id: tab
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 9
                        color: root.activeTab === index ? Theme.accent
                            : tabPointer.containsMouse ? Theme.elevated : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: tab.modelData
                            color: root.activeTab === tab.index ? Theme.void_ : Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                        MouseArea { id: tabPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.activeTab = tab.index }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                anchors.fill: parent
                visible: root.activeTab === 0
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 9
                    Item {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Canvas {
                            id: timerOrbit
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) - 8
                            height: width
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                const cx = width / 2, cy = height / 2, radius = Math.min(width, height) / 2 - 12;
                                ctx.lineWidth = 5;
                                ctx.strokeStyle = Theme.line.toString();
                                ctx.beginPath(); ctx.arc(cx, cy, radius, 0, Math.PI * 2); ctx.stroke();
                                ctx.strokeStyle = Theme.accent.toString();
                                ctx.lineCap = "round";
                                ctx.beginPath(); ctx.arc(cx, cy, radius, -Math.PI / 2,
                                    -Math.PI / 2 + Math.PI * 2 * root.currentProgress); ctx.stroke();
                                const angle = -Math.PI / 2 + Math.PI * 2 * root.currentProgress;
                                ctx.fillStyle = Theme.cyan.toString();
                                ctx.beginPath(); ctx.arc(cx + Math.cos(angle) * radius,
                                    cy + Math.sin(angle) * radius, 5, 0, Math.PI * 2); ctx.fill();
                            }
                            Connections {
                                target: Timekeeper
                                function onTimerRemainingMsChanged() { timerOrbit.requestPaint(); }
                            }
                            Connections {
                                target: Theme
                                function onAccentChanged() { timerOrbit.requestPaint(); }
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Timekeeper.timerDisplay; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: root.railMode ? 39 : 48; font.weight: Font.Black; font.letterSpacing: 1 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Timekeeper.timerRunning ? "RUNNING" : Timekeeper.timerProgress > 0 ? "PAUSED" : "COUNTDOWN READY"; color: Timekeeper.timerRunning ? Theme.success : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1 }
                        }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 5
                        Repeater {
                            model: [1, 5, 10, 15, 25]
                            CapsuleButton { required property int modelData; label: modelData + "M"; primary: Timekeeper.timerPresetSeconds === modelData * 60; enabled: !Timekeeper.timerRunning; onActivated: Timekeeper.selectTimer(modelData) }
                        }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 7
                        CapsuleButton { label: "− 1 MIN"; enabled: !Timekeeper.timerRunning; onActivated: Timekeeper.adjustTimer(-60) }
                        CapsuleButton { label: Timekeeper.timerRunning ? "PAUSE" : Timekeeper.timerProgress > 0 ? "RESUME" : "LAUNCH"; primary: true; onActivated: Timekeeper.toggleTimer() }
                        CapsuleButton { label: "+ 1 MIN"; enabled: !Timekeeper.timerRunning; onActivated: Timekeeper.adjustTimer(60) }
                        CapsuleButton { label: "RESET"; onActivated: Timekeeper.resetTimer() }
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: root.activeTab === 1
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Item { Layout.fillHeight: true; Layout.fillWidth: true
                        Column {
                            anchors.centerIn: parent
                            spacing: 5
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Timekeeper.stopwatchDisplay; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: root.railMode ? 36 : 48; font.weight: Font.Black; font.letterSpacing: 1 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Timekeeper.stopwatchRunning ? "MEASURING LOCAL TIME" : Timekeeper.stopwatchDisplayMs > 0 ? "STOPWATCH PAUSED" : "STOPWATCH READY"; color: Timekeeper.stopwatchRunning ? Theme.cyan : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1 }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(120, Math.max(58, Timekeeper.laps.length * 27 + 12))
                        radius: Theme.radiusMedium; color: Theme.mantle; border.width: 0; border.color: Theme.line; clip: true
                        ListView {
                            anchors.fill: parent; anchors.margins: 6; spacing: 3
                            model: Timekeeper.laps.slice().reverse()
                            delegate: Rectangle {
                                required property var modelData
                                width: ListView.view.width; height: 24; radius: 7; color: Theme.elevated
                                RowLayout { anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 9
                                    Text { text: "LAP " + modelData.number.toString().padStart(2, "0"); color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10 }
                                    Item { Layout.fillWidth: true }
                                    Text { text: "+" + Timekeeper.formatTime(modelData.split, true); color: Theme.cyan; font.family: Theme.fontMono; font.pixelSize: 10 }
                                    Text { text: Timekeeper.formatTime(modelData.total, true); color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold }
                                }
                            }
                            Text { anchors.centerIn: parent; visible: Timekeeper.laps.length === 0; text: "NO LAPS RECORDED"; color: Theme.lineBright; font.family: Theme.fontMono; font.pixelSize: 10 }
                        }
                    }
                    RowLayout { Layout.alignment: Qt.AlignHCenter; spacing: 8
                        CapsuleButton { label: Timekeeper.stopwatchRunning ? "PAUSE" : Timekeeper.stopwatchDisplayMs > 0 ? "RESUME" : "START"; primary: true; onActivated: Timekeeper.toggleStopwatch() }
                        CapsuleButton { label: "LAP"; enabled: Timekeeper.stopwatchRunning; onActivated: Timekeeper.addLap() }
                        CapsuleButton { label: "RESET"; onActivated: Timekeeper.resetStopwatch() }
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: root.activeTab === 2
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Item { Layout.fillHeight: true; Layout.fillWidth: true
                        Column {
                            anchors.centerIn: parent; spacing: 4
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Focus.displayTime; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: root.railMode ? 46 : 58; font.weight: Font.Black; font.letterSpacing: 2 }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Focus.phaseLabel + " // " + (Focus.running ? "IN PROGRESS" : "STANDBY")
                                color: Focus.running ? Theme.success : Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "EXPAND FOR CYCLES AND STATS"
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.letterSpacing: 0.7
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 8; radius: 4; color: Theme.line; clip: true
                        Rectangle { width: parent.width * Focus.progress; height: parent.height; radius: 4; color: Theme.accent; Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } }
                    }
                    RowLayout { Layout.alignment: Qt.AlignHCenter; spacing: 6
                        Repeater { model: [25, 45, 60]
                            CapsuleButton { required property int modelData; label: modelData + " MIN"; primary: Focus.workMinutes === modelData; onActivated: Focus.selectPreset(modelData) }
                        }
                    }
                    RowLayout { Layout.alignment: Qt.AlignHCenter; spacing: 8
                        CapsuleButton { label: Focus.running ? "PAUSE" : Focus.progress > 0 ? "RESUME" : "START"; primary: true; onActivated: Focus.toggle() }
                        CapsuleButton { label: "RESET"; onActivated: Focus.reset() }
                        CapsuleButton {
                            label: "OPEN FULL VIEW"
                            onActivated: {
                                ShellState.hideQuickActions();
                                ShellState.openEphemeris("focus");
                            }
                        }
                    }
                    Text { Layout.alignment: Qt.AlignHCenter; text: Focus.completedSessions + " SESSIONS DONE"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.letterSpacing: 1 }
                }
            }
        }
    }
}
