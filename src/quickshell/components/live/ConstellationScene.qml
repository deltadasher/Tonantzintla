import QtQuick
import "../.."

// Drifting points that draw a line to every neighbour within reach, so
// constellations keep forming and dissolving. The pointer is one more star to
// link to; a click pushes nearby points away. Half resolution, 30 Hz.
Item {
    id: scene
    property var values: ({})
    property bool running: true
    property point pointer: Qt.point(-1, -1)
    property bool pointerActive: false

    readonly property int count: Math.max(8, Math.round(Number(values.count) || 90))
    readonly property real reach: Math.max(20, Number(values.reach) || 90)
    property var points: null   // x, y, vx, vy per point, in canvas pixels

    function reset() {
        const p = new Float32Array(count * 4);
        for (let i = 0; i < p.length; i += 4) {
            const angle = Math.random() * 6.283, speed = 0.12 + Math.random() * 0.28;
            p[i] = Math.random() * chart.width; p[i + 1] = Math.random() * chart.height;
            p[i + 2] = Math.cos(angle) * speed; p[i + 3] = Math.sin(angle) * speed;
        }
        points = p;
        chart.requestPaint();
    }
    function pulse(x, y) {
        const p = points;
        if (!p) return;
        const cx = x / 2, cy = y / 2;
        for (let i = 0; i < p.length; i += 4) {
            const dx = p[i] - cx, dy = p[i + 1] - cy, d = Math.sqrt(dx * dx + dy * dy);
            if (d < 150 && d > 0.5) { const k = (1 - d / 150) * 5 / d; p[i + 2] += dx * k; p[i + 3] += dy * k; }
        }
    }
    onCountChanged: reset()
    onWidthChanged: reset()
    onHeightChanged: reset()
    Component.onCompleted: reset()

    Canvas {
        id: chart
        width: Math.max(1, Math.ceil(scene.width / 2)); height: Math.max(1, Math.ceil(scene.height / 2))
        scale: 2; transformOrigin: Item.TopLeft
        renderStrategy: Canvas.Cooperative
        function tone(color, alpha) {
            return "rgba(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + "," + Math.round(color.b * 255) + "," + alpha + ")";
        }
        onPaint: {
            const ctx = getContext("2d"), p = scene.points;
            const w = width, h = height;
            ctx.fillStyle = String(Theme.void_);
            ctx.fillRect(0, 0, w, h);
            if (!p) return;
            const reach = scene.reach, reach2 = reach * reach;
            // Lines are sorted into four strengths so each is stroked as one path.
            const levels = [[], [], [], []];
            for (let i = 0; i < p.length; i += 4) {
                for (let j = i + 4; j < p.length; j += 4) {
                    const dx = p[i] - p[j], dy = p[i + 1] - p[j + 1], d2 = dx * dx + dy * dy;
                    if (d2 < reach2) levels[Math.min(3, Math.floor((1 - Math.sqrt(d2) / reach) * 4))].push(i, j);
                }
            }
            ctx.lineWidth = 1;
            for (let level = 0; level < 4; ++level) {
                const pairs = levels[level];
                if (!pairs.length) continue;
                ctx.strokeStyle = tone(Theme.accent, 0.1 + level * 0.17);
                ctx.beginPath();
                for (let k = 0; k < pairs.length; k += 2) {
                    ctx.moveTo(p[pairs[k]], p[pairs[k] + 1]);
                    ctx.lineTo(p[pairs[k + 1]], p[pairs[k + 1] + 1]);
                }
                ctx.stroke();
            }
            if (scene.pointerActive) {
                const px = scene.pointer.x / 2, py = scene.pointer.y / 2, wide = reach * 1.6, wide2 = wide * wide;
                ctx.strokeStyle = tone(Theme.cyan, 0.55);
                ctx.beginPath();
                for (let i = 0; i < p.length; i += 4) {
                    const dx = p[i] - px, dy = p[i + 1] - py;
                    if (dx * dx + dy * dy < wide2) { ctx.moveTo(px, py); ctx.lineTo(p[i], p[i + 1]); }
                }
                ctx.stroke();
            }
            ctx.fillStyle = String(Theme.moon);
            for (let i = 0; i < p.length; i += 4) ctx.fillRect(p[i] - 1, p[i + 1] - 1, 2, 2);
        }
    }

    Timer {
        interval: 33; repeat: true
        running: scene.running && scene.visible
        onTriggered: {
            const p = scene.points, w = chart.width, h = chart.height;
            if (!p) return;
            for (let i = 0; i < p.length; i += 4) {
                // A pushed point coasts back down to its cruising speed.
                const speed2 = p[i + 2] * p[i + 2] + p[i + 3] * p[i + 3];
                if (speed2 > 0.16) { p[i + 2] *= 0.96; p[i + 3] *= 0.96; }
                p[i] += p[i + 2]; p[i + 1] += p[i + 3];
                if (p[i] < -10) p[i] = w + 10; else if (p[i] > w + 10) p[i] = -10;
                if (p[i + 1] < -10) p[i + 1] = h + 10; else if (p[i + 1] > h + 10) p[i + 1] = -10;
            }
            chart.requestPaint();
        }
    }
}
