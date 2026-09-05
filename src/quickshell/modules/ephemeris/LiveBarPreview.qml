import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."

Rectangle {
    id: root

    radius: Theme.radiusLarge
    color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.72)
    border.width: 0
    border.color: Theme.line
    clip: true

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Repeater {
        model: 8
        Rectangle {
            required property int index
            x: ((index * 71) % 997) / 997 * root.width
            y: ((index * 43 + 19) % 211) / 211 * root.height
            width: index % 3 === 0 ? 3 : 2
            height: width
            radius: width / 2
            color: index % 2 === 0 ? Theme.accent : Theme.lineBright
            opacity: 0.28
        }
    }

    Rectangle {
        id: barBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Settings.barMode === "docked" ? 0 : 16
        anchors.rightMargin: Settings.barMode === "docked" ? 0 : 16
        anchors.verticalCenter: parent.verticalCenter
        height: Settings.compact ? 32 : 42
        radius: Settings.barMode === "docked" ? 0 : 14
        color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, Settings.barOpacity)
        border.width: 0
        border.color: Theme.line
        opacity: Settings.barMode === "capsules" ? 0 : 1
    }

    RowLayout {
        anchors.left: barBody.left
        anchors.leftMargin: 8
        anchors.verticalCenter: barBody.verticalCenter
        spacing: Settings.barMode === "capsules" ? 5 : 2

        Repeater {
            model: [
                { "show": Settings.showLauncherButton, "text": "⌕" },
                { "show": Settings.showWorkspaces, "text": "1  2  3" },
                { "show": Settings.showMedia, "text": "♪  MEDIA" }
            ]
            Rectangle {
                required property var modelData
                visible: modelData.show
                Layout.preferredWidth: Math.max(34, leftLabel.implicitWidth + 18)
                Layout.preferredHeight: Settings.compact ? 25 : 31
                radius: 10
                color: Settings.barMode === "capsules" ? Theme.mantle : "transparent"
                border.width: 0
                border.color: Theme.line
                Text { id: leftLabel; anchors.centerIn: parent; text: parent.modelData.text; color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
            }
        }
    }

    Rectangle {
        anchors.centerIn: barBody
        width: 118
        height: Settings.compact ? 25 : 31
        radius: 10
        color: Settings.barMode === "capsules" ? Theme.mantle : "transparent"
        border.width: 0
        border.color: Theme.line
        Text { anchors.centerIn: parent; text: Qt.formatDateTime(clock.date, Settings.clockFormat); color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 14; font.weight: Font.Black; font.letterSpacing: 1 }
    }

    RowLayout {
        anchors.right: barBody.right
        anchors.rightMargin: 8
        anchors.verticalCenter: barBody.verticalCenter
        spacing: 4
        Repeater {
            model: [
                { "show": Settings.showNetworkLabel, "text": "NET" },
                { "show": Settings.showAudio, "text": "VOL 40" },
                { "show": Settings.showBattery, "text": "PWR 76" }
            ]
            Rectangle {
                required property var modelData
                visible: modelData.show
                Layout.preferredWidth: rightLabel.implicitWidth + 16
                Layout.preferredHeight: Settings.compact ? 25 : 31
                radius: 10
                color: Settings.barMode === "capsules" ? Theme.mantle : "transparent"
                border.width: 0
                border.color: Theme.line
                Text { id: rightLabel; anchors.centerIn: parent; text: parent.modelData.text; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 13
        anchors.top: parent.top
        anchors.topMargin: 8
        text: "LIVE BAR PREVIEW"
        color: Theme.muted
        font.family: Theme.fontMono
        font.pixelSize: 10
        font.weight: Font.Bold
        font.letterSpacing: 1
    }
}
