import QtQuick
import "../.."

// A slowly drifting star field in three depths. Stars twinkle, the view leans
// toward the pointer, and a click (or the occasional chance) sends a meteor.
// Painted at half resolution, 20 Hz.
Item {
    id: scene
    property var values: ({})
    property bool running: true
    property point pointer: Qt.point(-1, -1)
    property bool pointerActive: false

    readonly property int count: Math.max(20, Math.round(Number(values.stars) || 600))
    readonly property real drift: Math.max(0, Number(values.drift !== undefined ? values.drift : 3)) / 3
    property var stars: null      // x, y (0..1), depth (0..1), phase per star
    property var meteors: []
    property real clock: 0
    property real lookX: 0
    property real lookY: 0
    property real nextMeteor: 6

    function reset() {
        const s = new Float32Array(count * 4);
        for (let i = 0; i < s.length; i += 4) {
            s[i] = Math.random(); s[i + 1] = Math.random();
            s[i + 2] = Math.pow(Math.random(), 1.8); s[i + 3] = Math.random() * 6.283;
        }
        stars = s;
        sky.requestPaint();
    }
    function launch(x, y) {
        const direction = Math.random() < 0.5 ? -1 : 1;
        meteors.push({ x: x, y: y, vx: direction * (7 + Math.random() * 5), vy: 2.5 + Math.random() * 2.5, life: 1 });
        if (meteors.length > 6) meteors.shift();
    }
    function pulse(x, y) { launch(x / 2, y / 2); }
    onCountChanged: reset()
    Component.onCompleted: reset()

    Canvas {
        id: sky
        width: Math.max(1, Math.ceil(scene.width / 2)); height: Math.max(1, Math.ceil(scene.height / 2))
        scale: 2; transformOrigin: Item.TopLeft
        renderStrategy: Canvas.Cooperative
        readonly property var tints: [Theme.moon, Theme.cyan, Theme.accent]
        function tone(color, alpha) {
            return "rgba(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + "," + Math.round(color.b * 255) + "," + alpha + ")";
        }
        onPaint: {
            const ctx = getContext("2d"), s = scene.stars;
            const w = width, h = height, t = scene.clock;
            const wash = ctx.createLinearGradient(0, 0, 0, h);
            wash.addColorStop(0, String(Qt.darker(Theme.void_, 1.35)));
            wash.addColorStop(1, String(Theme.void_));
            ctx.globalAlpha = 1;
            ctx.fillStyle = wash;
            ctx.fillRect(0, 0, w, h);
            if (!s) return;
            // One pass per tint keeps fill-style changes to three per frame.
            for (let tint = 0; tint < 3; ++tint) {
                ctx.fillStyle = String(tints[tint]);
                for (let i = 0, n = 0; i < s.length; i += 4, ++n) {
                    if ((n % 9 === 0 ? 1 : n % 13 === 0 ? 2 : 0) !== tint) continue;
                    const depth = s[i + 2];
                    let x = (s[i] + t * 0.0035 * scene.drift * (0.15 + depth) - scene.lookX * 0.03 * depth) % 1;
                    let y = (s[i + 1] - scene.lookY * 0.03 * depth) % 1;
                    if (x < 0) x += 1;
                    if (y < 0) y += 1;
                    ctx.globalAlpha = (0.38 + 0.62 * depth) * (0.55 + 0.45 * Math.sin(t * (0.5 + depth * 1.7) + s[i + 3]));
                    const size = depth > 0.7 ? 2 : 1;
                    ctx.fillRect(x * w, y * h, size, size);
                }
            }
            ctx.lineWidth = 1;
            for (let m = 0; m < scene.meteors.length; ++m) {
                const meteor = scene.meteors[m];
                const tail = ctx.createLinearGradient(meteor.x, meteor.y, meteor.x - meteor.vx * 9, meteor.y - meteor.vy * 9);
                tail.addColorStop(0, tone(Theme.moon, 0.95 * meteor.life));
                tail.addColorStop(1, tone(Theme.cyan, 0));
                ctx.globalAlpha = 1;
                ctx.strokeStyle = tail;
                ctx.beginPath();
                ctx.moveTo(meteor.x, meteor.y);
                ctx.lineTo(meteor.x - meteor.vx * 9, meteor.y - meteor.vy * 9);
                ctx.stroke();
            }
            ctx.globalAlpha = 1;
        }
    }

    Timer {
        interval: 50; repeat: true
        running: scene.running && scene.visible
        onTriggered: {
            scene.clock += 0.05;
            const targetX = scene.pointerActive ? scene.pointer.x / Math.max(1, scene.width) * 2 - 1 : 0;
            const targetY = scene.pointerActive ? scene.pointer.y / Math.max(1, scene.height) * 2 - 1 : 0;
            scene.lookX += (targetX - scene.lookX) * 0.08;
            scene.lookY += (targetY - scene.lookY) * 0.08;
            for (let m = scene.meteors.length - 1; m >= 0; --m) {
                const meteor = scene.meteors[m];
                meteor.x += meteor.vx; meteor.y += meteor.vy; meteor.life -= 0.035;
                if (meteor.life <= 0) scene.meteors.splice(m, 1);
            }
            scene.nextMeteor -= 0.05;
            if (scene.nextMeteor <= 0) {
                scene.launch(Math.random() * sky.width, Math.random() * sky.height * 0.5);
                scene.nextMeteor = 7 + Math.random() * 14;
            }
            sky.requestPaint();
        }
    }
}
