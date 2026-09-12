import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../components"
import "../../../services"
import "../../.."

BarIsland {
    id: root
    islandId: "clock"
    reveal: barWindow ? barWindow.centerReveal : (typeof window !== "undefined" && window ? window.centerReveal : 1)
    luminous: false
    readonly property bool isVertical: barWindow ? barWindow.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")

    SystemClock {
        id: islandClock
        precision: SystemClock.Seconds
    }

    Rectangle {
        visible: !root.isVertical
        width: 2
        height: 18
        radius: 1
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.70)
    }

    ColumnLayout {
        spacing: root.isVertical ? 1 : -2

        Text {
            text: root.isVertical
                ? Qt.formatDateTime(islandClock.date, "HH\nmm")
                : Qt.formatDateTime(islandClock.date, Settings.clockFormat)
            color: Theme.moon
            font.family: Theme.fontDisplay
            font.pixelSize: root.isVertical ? 13 : (Settings.compact ? 16 : 20)
            font.weight: Font.Bold
            font.letterSpacing: root.isVertical ? 0.4 : 0.8
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
            lineHeight: root.isVertical ? 0.88 : 1.0
        }
        Text {
            visible: Settings.showDate && !root.isVertical
            text: Qt.formatDateTime(islandClock.date, Settings.dateFormat)
            color: Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: 10
            font.letterSpacing: 1.1
            Layout.alignment: Qt.AlignHCenter
        }
        Rectangle {
            visible: !Settings.compact && !root.isVertical
            Layout.preferredWidth: 92
            Layout.preferredHeight: 1
            color: Theme.barHairlineHover
            Rectangle {
                width: parent.width * islandClock.date.getSeconds() / 59
                height: 1
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }
        }
    }

    Rectangle {
        visible: Weather.available && !root.isVertical && (!barWindow || barWindow.width >= 1220)
        width: 1
        height: 18
        color: Theme.barHairlineHover
    }

    RowLayout {
        visible: Weather.available && !root.isVertical && (!barWindow || barWindow.width >= 1220)
        spacing: 5

        Text {
            text: Weather.current.icon || "☾"
            color: Theme.muted
            font.family: Theme.fontIcon
            font.pixelSize: 16
        }
        Text {
            text: Math.round(Number(Weather.current.temp || 0)) + Weather.unitSymbol
            color: Theme.moon
            font.family: Theme.fontMono
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }

    TapHandler {
        onTapped: root.toggleEphemeris("calendar")
    }
}
