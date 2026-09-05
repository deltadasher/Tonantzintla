import QtQuick 2.15

Item {
    id: root

    property color accent: "#a99cff"
    property color secondary: "#72d9e7"
    property real phase: 0
    property real energy: 0
    property real focalX: width * 0.73
    property real focalY: height * 0.48
    property bool motionActive: true

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: 32000
        loops: Animation.Infinite
        running: root.motionActive && root.visible
    }

    Canvas {
        id: field
        anchors.fill: parent

        Connections {
            target: root
            function onPhaseChanged() { field.requestPaint(); }
            function onEnergyChanged() { field.requestPaint(); }
            function onAccentChanged() { field.requestPaint(); }
            function onSecondaryChanged() { field.requestPaint(); }
            function onFocalXChanged() { field.requestPaint(); }
            function onFocalYChanged() { field.requestPaint(); }
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
            const turn = root.phase * Math.PI * 2;
            const diagonal = Math.sqrt(width * width + height * height);

            // The field bends toward the displaced horizon. Static seeds keep
            // the sky stable while the slow phase gives it just enough life.
            for (let i = 0; i < 96; i++) {
                const seedX = ((i * 97) % 997) / 997;
                const seedY = ((i * 193) % 991) / 991;
                const drift = Math.sin(turn + i * 1.71) * (0.7 + i % 3);
                const x = seedX * width + drift;
                const y = seedY * height + Math.cos(turn + i) * 0.8;
                const size = i % 19 === 0 ? 2.2 : i % 7 === 0 ? 1.35 : 0.65;
                ctx.fillStyle = rgba(i % 5 === 0 ? root.secondary : root.accent,
                    i % 19 === 0 ? 0.52 : 0.16 + (i % 4) * 0.045);
                ctx.beginPath();
                ctx.arc(x, y, size + root.energy * (i % 13 === 0 ? 0.8 : 0), 0, Math.PI * 2);
                ctx.fill();
            }

            // Sparse trajectories imply a navigable machine without turning
            // the greeter into a dashboard or a bordered panel.
            ctx.lineCap = "round";
            for (let lane = 0; lane < 5; lane++) {
                const startX = -width * (0.06 + lane * 0.02);
                const startY = height * (0.22 + lane * 0.13);
                ctx.beginPath();
                ctx.moveTo(startX, startY);
                ctx.bezierCurveTo(width * (0.24 + lane * 0.02),
                    startY + Math.sin(turn + lane) * 10,
                    root.focalX - diagonal * (0.12 + lane * 0.025),
                    root.focalY + (lane - 2) * height * 0.12,
                    root.focalX, root.focalY);
                ctx.lineWidth = lane === 2 ? 1.25 : 0.7;
                ctx.strokeStyle = rgba(lane % 2 ? root.secondary : root.accent,
                    0.035 + root.energy * 0.025);
                ctx.stroke();
            }
        }
    }
}
