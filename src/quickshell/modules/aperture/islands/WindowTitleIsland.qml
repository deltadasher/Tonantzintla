import QtQuick
import "../../../components"
import "../../../services"
import "../../.."

BarIsland {
    id: root
    islandId: "window_title"
    // A placed island must remain present on every output.
    islandVisible: true
    reveal: barWindow ? barWindow.mediaReveal : (typeof window !== "undefined" && window ? window.mediaReveal : 1)

    FocusedSignal { visible: !root.isVertical }

    BarButton {
        visible: root.isVertical
        glyph: "▭"
        accessibleLabel: "Open workspace overview"
        targetPanel: "workspaces"
        motionKind: "workspace"
        onActivated: root.toggleEphemeris("workspaces")
    }
}
