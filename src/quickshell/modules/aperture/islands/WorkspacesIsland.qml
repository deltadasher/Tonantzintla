import QtQuick
import "../../../components"
import "../../../services"
import "../../.."

BarIsland {
    id: root
    islandId: "workspaces"
    islandVisible: Settings.showWorkspaces
    reveal: barWindow ? barWindow.workspaceReveal : (typeof window !== "undefined" && window ? window.workspaceReveal : 1)
    property string outputName: ""
    readonly property bool isVertical: barWindow ? barWindow.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")

    WorkspaceOrbit { output: root.outputName }

    BarButton {
        implicitWidth: 30
        implicitHeight: 30
        glyph: "⊞"
        accessibleLabel: "Open Compositor workspace navigator"
        targetPanel: "workspaces"
        motionKind: "workspace"
        onActivated: root.toggleEphemeris("workspaces")
    }
}
