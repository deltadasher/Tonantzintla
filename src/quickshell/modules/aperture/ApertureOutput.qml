import Quickshell
import "../.."

// Empty edge hosts are absent until editing needs their drop targets.
Scope {
    id: root
    required property var modelData

    Variants {
        model: ["top", "right", "bottom", "left"].filter(edge => {
            if (ShellState.barEditMode) return true;
            const layout = Settings.getEdgeBarLayout(root.modelData.name, edge);
            // Dock owns a separate native host outside the shared edit targets.
            return ["start", "center", "end"].some(zone =>
                layout[zone].some(island => island !== "dock"));
        })
        Scope {
            id: edgeScope
            required property string modelData
            ApertureBar { modelData: root.modelData; edge: edgeScope.modelData }
        }
    }
    Variants {
        model: Settings.dockEnabled && Settings.dockOnOutput(root.modelData.name)
            ? [root.modelData] : []
        ApertureDock { }
    }
}
