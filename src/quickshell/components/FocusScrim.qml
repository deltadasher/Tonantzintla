import QtQuick
import ".."

// Dims the whole screen except one rectangle, so the thing being configured is
// the only thing still lit.
//
// This was a Canvas that punched the hole with destination-out compositing.
// It rendered nothing at all on the real shell, and Canvas compositing is not
// something this repository can lint or preview, so the hole is now four plain
// Rectangles laid around the focus rect. Four solid fills of one colour show no
// seam where they meet, and a Rectangle either paints or the file fails to
// load -- there is no third outcome to debug from a screenshot.
Item {
    id: root

    // The region left undimmed, in this item's coordinates.
    property real focusX: 0
    property real focusY: 0
    property real focusWidth: 0
    property real focusHeight: 0
    property real focusRadius: 10
    // Breathing room left around the target.
    property real halo: 6
    property real dim: 0.62

    readonly property bool hasFocus: focusWidth > 0 && focusHeight > 0
    readonly property color scrimColor: Qt.rgba(Theme.void_.r, Theme.void_.g,
        Theme.void_.b, root.dim)

    // Edges of the cutout, clamped into this item. With no focus they collapse
    // to a zero-height band at the top, which leaves the bottom band covering
    // the whole screen -- a plain full dim, no special case needed.
    readonly property real holeLeft: hasFocus
        ? Math.max(0, Math.min(width, focusX - halo)) : 0
    readonly property real holeRight: hasFocus
        ? Math.max(0, Math.min(width, focusX + focusWidth + halo)) : 0
    readonly property real holeTop: hasFocus
        ? Math.max(0, Math.min(height, focusY - halo)) : 0
    readonly property real holeBottom: hasFocus
        ? Math.max(0, Math.min(height, focusY + focusHeight + halo)) : 0

    Rectangle {
        x: 0
        y: 0
        width: root.width
        height: root.holeTop
        color: root.scrimColor
    }

    Rectangle {
        x: 0
        y: root.holeBottom
        width: root.width
        height: Math.max(0, root.height - root.holeBottom)
        color: root.scrimColor
    }

    Rectangle {
        x: 0
        y: root.holeTop
        width: root.holeLeft
        height: Math.max(0, root.holeBottom - root.holeTop)
        color: root.scrimColor
    }

    Rectangle {
        x: root.holeRight
        y: root.holeTop
        width: Math.max(0, root.width - root.holeRight)
        height: Math.max(0, root.holeBottom - root.holeTop)
        color: root.scrimColor
    }

    // A ring around the cutout so the lit thing reads as deliberately chosen
    // rather than as a gap in the dimming.
    Rectangle {
        visible: false
        x: root.focusX - root.halo
        y: root.focusY - root.halo
        width: root.focusWidth + root.halo * 2
        height: root.focusHeight + root.halo * 2
        radius: Math.min(root.focusRadius + root.halo, width / 2, height / 2)
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
    }

    Behavior on dim {
        NumberAnimation { duration: Settings.motion ? 180 : 0; easing.type: Easing.OutCubic }
    }
}
