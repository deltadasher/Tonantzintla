import QtQuick
import "../.."

// Particles drifting along a slowly shifting vector field, leaving fading trails.
// Painted at half resolution and 30 Hz to stay cheap. The pointer is a whirlpool;
// a click scatters everything near it.
Item {
    id: scene
    property var values: ({})
    property bool running: true
    property point pointer: Qt.point(-1, -1)
    property bool pointerActive: false

    readonly property int count: Math.max(50, Math.round(Number(values.count) || 1200))
    readonly property real pace: Math.max(1, Number(values.pace) || 4) / 4
    property var particles: null   // x, y, vx, vy per particle, in canvas pixels
    property real clock: 0
    property bool cleared: false

    function spawn(p, i) {
        p[i] = Math.random() * field.width; p[i + 1] = Math.random() * field.height;
        p[i + 2] = 0; p[i + 3] = 0;
    }
    function reset() {
        const p = new Float32Array(count * 4);
        for (let i = 0; i < p.length; i += 4) spawn(p, i);
        particles = p; cleared = false;
        field.requestPaint();
    }
    function pulse(x, y) {
        const p = particles;
        if (!p) return;
        const cx = x / 2, cy = y / 2;
        for (let i = 0; i < p.length; i += 4) {
            const dx = p[i] - cx, dy = p[i + 1] - cy, d = Math.sqrt(dx * dx + dy * dy);
            if (d < 160 && d > 0.5) { const k = (1 - d / 160) * 9 / d; p[i + 2] += dx * k; p[i + 3] += dy * k; }
        }
    }
    onCountChanged: reset()
    onWidthChanged: reset()
    onHeightChanged: reset()
    Component.onCompleted: reset()

    Rectangle { anchors.fill: parent; color: Theme.void_ }

    Canvas {
        id: field
        width: Math.max(1, Math.ceil(scene.width / 2)); height: Math.max(1, Math.ceil(scene.height / 2))
        scale: 2; transformOrigin: Item.TopLeft
        renderStrategy: Canvas.Cooperative

        function tone(color, alpha) {
            return "rgba(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + "," + Math.round(color.b * 255) + "," + alpha + ")";
        }
        onPaint: {
            const ctx = getContext("2d"), p = scene.particles;
            if (!p) return;
            const w = width, h = height, t = scene.clock, pace = scene.pace;
            ctx.globalCompositeOperation = "source-over";
            ctx.fillStyle = scene.cleared ? tone(Theme.void_, 0.12) : String(Theme.void_);
            ctx.fillRect(0, 0, w, h);
            scene.cleared = true;
            ctx.globalCompositeOperation = "lighter";
            ctx.lineWidth = 1;
            const bands = [Theme.accent, Theme.cyan, Theme.rose];
            const per = Math.ceil(p.length / 4 / bands.length) * 4;
            const px = scene.pointerActive ? scene.pointer.x / 2 : -1e6, py = scene.pointer.y / 2;
            for (let b = 0; b < bands.length; ++b) {
                ctx.strokeStyle = tone(bands[b], 0.5);
                ctx.beginPath();
                const end = Math.min(p.length, (b + 1) * per);
                for (let i = b * per; i < end; i += 4) {
                    const x = p[i], y = p[i + 1];
                    const u = x * 0.0042, v = y * 0.0042;
                    const a = 3.2 * (Math.sin(u * 1.7 + t * 0.21) + Math.sin(v * 2.3 - t * 0.17)
                        + Math.sin((u + v) * 1.1 + t * 0.13) + 0.5 * Math.sin(u * 4.1 - v * 3.3 + t * 0.29));
                    let ax = Math.cos(a) * 0.12, ay = Math.sin(a) * 0.12;
                    const dx = x - px, dy = y - py, d2 = dx * dx + dy * dy;
                    if (d2 < 15625) {   // 125 canvas px: mostly tangential, slightly inward
                        const k = (1 - d2 / 15625) * 0.5 / (Math.sqrt(d2) + 1);
                        ax += (-dy - dx * 0.25) * k; ay += (dx - dy * 0.25) * k;
                    }
                    const vx = p[i + 2] = (p[i + 2] + ax * 2) * 0.93, vy = p[i + 3] = (p[i + 3] + ay * 2) * 0.93;
                    const nx = x + vx * pace, ny = y + vy * pace;
                    ctx.moveTo(x, y); ctx.lineTo(nx, ny);
                    if (nx < 0 || nx > w || ny < 0 || ny > h || Math.random() < 0.003) scene.spawn(p, i);
                    else { p[i] = nx; p[i + 1] = ny; }
                }
                ctx.stroke();
            }
        }
    }

    Timer {
        interval: 33; repeat: true
        running: scene.running && scene.visible
        onTriggered: { scene.clock += 0.033; field.requestPaint(); }
    }
}
