import Quickshell

// One monitor can host independent instruments on every edge. Each host only
// maps when its edge owns at least one island.
Scope {
    id: root
    required property var modelData

    ApertureBar { modelData: root.modelData; edge: "top" }
    ApertureBar { modelData: root.modelData; edge: "right" }
    ApertureBar { modelData: root.modelData; edge: "bottom" }
    ApertureBar { modelData: root.modelData; edge: "left" }
}
