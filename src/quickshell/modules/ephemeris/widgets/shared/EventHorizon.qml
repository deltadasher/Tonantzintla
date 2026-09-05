import QtQuick
import "../../../.."

// Tonantzintla's black hole. The accretion disk is seen almost edge-on while its
// far side is lensed up and over the horizon, which is the one feature that
// makes the shape read as gravity rather than a ringed planet.
//
// Painted once per resize or palette change: nothing here animates, so it
// costs a single raster and then nothing at all.
Item {
    id: root

    // Matugen drives the accent, so the disk recolours with the wallpaper.
    property color diskColor: Theme.accent
    property color edgeColor: Theme.rose
    property color hotColor: Theme.moon
    property color horizonColor: "#000000"
    // Horizon radius as a fraction of the smaller side.
    property real scaleFactor: 0.135
    property real intensity: 1.0

    readonly property real horizon: Math.min(width, height) * scaleFactor

    function blend(from, to, amount) {
        const t = Math.max(0, Math.min(1, amount));
        return Qt.rgba(from.r + (to.r - from.r) * t,
            from.g + (to.g - from.g) * t,
            from.b + (to.b - from.b) * t, 1);
    }

    Canvas {
        id: field
        anchors.fill: parent
        antialiasing: true

        // One concentric sweep of the disk, from `inner` to `outer` in
        // multiples of the horizon radius. Colour runs hot near the inside
        // out through the accent to the rim tone.
        function band(ctx, inner, outer, squash, from, to, steps, peak, thick) {
            const cx = width / 2;
            const cy = height / 2;
            const horizon = root.horizon;
            for (let index = 0; index < steps; index++) {
                const t = index / Math.max(1, steps - 1);
                const radius = horizon * (inner + t * (outer - inner));
                const warm = root.blend(root.hotColor, root.diskColor,
                    Math.min(1, t * 2.2));
                const tone = root.blend(warm, root.edgeColor,
                    Math.max(0, t - 0.55) * 1.9);
                const alpha = Math.max(0.02,
                    peak * Math.pow(1 - t, 1.35) * root.intensity);

                // Build the arc under a vertical squash, then restore before
                // stroking so the line keeps an even width.
                ctx.save();
                ctx.translate(cx, cy);
                ctx.scale(1, squash);
                ctx.beginPath();
                ctx.arc(0, 0, radius, from, to);
                ctx.restore();
                ctx.strokeStyle = Qt.rgba(tone.r, tone.g, tone.b, alpha);
                ctx.lineWidth = thick;
                ctx.stroke();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2;
            const cy = height / 2;
            const horizon = root.horizon;
            if (horizon < 8)
                return;

            // A quiet starfield so the hole has something to sit in.
            let seed = 20260901;
            function next() {
                seed = (Math.imul(seed, 1103515245) + 12345) & 0x7fffffff;
                return seed / 0x7fffffff;
            }
            for (let star = 0; star < 90; star++) {
                const sx = next() * width;
                const sy = next() * height;
                const roll = next();
                ctx.beginPath();
                ctx.arc(sx, sy, roll < 0.1 ? 1.7 : roll < 0.38 ? 1.0 : 0.6,
                    0, Math.PI * 2);
                ctx.fillStyle = Qt.rgba(root.hotColor.r, root.hotColor.g,
                    root.hotColor.b, (0.11 + roll * 0.27) * root.intensity);
                ctx.fill();
            }

            const TAU = Math.PI * 2;
            const deg = Math.PI / 180;

            // Bloom pass: the same geometry, wider and fainter, stands in for
            // a blur that Canvas cannot do.
            band(ctx, 1.06, 1.78, 0.98, 190 * deg, 350 * deg, 14, 0.22, 7);
            band(ctx, 1.42, 3.30, 0.19, 0, TAU, 26, 0.26, 9);

            // The far side of the disk, lensed over the top of the horizon.
            band(ctx, 1.06, 1.78, 0.98, 190 * deg, 350 * deg, 20, 0.80, 2.0);
            // The disk plane itself.
            band(ctx, 1.42, 3.30, 0.19, 0, TAU, 52, 0.94, 2.6);

            // The horizon: an actual hole punched through everything behind it.
            ctx.beginPath();
            ctx.arc(cx, cy, horizon, 0, TAU);
            ctx.fillStyle = root.horizonColor;
            ctx.fill();

            // Photon ring hugging the edge.
            const ring = [[0.995, 1.0], [1.022, 0.74], [1.058, 0.38], [1.10, 0.16]];
            const glow = root.blend(root.hotColor, root.diskColor, 0.22);
            ring.forEach(function(step) {
                ctx.beginPath();
                ctx.arc(cx, cy, horizon * step[0], 0, TAU);
                ctx.strokeStyle = Qt.rgba(glow.r, glow.g, glow.b,
                    step[1] * root.intensity);
                ctx.lineWidth = 1.9;
                ctx.stroke();
            });

            // The near side crosses in front of the horizon.
            band(ctx, 1.42, 3.30, 0.19, 8 * deg, 172 * deg, 52, 0.94, 2.6);
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }

    Connections {
        target: root
        function onDiskColorChanged() { field.requestPaint(); }
        function onEdgeColorChanged() { field.requestPaint(); }
        function onIntensityChanged() { field.requestPaint(); }
    }
}
