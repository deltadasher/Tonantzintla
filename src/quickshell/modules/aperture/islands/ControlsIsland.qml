import QtQuick
import "../../../components"
import "../../../services"
import "../../.."

BarIsland {
    id: root
    islandId: "controls"
    reveal: barWindow ? barWindow.rightReveal : (typeof window !== "undefined" && window ? window.rightReveal : 1)
    luminous: false
    readonly property bool isVertical: barWindow ? barWindow.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")

    NotificationIndicator {
        id: notificationControl
        onActivated: root.toggleEphemeris("notifications", notificationControl)
    }

    BarButton {
        id: settingsControl
        visible: Settings.showSettingsButton
        glyph: "⚙"
        accessibleLabel: "Open settings"
        targetPanel: "settings"
        motionKind: "gear"
        onActivated: root.toggleEphemeris("settings", settingsControl)
    }
}
