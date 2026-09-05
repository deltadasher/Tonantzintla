import QtQuick
import QtQuick.Layouts
import "../../../.."
import "../../../../services"

Item {
    id: root

    readonly property color phaseColor: Focus.phase === "focus" ? Theme.accent
        : Focus.phase === "long-break" ? Theme.success : Theme.cyan

    component OrbitButton: Rectangle {
        property string label: ""
        property bool primary: false
        property bool enabledControl: true
        signal activated
        implicitWidth: buttonLabel.implicitWidth + 26
        implicitHeight: 38
        radius: 12
        color: primary ? root.phaseColor
            : buttonPointer.containsMouse ? Theme.controlHover : Theme.controlRest
        border.width: 0
        opacity: enabledControl ? 1 : 0.38
        scale: buttonPointer.pressed ? 0.96 : buttonPointer.containsMouse ? 1.025 : 1
        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: parent.label
            color: parent.primary ? Theme.void_ : Theme.moon
            font.family: Theme.fontMono
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 0.6
        }
        MouseArea {
            id: buttonPointer
            anchors.fill: parent
            enabled: parent.enabledControl
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: parent.activated()
        }
        Behavior on scale { NumberAnimation { duration: Settings.motion ? 150 : 0; easing.type: Easing.OutBack } }
    }

    component StatCard: Rectangle {
        property string code: "STAT"
        property string value: "0"
        property string detail: ""
        property color tone: Theme.accent
        Layout.fillWidth: true
        Layout.preferredHeight: 78
        radius: Theme.radiusMedium
        color: Theme.controlRest
        border.width: 0
        border.color: Theme.barHairlineHover
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 2
            Text { text: parent.parent.code; color: parent.parent.tone; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1 }
            Text { text: parent.parent.value; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 21; font.weight: Font.Black }
            Text { text: parent.parent.detail; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.letterSpacing: 0.7 }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "FOCUS"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 23
                font.weight: Font.Black
            }
            Rectangle {
                Layout.preferredWidth: phaseStatus.implicitWidth + 24
                Layout.preferredHeight: 34
                radius: 11
                color: Qt.rgba(root.phaseColor.r, root.phaseColor.g, root.phaseColor.b, 0.11)
                border.width: 0
                border.color: Qt.rgba(root.phaseColor.r, root.phaseColor.g, root.phaseColor.b, 0.40)
                Row {
                    id: phaseStatus
                    anchors.centerIn: parent
                    spacing: 7
                    Rectangle { width: 7; height: 7; radius: 4; color: Focus.running ? Theme.success : root.phaseColor; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: Focus.phaseLabel; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Bold }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 344
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: Theme.mantle
                border.width: 0
                border.color: Focus.running ? Qt.rgba(root.phaseColor.r, root.phaseColor.g, root.phaseColor.b, 0.46) : Theme.barHairlineHover
                clip: true

                Rectangle {
                    anchors.centerIn: parent
                    width: 260
                    height: 260
                    radius: 130
                    color: root.phaseColor
                    opacity: Focus.running ? 0.075 : 0.035
                    SequentialAnimation on scale {
                        running: Settings.motion && Focus.running
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.08; duration: 1800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 1800; easing.type: Easing.InOutSine }
                    }
                }

                Item {
                    id: orbit
                    anchors.centerIn: parent
                    width: 252
                    height: 252
                    Repeater {
                        model: 48
                        Rectangle {
                            id: orbitSegment
                            required property int index
                            width: index % 4 === 0 ? 4 : 2
                            height: index % 4 === 0 ? 18 : 11
                            radius: 2
                            x: orbit.width / 2 - width / 2
                            y: 0
                            color: index < Math.round(Focus.progress * 48)
                                ? root.phaseColor : Theme.lineBright
                            opacity: index < Math.round(Focus.progress * 48) ? 0.95 : 0.22
                            transform: Rotation {
                                origin.x: orbitSegment.width / 2
                                origin.y: orbit.height / 2
                                angle: index * 7.5
                            }
                            Behavior on color { ColorAnimation { duration: 260 } }
                            Behavior on opacity { NumberAnimation { duration: 260 } }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    width: 238
                    spacing: 1
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Focus.displayTime
                        color: Theme.moon
                        font.family: Theme.fontDisplay
                        font.pixelSize: 48
                        font.weight: Font.Black
                        font.letterSpacing: 1
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Focus.phaseLabel
                        color: root.phaseColor
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1.3
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "CYCLE " + (Focus.completedCycles % Math.max(1, Focus.longBreakEvery) + 1)
                            + " / " + Focus.longBreakEvery
                        color: Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.letterSpacing: 0.8
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: [
                            { "id": "focus", "label": "FOCUS", "time": Focus.workMinutes },
                            { "id": "short-break", "label": "SHORT", "time": Focus.shortBreakMinutes },
                            { "id": "long-break", "label": "LONG", "time": Focus.longBreakMinutes }
                        ]
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            radius: 12
                            readonly property bool active: Focus.phase === modelData.id
                            color: active ? Qt.rgba(root.phaseColor.r, root.phaseColor.g, root.phaseColor.b, 0.14)
                                : phasePointer.containsMouse ? Theme.elevated : Theme.mantle
                            border.width: 0
                            border.color: active ? Qt.rgba(root.phaseColor.r, root.phaseColor.g, root.phaseColor.b, 0.50) : Theme.barHairlineHover
                            Column {
                                anchors.centerIn: parent
                                spacing: 1
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData.label; color: parent.parent.active ? root.phaseColor : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData.time + " MIN"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 11; font.weight: Font.Bold }
                            }
                            MouseArea { id: phasePointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Focus.selectPhase(parent.modelData.id) }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text { text: "FOCUS LENGTH"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.letterSpacing: 0.8 }
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: [25, 45, 60, 90]
                        Rectangle {
                            required property int modelData
                            Layout.preferredWidth: 52
                            Layout.preferredHeight: 30
                            radius: 9
                            readonly property bool active: Focus.workMinutes === modelData
                            color: active ? Theme.accentVeil : presetPointer.containsMouse ? Theme.elevated : Theme.barNeutral
                            border.width: 0
                            border.color: active ? Theme.accentLine : Theme.barHairlineHover
                            Text { anchors.centerIn: parent; text: parent.modelData; color: parent.active ? Theme.accent : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                            MouseArea { id: presetPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Focus.selectPreset(parent.modelData) }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    radius: 13
                    color: autoPointer.containsMouse ? Theme.elevated : Theme.mantle
                    border.width: 0
                    border.color: Focus.autoAdvance ? Theme.accentLine : Theme.barHairlineHover
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 13
                        anchors.rightMargin: 12
                        ColumnLayout { Layout.fillWidth: true; spacing: 1
                            Text { text: "AUTO-ADVANCE"; color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold }
                            Text { text: "FOCUS → SHORT BREAK // LONG BREAK EVERY " + Focus.longBreakEvery; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.letterSpacing: 0.5 }
                        }
                        Rectangle {
                            Layout.preferredWidth: 36; Layout.preferredHeight: 20; radius: 10
                            color: Focus.autoAdvance ? root.phaseColor : Theme.elevated
                            Rectangle { y: 3; x: Focus.autoAdvance ? 19 : 3; width: 14; height: 14; radius: 7; color: Focus.autoAdvance ? Theme.void_ : Theme.muted; Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutBack } } }
                        }
                    }
                    MouseArea { id: autoPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Focus.autoAdvance = !Focus.autoAdvance; Focus.queueSave(); } }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    OrbitButton {
                        Layout.fillWidth: true
                        primary: true
                        label: Focus.running ? "PAUSE" : Focus.progress > 0 ? "RESUME" : "START"
                        onActivated: Focus.toggle()
                    }
                    OrbitButton { label: "RESET"; onActivated: Focus.reset() }
                    OrbitButton { label: "SKIP ›"; onActivated: Focus.skipPhase() }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 88
                    radius: Theme.radiusMedium
                    color: Theme.mantle
                    border.width: 0
                    border.color: Theme.barHairlineHover
                    Text {
                        anchors.centerIn: parent
                        visible: Focus.weekFocusSeconds === 0
                        text: "NO SESSIONS YET\nYOUR FIRST ONE WILL SHOW HERE"
                        color: Theme.muted
                        opacity: 0.52
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.4
                    }
                    Row {
                        id: weekBars
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        spacing: 8
                        Repeater {
                            model: Focus.recentDays
                            Column {
                                required property var modelData
                                width: (weekBars.width - weekBars.spacing * 6) / 7
                                height: weekBars.height
                                spacing: 4
                                Item {
                                    width: parent.width
                                    height: parent.height - 18
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        width: Math.min(18, parent.width)
                                        height: Math.max(3, parent.height * modelData.ratio)
                                        radius: width / 2
                                        color: modelData.key === Focus.todayKey ? root.phaseColor : Theme.lineBright
                                        opacity: modelData.seconds > 0 ? 0.90 : 0.18
                                        Behavior on height { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }
                                    }
                                }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.label; color: parent.modelData.key === Focus.todayKey ? root.phaseColor : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StatCard { code: "TODAY"; value: Focus.formatDuration(Focus.todayFocusSeconds); detail: Focus.todaySessions + " SESSIONS DONE"; tone: root.phaseColor }
            StatCard { code: "SEVEN DAY"; value: Focus.formatDuration(Focus.weekFocusSeconds); detail: "FOCUS TIME"; tone: Theme.cyan }
            StatCard { code: "STREAK"; value: Focus.currentStreak + " DAYS"; detail: "BEST " + Focus.bestStreak + " DAYS"; tone: Theme.warning }
            StatCard { code: "ALL TIME"; value: Focus.completedSessions; detail: "SESSIONS DONE"; tone: Theme.success }
        }
    }
}
