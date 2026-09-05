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

    Image {
        id: artSource
        source: root.artUrl
        // Oversized so the blur never samples past its own edges, which would
        // leave a dark halo around the panel.
        width: parent.width * 1.6
        height: parent.height * 1.6
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        // artSource is already centred and oversized; matching its geometry is
        // enough. Adding centerIn as well would be a conflicting anchor.
        anchors.fill: artSource
        source: artSource
        visible: root.lit && artSource.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.45
        opacity: root.intensity
        Behavior on opacity {
            NumberAnimation { duration: Settings.motion ? 520 : 0; easing.type: Easing.OutCubic }
        }
    }

    // Radial falloff to the void colour. Painted only on resize, never live.
    Canvas {
        id: vignette
        anchors.fill: parent
        visible: root.lit

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2;
            const cy = height / 2;
            const reach = Math.max(width, height) * 0.78;
            const shade = ctx.createRadialGradient(cx, cy, reach * 0.30, cx, cy, reach);
            shade.addColorStop(0, Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0));
            shade.addColorStop(0.62, Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.42));
            shade.addColorStop(1, Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.94));
            ctx.fillStyle = shade;
            ctx.fillRect(0, 0, width, height);
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
        Connections {
            target: Theme
            // accent and void_ move together on a palette change; accent's
            // signal name is unambiguous where void_'s underscore is not.
            function onAccentChanged() { vignette.requestPaint(); }
        }
    }
}
