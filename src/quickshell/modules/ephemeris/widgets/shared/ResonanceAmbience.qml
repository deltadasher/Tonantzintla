import QtQuick
import QtQuick.Effects
import "../../../.."

// The panel takes the light of whatever is playing: the cover art, blown well
// past the panel edges and blurred to colour, sits under every Resonance tab.
// A vignette pulls the edges back down so type and controls keep their
// contrast. With no art the whole thing stays dark and costs nothing.
Item {
    id: root

    property string artUrl: ""
    property real intensity: 0.34

    readonly property bool lit: artUrl.length > 0
    clip: true

    // Blur at a deliberately small resolution, then scale the finished light.
    // Bounding only Image.sourceSize would still leave full-panel blur targets.
    Item {
        id: lightField
        width: 256
        height: 256
        x: -root.width * 0.3
        y: -root.height * 0.3
        visible: root.lit
        transform: Scale {
            xScale: root.width * 1.6 / lightField.width
            yScale: root.height * 1.6 / lightField.height
        }
        Image {
            id: artSource
            anchors.fill: parent
            source: root.artUrl
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
            layer.enabled: root.lit && status === Image.Ready
            layer.textureSize: Qt.size(256, 256)
        }
        MultiEffect {
            anchors.fill: artSource
            source: artSource
            visible: root.lit && artSource.status === Image.Ready
            blurEnabled: true
            blur: 1.0
            blurMax: 32
            saturation: 0.45
            opacity: root.intensity
            Behavior on opacity {
                NumberAnimation { duration: Theme.duration(520); easing.type: Easing.OutCubic }
            }
        }
    }

    // Smooth radial falloff needs only a small texture; retain the panel-space
    // gradient geometry while rasterizing at256². Repaint on resize, never live.
    Canvas {
        id: vignette
        width: 256; height: 256
        readonly property real sceneWidth: Math.max(1, root.width)
        readonly property real sceneHeight: Math.max(1, root.height)
        transform: Scale { xScale: root.width / 256; yScale: root.height / 256 }
        visible: root.lit

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.scale(256 / sceneWidth, 256 / sceneHeight);
            const cx = sceneWidth / 2;
            const cy = sceneHeight / 2;
            const reach = Math.max(sceneWidth, sceneHeight) * 0.78;
            const shade = ctx.createRadialGradient(cx, cy, reach * 0.30, cx, cy, reach);
            shade.addColorStop(0, Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0));
            shade.addColorStop(0.62, Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.42));
            shade.addColorStop(1, Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.94));
            ctx.fillStyle = shade;
            ctx.fillRect(0, 0, sceneWidth, sceneHeight);
        }

        onSceneWidthChanged: requestPaint()
        onSceneHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
        Connections {
            target: Theme
            // accent and void_ move together on a palette change; accent's
            // signal name is unambiguous where void_'s underscore is not.
            function onAccentChanged() { vignette.requestPaint(); }
        }
    }
}
