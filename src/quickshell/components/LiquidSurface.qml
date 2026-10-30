import QtQuick
import Quickshell
import ".."

// Wallpaper optics, not a desktop capture. One cached, bounded still; no frame timer.
Item {
    id: root
    property string material: "classic"
    property real radius: 10
    property real fillOpacity: 1
    property real frost: Settings.surfaceFrost
    property real refraction: Settings.surfaceRefraction
    property real tintAmount: Settings.surfaceTint
    property color tint: Theme.accent
    property color backing: Theme.void_
    property string edgeStyle: "none"
    property bool hovered: false
    property size viewportSize: Qt.size(width, height)
    property point viewportOrigin: Qt.point(0, 0)
    property string wallpaperSource: Settings.wallpaperKind === "video" ? "" : Settings.wallpaperPath
    readonly property bool glassRequested: material === "frosted" || material === "liquid"
    readonly property bool hardware: GraphicsInfo.api !== GraphicsInfo.Software
    readonly property bool textureReady: !!still.item && still.item.status === Image.Ready
    readonly property bool usable: glassRequested && hardware && textureReady && !!effect.item && effect.item.status !== ShaderEffect.Error
    // Passive pointer tracking never takes button presses from the bar or panel.
    HoverHandler {
        id: pointer
        enabled: root.visible && root.usable && root.material === "liquid" && Theme.motionScale > 0
    }
    readonly property string statusText: !glassRequested ? ""
        : !hardware ? "Glass unavailable with software rendering; using a solid surface."
        : !wallpaperSource ? "Choose a still wallpaper for refraction; using a solid surface."
        : still.item && still.item.status === Image.Error ? "Wallpaper unavailable; using a solid surface."
        : !textureReady ? "Preparing glass…"
        : effect.item && effect.item.status === ShaderEffect.Error ? "Glass unavailable; using a solid surface." : ""

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        visible: !root.usable
        color: Qt.rgba(root.backing.r, root.backing.g, root.backing.b,
            root.glassRequested ? 1 : Math.max(0, Math.min(1, root.fillOpacity)))
    }
    Loader {
        id: still
        active: root.visible && root.glassRequested && root.hardware && root.wallpaperSource.length > 0
        visible: false
        sourceComponent: Image {
            source: {
                const url = root.wallpaperSource.indexOf("/") === 0 ? "file://" + root.wallpaperSource : root.wallpaperSource;
                // Keep one shared mipmapped entry, separate from ordinary wallpaper
                // consumers whose uploaded textures may no longer retain image data.
                return url.indexOf("file:") === 0
                    ? url + (url.indexOf("?") >= 0 ? "&" : "?") + "tonantzintla-glass=mipmapped" : url;
            }
            sourceSize: Qt.size(1024, 1024)
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
        }
    }
    Loader {
        id: effect
        anchors.fill: parent
        active: root.visible && root.glassRequested && root.hardware && root.textureReady
        sourceComponent: ShaderEffect {
            property var wallpaper: still.item
            property vector2d viewport: Qt.vector2d(width, height)
            property vector2d fieldSize: Qt.vector2d(Math.max(1, root.viewportSize.width), Math.max(1, root.viewportSize.height))
            property vector2d fieldOrigin: Qt.vector2d(root.viewportOrigin.x, root.viewportOrigin.y)
            property vector2d cropScale: {
                const imageAspect = still.item.implicitWidth / Math.max(1, still.item.implicitHeight);
                const fieldAspect = fieldSize.x / fieldSize.y;
                return imageAspect > fieldAspect ? Qt.vector2d(fieldAspect / imageAspect, 1) : Qt.vector2d(1, imageAspect / fieldAspect);
            }
            property real cornerRadius: root.radius
            property real strength: root.material === "liquid" ? Math.max(0, Math.min(1, root.refraction)) : 0
            property real frostAmount: Math.max(root.material === "frosted" ? 0.7 : 0, Math.min(1, root.frost))
            property real pigment: Math.max(0, Math.min(1, root.tintAmount))
            property real density: Math.max(0.3, Math.min(1, root.fillOpacity))
            property real lightMode: Theme.isLight ? 1 : 0
            property real hoverAmount: Theme.motionScale > 0 && (root.hovered || pointer.hovered) ? 1 : 0
            Behavior on hoverAmount { NumberAnimation { duration: Math.round(160 * Theme.motionScale); easing.type: Easing.OutCubic } }
            property vector2d pointerPosition: pointer.hovered
                ? Qt.vector2d(pointer.point.position.x, pointer.point.position.y)
                : Qt.vector2d(width / 2, height / 2)
            property real liquid: root.material === "liquid" ? 1 : 0
            property color tint: root.tint
            property color backing: root.backing
            // A revision key also invalidates Qt's process-wide baked-shader cache on hot reload.
            fragmentShader: Qt.resolvedUrl("shaders/liquid-surface.frag.qsb?revision=2")
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        antialiasing: true
        border.width: root.edgeStyle === "none" ? 0 : 1
        border.color: root.edgeStyle === "accent" ? Qt.rgba(root.tint.r, root.tint.g, root.tint.b, .55)
            : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, root.hovered ? .26 : .16)
    }
}
