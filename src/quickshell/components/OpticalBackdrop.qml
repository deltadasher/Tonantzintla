import QtQuick
import Quickshell
import ".."
import "../services"

// Opt in once on a native host: property var opticalBackdrop: field.
// This invisible provider shares a decoded still directly with ShaderEffect;
// it never captures the desktop or any Qt Quick item into a render target.
Item {
    id: root
    property bool active: true
    property string scope: "instruments"
    readonly property string material: Settings.controlFinishFor(scope)
    property size viewportSize: Qt.size(width, height)
    property point viewportOffset: Qt.point(0, 0)
    // Hosts with custom Transform objects invalidate mapping from their existing transition.
    property real geometryRevision: 0
    property string source: Settings.wallpaperPath || (Quickshell.shellDir + "/../assets/wallpapers/astral-observatory.png")
    property string sourceKind: Settings.wallpaperKind || "image"
    property string previewSource: {
        if (sourceKind !== "video") return "";
        const entry = Environment.localWallpapers.find(function(item) { return item.path === root.source; });
        return entry && entry.preview ? entry.preview : "";
    }
    readonly property string stillSource: sourceKind === "video" ? previewSource : source
    readonly property bool requested: active && visible && Settings.opticalControls && material !== "etched"
    readonly property var prepared: sourceKind !== "video" ? Environment.opticalPreviewFor(stillSource) : null
    readonly property string preparedSource: sourceKind === "video" ? previewSource : prepared ? prepared.preview : ""
    property bool preparationAccepted: true
    function syncRequest() {
        if (requested && sourceKind !== "video" && stillSource.length)
            preparationAccepted = Environment.requestOpticalPreview(root, stillSource);
        else { Environment.releaseOpticalPreview(root); preparationAccepted = true; }
    }
    Component.onCompleted: syncRequest()
    Component.onDestruction: Environment.releaseOpticalPreview(root)
    onRequestedChanged: syncRequest()
    onStillSourceChanged: syncRequest()
    onSourceKindChanged: syncRequest()
    readonly property var texture: imageLoader.item
    readonly property bool ready: !!texture && texture.status === Image.Ready
    readonly property string stateLabel: !requested ? "Etched control finish"
        : sourceKind === "video" && !previewSource ? "Video still unavailable · etched fallback"
        : !preparationAccepted ? "Optical still capacity reached · etched fallback"
        : sourceKind !== "video" && prepared && !prepared.preview ? prepared.message
        : sourceKind !== "video" && !preparedSource ? "Preparing optical still · etched fallback"
        : texture && texture.status === Image.Error ? "Wallpaper unavailable · etched fallback"
        : !ready ? "Loading wallpaper still · etched fallback"
        : GraphicsInfo.api === GraphicsInfo.Software ? "Software rendering · etched fallback"
        : sourceKind === "video" ? "Cached video still · no live video sampling" : "Wallpaper still · bounded optical field"
    readonly property vector2d cropScale: {
        if (!ready || width <= 0 || height <= 0) return Qt.vector2d(1, 1);
        const imageAspect = texture.implicitWidth / Math.max(1, texture.implicitHeight);
        const hostAspect = viewportSize.width / Math.max(1, viewportSize.height);
        return imageAspect > hostAspect ? Qt.vector2d(hostAspect / imageAspect, 1)
                                       : Qt.vector2d(1, imageAspect / hostAspect);
    }
    Loader {
        id: imageLoader
        active: root.requested && root.preparationAccepted && root.preparedSource.length > 0
        visible: false
        sourceComponent: Image {
            source: root.preparedSource.indexOf("/") === 0 ? "file://" + root.preparedSource : root.preparedSource
            sourceSize: root.sourceKind === "video" ? Qt.size(768, 768)
                : root.prepared ? Qt.size(root.prepared.width || 0, root.prepared.height || 0) : Qt.size(0, 0)
            asynchronous: true
            cache: true
            smooth: true
            mipmap: false
        }
    }
}
