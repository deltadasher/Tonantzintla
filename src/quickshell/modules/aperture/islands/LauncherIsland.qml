import QtQuick
import "../../../components"
import "../../../services"
import "../../.."

BarIsland {
    id: root
    islandId: "launcher"
    reveal: barWindow ? barWindow.leftReveal : (typeof window !== "undefined" && window ? window.leftReveal : 1)
    luminous: false

    BarButton {
        id: guideControl
        glyph: ""
        accessibleLabel: "Open Tonantzintla manual"
        targetPanel: "guide"
        motionKind: "orbit"
        onActivated: root.toggleEphemeris("guide", guideControl)
        WabiSabiBlackHole {
            anchors.centerIn: parent
            width: root.isVertical ? 24 : 28
            height: root.isVertical ? 17 : 20
            diskColor: Theme.accent
            horizonColor: Theme.void_
        }
    }

    BarButton {
        id: launcherControl
        visible: Settings.showLauncherButton
        glyph: "⌕"
        accessibleLabel: "Open application launcher"
        targetPanel: Settings.defaultLaunchTab || "apps"
        motionKind: "lens"
        onActivated: root.toggleEphemeris(Settings.defaultLaunchTab || "apps", launcherControl)
    }

    BarButton {
        id: wallpaperControl
        glyph: "✦"
        accessibleLabel: "Open wallpaper observatory"
        targetPanel: "walls"
        motionKind: "star"
        onActivated: root.toggleEphemeris("walls", wallpaperControl)
    }
}
