import QtQuick
import "../../../.."

// The track's position drawn as a body in orbit: an arc sweeps clockwise from
// twelve o'clock around whatever sits in the middle, and a moon rides its
// head. Dragging the moon scrubs the track, so the ring is a seek control,
// not a decoration.
Item {
    id: root

    property real progress: 0
    property real orbitRadius: 140
    property bool playing: false
    property bool enabledControl: true
    property bool interacting: false
    property real previewProgress: progress
    signal seekRequested(real progress)

    readonly property real shown: interacting ? previewProgress : progress

    function progressAt(x, y) {
        const angle = Math.atan2(y - height / 2, x - width / 2);
        // Canvas angles run from three o'clock; the orbit starts at twelve.
        return ((angle + Math.PI / 2) / (Math.PI * 2) + 1) % 1;
    }

    Canvas {
        id: orbit
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2;
            const cy = height / 2;
            const start = -Math.PI / 2;

            // The whole orbit, faint, so the swept part reads against it.
            ctx.beginPath();
            ctx.arc(cx, cy, root.orbitRadius, 0, Math.PI * 2);
            ctx.strokeStyle = Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.16);
            ctx.lineWidth = 2;
            ctx.stroke();

            for (let mark = 0; mark < 8; mark++) {
                const angle = start + mark / 8 * Math.PI * 2;
                const inner = root.orbitRadius + 7;
                const outer = root.orbitRadius + (mark % 2 === 0 ? 14 : 11);
                ctx.beginPath();
                ctx.moveTo(cx + Math.cos(angle) * inner, cy + Math.sin(angle) * inner);
                ctx.lineTo(cx + Math.cos(angle) * outer, cy + Math.sin(angle) * outer);
                ctx.strokeStyle = Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b,
                    mark % 2 === 0 ? 0.34 : 0.16);
                ctx.lineWidth = mark % 2 === 0 ? 2 : 1;
                ctx.stroke();
            }

            const swept = Math.max(0, Math.min(1, root.shown));
            if (swept > 0.001) {
                ctx.beginPath();
                ctx.arc(cx, cy, root.orbitRadius, start, start + swept * Math.PI * 2);
                ctx.strokeStyle = Qt.rgba(Theme.accent.r, Theme.accent.g,
                    Theme.accent.b, root.playing || root.interacting ? 0.92 : 0.45);
                ctx.lineWidth = 5;
                ctx.lineCap = "round";
                ctx.stroke();
            }

            // The moon at the head of the sweep.
            const head = start + swept * Math.PI * 2;
            const hx = cx + Math.cos(head) * root.orbitRadius;
            const hy = cy + Math.sin(head) * root.orbitRadius;
            ctx.beginPath();
            ctx.arc(hx, hy, root.interacting ? 13 : 9, 0, Math.PI * 2);
            ctx.fillStyle = Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(hx, hy, root.interacting ? 6.5 : 4.5, 0, Math.PI * 2);
            ctx.fillStyle = Theme.moon;
            ctx.fill();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }

    Connections {
        target: root
        function onProgressChanged() { orbit.requestPaint(); }
        function onPreviewProgressChanged() { orbit.requestPaint(); }
        function onInteractingChanged() { orbit.requestPaint(); }
        function onPlayingChanged() { orbit.requestPaint(); }
    }
    Connections {
        target: Theme
        function onAccentChanged() { orbit.requestPaint(); }
        function onMoonChanged() { orbit.requestPaint(); }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabledControl
        hoverEnabled: true

        // Only the ring band seeks; the middle belongs to whatever it wraps.
        function onRing(x, y) {
            const distance = Math.hypot(x - width / 2, y - height / 2);
            return Math.abs(distance - root.orbitRadius) <= 20;
        }

        cursorShape: root.interacting || onRing(mouseX, mouseY)
            ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton

        onPressed: function(mouse) {
            if (!onRing(mouse.x, mouse.y)) {
                mouse.accepted = false;
                return;
            }
            root.interacting = true;
            root.previewProgress = root.progressAt(mouse.x, mouse.y);
        }
        onPositionChanged: function(mouse) {
            if (root.interacting)
                root.previewProgress = root.progressAt(mouse.x, mouse.y);
        }
        onReleased: function(mouse) {
            if (!root.interacting)
                return;
            root.previewProgress = root.progressAt(mouse.x, mouse.y);
            root.seekRequested(root.previewProgress);
            root.interacting = false;
        }
    }
}
