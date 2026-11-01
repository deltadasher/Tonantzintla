// Keep approved geometry; optionally recolor the SVG with the interface accent.
import QtQuick
import Quickshell.Io
import ".."
import "ThemeIdentity.js" as Identity
import "LogoColor.js" as LogoColor

Item {
    id: root
    property string identity: Theme.identity.id
    readonly property var mark: Identity.get(identity)
    property bool useThemeColor: Settings.logoColorMode === "theme"
    property color tintColor: Theme.accent
    readonly property url originalSource: Qt.resolvedUrl("../assets/theme-marks/" + mark.id + ".svg")
    readonly property string assetPath: decodeURIComponent(String(originalSource).replace(/^file:\/\//, ""))
    property string loadedSvg: ""
    property string loadedPath: ""
    readonly property url artworkSource: useThemeColor && loadedPath === assetPath && loadedSvg.length > 0
        ? "data:image/svg+xml;charset=utf-8," + encodeURIComponent(LogoColor.recolor(loadedSvg, mark.id, mark.color, String(tintColor)))
        : originalSource
    // Read only when recoloring is requested; no watcher, process or polling.
    FileView {
        path: root.useThemeColor ? root.assetPath : ""
        watchChanges: false
        printErrors: false
        onLoaded: { root.loadedSvg = text(); root.loadedPath = path; }
        onLoadFailed: { root.loadedSvg = ""; root.loadedPath = ""; }
    }
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
        source: root.artworkSource
        sourceSize.width: Math.ceil(width * Screen.devicePixelRatio * 2)
        sourceSize.height: Math.ceil(height * Screen.devicePixelRatio * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }
}
