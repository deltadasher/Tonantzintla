import QtQuick
import "../.."

Item {
    id: root

    property color primary: Theme.accent
    property color secondary: Theme.cyan
    property real energy: 0
    property real focalX: width * 0.73
    property real focalY: height * 0.49
    property bool motionActive: true
    property real phase: 0

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: Settings.motion && Settings.umbraMotion ? 68000 : 1
        loops: Animation.Infinite
        running: root.motionActive && Settings.motion && Settings.umbraMotion && root.visible
    }

    Canvas {
        id: field
        anchors.fill: parent
        opacity: 0.84

        Connections {
            target: root
            function onPhaseChanged() { field.requestPaint(); }
            function onEnergyChanged() { field.requestPaint(); }
            function onFocalXChanged() { field.requestPaint(); }
            function onFocalYChanged() { field.requestPaint(); }
            function onPrimaryChanged() { field.requestPaint(); }
            function onSecondaryChanged() { field.requestPaint(); }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        function rgba(color, alpha) {
            return "rgba(" + Math.round(color.r * 255) + ","
                + Math.round(color.g * 255) + ","
                + Math.round(color.b * 255) + "," + alpha + ")";
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const rotation = root.phase * Math.PI * 2;
            const shortSide = Math.min(width, height);
            const focusX = root.focalX + Math.sin(rotation * 0.31) * shortSide * 0.006;
            const focusY = root.focalY + Math.cos(rotation * 0.27) * shortSide * 0.004;

            // Long gravitational veins feed the displaced event horizon. They are
            // deliberately incomplete: Umbra should feel spatial, not framed.
            ctx.lineCap = "round";
            for (let vein = 0; vein < 31; vein++) {
                const lane = vein / 30;
                const seed = Math.sin((vein + 3) * 71.117) * 43758.5453;
                const noise = seed - Math.floor(seed);
                const startX = -width * (0.08 + noise * 0.16);
                const startY = height * (-0.08 + lane * 1.16);
                const bend = Math.sin(vein * 0.91 + rotation * 0.38) * height * 0.08;
                const endAngle = -1.55 + lane * 3.1;
                const endRadius = shortSide * (0.13 + (vein % 7) * 0.011);
                const endX = focusX + Math.cos(endAngle) * endRadius;
                const endY = focusY + Math.sin(endAngle) * endRadius * 0.56;

                ctx.beginPath();
                ctx.moveTo(startX, startY);
                ctx.bezierCurveTo(
                    width * (0.18 + noise * 0.16), startY + bend,
                    focusX - width * (0.28 + noise * 0.10), endY - bend * 0.35,
                    endX, endY
                );
                ctx.setLineDash([1 + vein % 3, 11 + vein % 8]);
                ctx.lineDashOffset = rotation * (vein % 2 ? 34 : -27) + vein * 3;
                ctx.lineWidth = vein % 9 === 0 ? 1.35 : 0.65;
                ctx.strokeStyle = rgba(vein % 5 === 0 ? root.secondary : root.primary,
                    0.025 + (vein % 6 === 0 ? 0.06 : 0.018) + root.energy * 0.018);
                ctx.stroke();
            }

            // Fixed pseudo-random stars keep the field alive without spawning
            // QML objects. A few react sharply to authentication energy.
            ctx.setLineDash([]);
            for (let star = 0; star < 88; star++) {
                const a = Math.sin((star + 11) * 91.317) * 43758.5453;
                const b = Math.sin((star + 29) * 47.11) * 12973.22;
                const x = (a - Math.floor(a)) * width;
                const y = (b - Math.floor(b)) * height;
                const pulse = 0.42 + 0.58 * Math.abs(Math.sin(rotation * (0.6 + star % 4 * 0.09) + star));
                const radius = star % 17 === 0 ? 1.7 + root.energy * 1.8
                    : star % 5 === 0 ? 1.0 : 0.55;
                ctx.fillStyle = rgba(star % 13 === 0 ? root.secondary : Theme.moon,
                    0.12 + pulse * (star % 17 === 0 ? 0.52 : 0.22));
                ctx.beginPath();
                ctx.arc(x, y, radius, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }
}
