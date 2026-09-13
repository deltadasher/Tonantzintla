import QtQuick
import "../../../components"
import "../../../services"
import "../../.."

BarIsland {
    id: root
    islandId: "media"
    islandVisible: Settings.showMedia && Media.available
        && (root.isVertical || !barWindow || barWindow.width >= 1380)
    reveal: barWindow ? barWindow.mediaReveal : (typeof window !== "undefined" && window ? window.mediaReveal : 1)
    luminous: false

    MediaPill {
        id: mediaPill
        visible: !root.isVertical
        embedded: true
        outputName: root.barWindow ? root.barWindow.outputName : ""
        anchorHost: root
    }

    BarButton {
        id: mediaControl
        visible: root.isVertical
        glyph: "◉"
        accessibleLabel: "Open Resonance"
        targetPanel: "media"
        motionKind: "pulse"
        onActivated: root.toggleEphemeris("media", mediaControl)
    }
}
