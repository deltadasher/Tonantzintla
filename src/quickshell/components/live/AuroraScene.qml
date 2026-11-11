import QtQuick
import "../.."

// Two slow aurora curtains over a few fixed stars. The curtains lift toward
// the pointer and a click sends a surge of light through them. Painted at
// quarter resolution and scaled up, which is also what makes it soft; 20 Hz.
Item {
    id: scene
    property var values: ({})
    property bool running: true
    property point pointer: Qt.point(-1, -1)
    property bool pointerActive: false

    readonly property real glow: Math.max(0.1, (Number(values.glow) || 60) / 100)
    readonly property real pace: Math.max(1, Number(values.pace) || 4) / 4
    property real clock: 0
    property real surge: 0
    property var stars: []

    function pulse(x, y) { surge = 1; settle.restart(); }
    NumberAnimation { id: settle; target: scene; property: "surge"; to: 0; duration: 2600; easing.type: Easing.OutCubic }
    Component.onCompleted: {
        const list = [];
        for (let i = 0; i < 70; ++i) list.push(Math.random(), Math.random() * 0.75, 0.25 + Math.random() * 0.6);
        stars = list;
    }

    Canvas {
        id: veil
        width: Math.max(1, Math.ceil(scene.width / 4)); height: Math.max(1, Math.ceil(scene.height / 4))
        scale: 4; transformOrigin: Item.TopLeft
        smooth: true
        renderStrategy: Canvas.Cooperative
        function tone(color, alpha) {
            return "rgba(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + "," + Math.round(color.b * 255) + "," + alpha + ")";
        }
        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height, t = scene.clock;
            ctx.globalCompositeOperation = "source-over";
            const night = ctx.createLinearGradient(0, 0, 0, h);
            night.addColorStop(0, String(Qt.darker(Theme.void_, 1.4)));
            night.addColorStop(1, String(Theme.void_));
            ctx.fillStyle = night;
            ctx.fillRect(0, 0, w, h);
            ctx.fillStyle = String(Theme.moon);
            for (let i = 0; i < scene.stars.length; i += 3) {
                ctx.globalAlpha = scene.stars[i + 2];
                ctx.fillRect(scene.stars[i] * w, scene.stars[i + 1] * h, 1, 1);
            }
            ctx.globalAlpha = 1;
            ctx.globalCompositeOperation = "lighter";
            const px = scene.pointerActive ? scene.pointer.x / 4 : -1e6;
            const strength = scene.glow * (1 + scene.surge * 0.9);
            // Two curtains, each a row of narrow columns: brightest at the hem and
            // fading upward from green through cyan to rose. Neighbouring columns
            // differ in height and brightness, which is what reads as rays.
            for (let c = 0; c < 2; ++c) {
                const base = h * (0.56 + c * 0.14), k = 0.013 + c * 0.006;
                for (let x = 0; x < w; x += 3) {
                    const lift = Math.exp(-Math.pow((x - px) / (w * 0.1), 2));
                    const hem = base + Math.sin(x * k + t * (0.19 + c * 0.07) + c * 2.1) * h * 0.075
                        + Math.sin(x * k * 2.7 - t * 0.27) * h * 0.03 - lift * h * 0.05;
                    const ray = 0.55 + 0.45 * Math.sin(x * 0.31 + t * 0.9 + c * 1.3) * Math.sin(x * 0.047 - t * 0.35 + c);
                    const tall = h * (0.2 + 0.2 * ray + 0.08 * lift + scene.surge * 0.08);
                    const alpha = Math.min(0.9, (0.2 + 0.5 * ray + 0.25 * lift) * strength * (c === 0 ? 1 : 0.7));
                    const column = ctx.createLinearGradient(0, hem + 3, 0, hem - tall);
                    column.addColorStop(0, tone(Theme.success, 0));
                    column.addColorStop(0.07, tone(Theme.success, alpha));
                    column.addColorStop(0.45, tone(Theme.cyan, alpha * 0.4));
                    column.addColorStop(1, tone(Theme.rose, 0));
                    ctx.fillStyle = column;
                    ctx.fillRect(x, hem - tall, 3, tall + 3);
                }
            }
            ctx.globalCompositeOperation = "source-over";
        }
    }

    Timer {
        interval: 50; repeat: true
        running: scene.running && scene.visible
        onTriggered: { scene.clock += 0.05 * scene.pace; veil.requestPaint(); }
    }
    onGlowChanged: veil.requestPaint()
}
