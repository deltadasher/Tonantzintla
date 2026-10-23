import QtQuick
import ".."

// The backing follows the same safe geometry as the rounded content mask.
// Draw the simple rounded panel directly in the scene graph: a monitor-sized
// Canvas allocated a full raster even when the instrument occupied a corner.
Item {
    id: root
    required property var geometry
    property string edge: "top"
    property color fillColor: Theme.mantle
    property bool attached: false

    Rectangle {
        x: root.geometry.x
        y: root.geometry.y
        width: Math.max(0, root.geometry.width)
        height: Math.max(0, root.geometry.height)
        radius: Math.max(0, Math.min(root.geometry.radius, width / 2, height / 2))
        color: root.fillColor
        antialiasing: true
    }
}
