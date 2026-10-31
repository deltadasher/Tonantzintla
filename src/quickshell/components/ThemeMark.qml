// Render the approved artwork in its own colors, independent of Matugen.
import QtQuick
import ".."
import "ThemeIdentity.js" as Identity

Item {
    id: root
    property string identity: Theme.identity.id
    readonly property var mark: Identity.get(identity)
    readonly property var bounds: mark.bounds
    readonly property real artworkScale: Math.max(0, Math.min(width / bounds[2], height / bounds[3]))
    implicitWidth: 32
    implicitHeight: 32

    // Fit the painted shape, not the padded square artboard. The source SVG and
    // its aspect ratio stay intact, including Wabi-sabi's black event horizon.
    Image {
        x: (root.width - root.bounds[2] * root.artworkScale) / 2 - root.bounds[0] * root.artworkScale
        y: (root.height - root.bounds[3] * root.artworkScale) / 2 - root.bounds[1] * root.artworkScale
        width: 128 * root.artworkScale
        height: width
        source: Qt.resolvedUrl("../assets/theme-marks/" + root.mark.id + ".svg")
        sourceSize.width: Math.ceil(width * Screen.devicePixelRatio * 2)
        sourceSize.height: Math.ceil(height * Screen.devicePixelRatio * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }
}
