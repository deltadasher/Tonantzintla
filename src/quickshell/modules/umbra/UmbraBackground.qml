import QtQuick
import QtQuick.Effects
import "../.."
import "../../services"

Item {
    id: root
    property bool active: false
    property bool preview: false
    property bool videoEnabled: true
    readonly property string mode: Settings.umbraBackgroundMode
    readonly property string customPath: Settings.umbraBackgroundPath
    readonly property url fallback: fileUrl(Environment.bundledRoot + "/umbra-array.png")
    readonly property url stillSource: mode === "image" && customPath.length ? fileUrl(customPath)
        : mode === "inherit" && Settings.umbraUseWallpaper && Settings.wallpaperKind === "image" && Settings.wallpaperPath.length
            ? fileUrl(Settings.wallpaperPath) : fallback
    readonly property url actualStillSource: imageLoader.item && imageLoader.item.failed ? fallback : stillSource
    readonly property bool videoLoaded: video.item !== null
    readonly property bool videoPlaying: video.item ? video.item.ready : false
    readonly property bool videoWanted: active && videoEnabled && mode === "video" && Umbra.videoAvailable
    readonly property string statusText: mode === "video"
        ? !Umbra.videoAvailable ? Umbra.backgroundInfo.message
            : !videoEnabled ? "Video paused · still background shown"
            : video.status === Loader.Error || (video.item && video.item.failed) ? "Video unavailable · still background shown" : "Silent loop · first 8 seconds · 640 × 360 / 12 fps"
        : imageLoader.item && imageLoader.item.failed ? "Image unavailable · bundled background shown" : ""
    function fileUrl(path) { return path.indexOf("file:") === 0 ? path : "file://" + path; }
    Component.onCompleted: Umbra.inspectBackground()
    Rectangle { anchors.fill: parent; color: Theme.void_ }
    Loader {
        id: imageLoader
        anchors.fill: parent
        active: root.active && root.mode !== "solid"
            && !(video.item && video.item.ready && video.status === Loader.Ready)
        sourceComponent: Settings.umbraBlurWallpaper && root.GraphicsInfo.api !== GraphicsInfo.Software ? blurredStill : directStill
    }
    Component {
        id: directStill
        Image {
            id: directImage
            property bool failed: false
            source: failed ? root.fallback : root.stillSource
            onStatusChanged: if (status === Image.Error && !failed) failed = true
            Connections { target: root; function onStillSourceChanged() { directImage.failed = false; } }
            sourceSize: Qt.size(1280, 720)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true; cache: false
        }
    }
    Component {
        id: blurredStill
        Item {
            property bool failed: art.status === Image.Error
            // Render the existing blur at a fixed low resolution, then scale
            // that small result. No full-screen captured source/render layer.
            Item {
                width: 320; height: 180
                transform: Scale { xScale: root.width / 320; yScale: root.height / 180 }
                Image {
                    id: art
                    anchors.fill: parent
                    source: root.stillSource
                    sourceSize: Qt.size(640, 360)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true; cache: false
                    visible: false
                    layer.enabled: true
                    layer.textureSize: Qt.size(320, 180)
                }
                Image {
                    anchors.fill: parent
                    visible: art.status === Image.Error
                    source: visible ? root.fallback : ""
                    sourceSize: Qt.size(320, 180)
                    fillMode: Image.PreserveAspectCrop
                }
                MultiEffect {
                    anchors.fill: parent; source: art
                    visible: art.status === Image.Ready
                    blurEnabled: true; blur: .68; blurMax: 32
                    saturation: -.25; brightness: -.08
                }
            }
        }
    }
    Loader {
        id: video
        anchors.fill: parent
        active: root.videoWanted
        source: active ? Qt.resolvedUrl("UmbraVideo.qml") : ""
        onLoaded: { item.source = Qt.binding(function() { return Umbra.backgroundInfo.path || ""; }); item.playing = true; }
    }
    Rectangle { anchors.fill: parent; color: Theme.void_; opacity: Settings.umbraBlurWallpaper ? .84 : .86 }
}
