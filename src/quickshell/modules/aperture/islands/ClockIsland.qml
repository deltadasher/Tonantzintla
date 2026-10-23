import QtQuick
import QtQuick.Controls
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
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Open calendar · " + Qt.formatDateTime(islandClock.date, Settings.clockFormat)
    Accessible.onPressAction: root.toggleEphemeris("calendar", root)
    Keys.onReturnPressed: root.toggleEphemeris("calendar", root)
    Keys.onSpacePressed: root.toggleEphemeris("calendar", root)
    border.width: activeFocus || ShellState.barEditMode ? 1 : 0
    border.color: Theme.accent

    property bool tooltipSuppressed: false
    onExtensionActiveChanged: if (extensionActive) tooltipSuppressed = true
    HoverHandler {
        id: clockHover
        onHoveredChanged: if (!hovered) root.tooltipSuppressed = false
    }
    ToolTip {
        visible: clockHover.hovered && !root.tooltipSuppressed && !root.extensionActive && !ShellState.barEditMode
        delay: 500
        text: "Open calendar"
        background: Rectangle { color: Theme.mantle; radius: Theme.radiusSmall; border.color: Theme.accentLine }
        contentItem: Text { text: "Open calendar"; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: Theme.textLabel }
    }
    readonly property bool isVertical: barWindow ? barWindow.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")

    readonly property string faceName: ["classic", "stacked", "compact"].indexOf(Settings.barClockFace) >= 0 ? Settings.barClockFace : "classic"

    SystemClock {
        id: islandClock
        enabled: root.visible
        precision: Settings.showSeconds || (root.faceName === "classic" && !root.compactContent) ? SystemClock.Seconds : SystemClock.Minutes
    }

    Rectangle {
        visible: !root.isVertical && root.faceName === "classic"
        width: 2
        height: 18
        radius: 1
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.70)
    }

    ApertureClockFace {
        dateTime: islandClock.date
        variant: root.faceName
        vertical: root.isVertical
        compact: root.compactContent
    }

    Rectangle {
        visible: Weather.available && !root.isVertical && (!barWindow || barWindow.width >= 1220)
        width: 1
        height: 18
        color: Theme.barHairlineHover
    }

    Loader {
        active: Weather.available && !root.isVertical && (!barWindow || barWindow.width >= 1220)
        visible: active
        sourceComponent: RowLayout {
            spacing: 5

            Text {
                text: Weather.current.icon || "☾"
                color: Theme.muted
                font.family: Theme.iconFamily(text)
                font.pixelSize: 16
            }
            Text {
                text: Math.round(Number(Weather.current.temp || 0)) + Weather.unitSymbol
                color: Theme.moon
                font.family: Theme.fontMono
                font.pixelSize: Theme.textCaption
                font.weight: Font.DemiBold
            }
        }
    }

    TapHandler {
        onTapped: root.toggleEphemeris("calendar", root)
    }
}
