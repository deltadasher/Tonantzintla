import QtQuick
import "../.."

// Bodies on Keplerian orbits around a central star, each drawing a fading
// trail: they sweep fast near the star and slow far from it. The system leans
// toward the pointer; a click launches a comet on a long eccentric pass.
// Half resolution, 30 Hz. Trails are kept as points, so nothing smears.
Item {
    id: scene
    property var values: ({})
    property bool running: true
    property point pointer: Qt.point(-1, -1)
    property bool pointerActive: false

    readonly property int count: Math.max(1, Math.round(Number(values.bodies) || 8))
    readonly property real pace: Math.max(1, Number(values.pace) || 4) / 4
    readonly property int trailLength: 70
    property var bodies: []
    property real leanX: 0
    property real leanY: 0

    function makeBody(index, total, comet) {
        const spread = total > 1 ? index / (total - 1) : 0.5;
        const body = {
            a: comet ? 0.55 + Math.random() * 0.4 : 0.14 + spread * 0.8,   // semi-major axis, in system radii
            e: comet ? 0.78 + Math.random() * 0.12 : Math.random() * 0.28,
            turn: Math.random() * 6.283,
            anomaly: comet ? 3.4 : Math.random() * 6.283,
            tint: comet ? 3 : index % 3,
            size: comet ? 1 : (index % 4 === 3 ? 3 : 2),
            laps: comet ? 1.6 : -1,
            trail: [],
            ring: []    // the full orbit in system radii, drawn as a faint guide
        };
        const cosT = Math.cos(body.turn), sinT = Math.sin(body.turn), minor = Math.sqrt(1 - body.e * body.e);
        for (let k = 0; k <= 72 && !comet; ++k) {
            const E = k / 72 * 6.283, ox = body.a * (Math.cos(E) - body.e), oy = body.a * minor * Math.sin(E);
            body.ring.push(ox * cosT - oy * sinT, (ox * sinT + oy * cosT) * 0.58);
        }
        return body;
    }
    function reset() {
        const list = [];
        for (let i = 0; i < count; ++i) list.push(makeBody(i, count, false));
        bodies = list;
        chart.requestPaint();
    }
    function pulse(x, y) {
        if (bodies.filter(function(body) { return body.laps >= 0; }).length < 4)
            bodies.push(makeBody(0, 1, true));
    }
    onCountChanged: reset()
    Component.onCompleted: reset()

    function advance() {
        const radius = Math.min(chart.width, chart.height) * 0.47;
        const cx = chart.width / 2 + leanX * radius * 0.08, cy = chart.height / 2 + leanY * radius * 0.08;
        for (let i = bodies.length - 1; i >= 0; --i) {
            const body = bodies[i];
            // Mean motion follows Kepler's third law: n is proportional to a^-1.5.
            const step = 0.012 * pace / Math.pow(body.a, 1.5);
            body.anomaly += step;
            if (body.laps >= 0) {
                body.laps -= step / 6.283;
                if (body.laps <= 0) { bodies.splice(i, 1); continue; }
            }
            let E = body.anomaly;   // solve Kepler's equation M = E - e sin E
            for (let k = 0; k < 4; ++k) E -= (E - body.e * Math.sin(E) - body.anomaly) / (1 - body.e * Math.cos(E));
            const ox = body.a * (Math.cos(E) - body.e), oy = body.a * Math.sqrt(1 - body.e * body.e) * Math.sin(E);
            const cosT = Math.cos(body.turn), sinT = Math.sin(body.turn);
            // The orbital plane is tilted away from the viewer, hence the flattened y.
            body.trail.push(cx + (ox * cosT - oy * sinT) * radius, cy + (ox * sinT + oy * cosT) * radius * 0.58);
            if (body.trail.length > trailLength * 2) body.trail.splice(0, 2);
        }
    }

    Canvas {
        id: chart
        width: Math.max(1, Math.ceil(scene.width / 2)); height: Math.max(1, Math.ceil(scene.height / 2))
        scale: 2; transformOrigin: Item.TopLeft
        renderStrategy: Canvas.Cooperative
        readonly property var tints: [Theme.accent, Theme.cyan, Theme.rose, Theme.moon]
        function tone(color, alpha) {
            return "rgba(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + "," + Math.round(color.b * 255) + "," + alpha + ")";
        }
        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height;
            ctx.fillStyle = String(Theme.void_);
            ctx.fillRect(0, 0, w, h);
            const radius = Math.min(w, h) * 0.47;
            const cx = w / 2 + scene.leanX * radius * 0.08, cy = h / 2 + scene.leanY * radius * 0.08;
            const halo = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius * 0.16);
            halo.addColorStop(0, tone(Theme.warning, 0.55));
            halo.addColorStop(0.25, tone(Theme.warning, 0.14));
            halo.addColorStop(1, tone(Theme.warning, 0));
            ctx.fillStyle = halo;
            ctx.fillRect(cx - radius * 0.16, cy - radius * 0.16, radius * 0.32, radius * 0.32);
            ctx.fillStyle = String(Theme.moon);
            ctx.beginPath(); ctx.arc(cx, cy, 2.5, 0, 6.283); ctx.fill();

            ctx.lineWidth = 1;
            ctx.strokeStyle = tone(Theme.muted, 0.16);
            ctx.beginPath();
            for (let i = 0; i < scene.bodies.length; ++i) {
                const ring = scene.bodies[i].ring;
                for (let k = 0; k < ring.length; k += 2) {
                    if (k === 0) ctx.moveTo(cx + ring[0] * radius, cy + ring[1] * radius);
                    else ctx.lineTo(cx + ring[k] * radius, cy + ring[k + 1] * radius);
                }
            }
            ctx.stroke();
            for (let i = 0; i < scene.bodies.length; ++i) {
                const body = scene.bodies[i], trail = body.trail, points = trail.length / 2;
                if (points < 2) continue;
                const color = tints[body.tint];
                // Three strokes per trail: faint tail, middle, bright head.
                for (let part = 0; part < 3; ++part) {
                    const from = Math.floor(points * part / 3), to = Math.min(points - 1, Math.floor(points * (part + 1) / 3));
                    if (to <= from) continue;
                    ctx.strokeStyle = tone(color, 0.1 + part * 0.25);
                    ctx.beginPath();
                    ctx.moveTo(trail[from * 2], trail[from * 2 + 1]);
                    for (let k = from + 1; k <= to; ++k) ctx.lineTo(trail[k * 2], trail[k * 2 + 1]);
                    ctx.stroke();
                }
                ctx.fillStyle = String(color);
                ctx.beginPath();
                ctx.arc(trail[trail.length - 2], trail[trail.length - 1], body.size, 0, 6.283);
                ctx.fill();
            }
        }
    }

    Timer {
        interval: 33; repeat: true
        running: scene.running && scene.visible
        onTriggered: {
            const targetX = scene.pointerActive ? scene.pointer.x / Math.max(1, scene.width) * 2 - 1 : 0;
            const targetY = scene.pointerActive ? scene.pointer.y / Math.max(1, scene.height) * 2 - 1 : 0;
            scene.leanX += (targetX - scene.leanX) * 0.05;
            scene.leanY += (targetY - scene.leanY) * 0.05;
            scene.advance();
            chart.requestPaint();
        }
    }
}
