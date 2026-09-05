import QtQuick 2.15

Item {
    id: root

    property color voidColor: "#080910"
    property color accent: "#a99cff"
    property color secondary: "#72d9e7"
    property color danger: "#ed7d8f"
    property real deployment: 1
    property real energy: 0
    property real capture: 0
    property real shock: 0
    property bool authenticating: false
    property bool failed: false
    property bool success: false
    property bool motionActive: true
    property real phase: 0
    property real packetPhase: 0

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: 26000
        loops: Animation.Infinite
        running: root.motionActive && root.visible
    }

    NumberAnimation on packetPhase {
        from: 0
        to: 1
        duration: 1100
        loops: Animation.Infinite
        running: root.motionActive && root.visible
            && (root.authenticating || root.success)
    }

    Canvas {
        id: horizon
        anchors.fill: parent

        Connections {
            target: root
            function onPhaseChanged() { horizon.requestPaint(); }
            function onPacketPhaseChanged() { horizon.requestPaint(); }
            function onDeploymentChanged() { horizon.requestPaint(); }
            function onEnergyChanged() { horizon.requestPaint(); }
            function onCaptureChanged() { horizon.requestPaint(); }
            function onShockChanged() { horizon.requestPaint(); }
            function onAuthenticatingChanged() { horizon.requestPaint(); }
            function onFailedChanged() { horizon.requestPaint(); }
            function onSuccessChanged() { horizon.requestPaint(); }
            function onAccentChanged() { horizon.requestPaint(); }
            function onSecondaryChanged() { horizon.requestPaint(); }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        function rgba(color, alpha) {
            return "rgba(" + Math.round(color.r * 255) + ","
                + Math.round(color.g * 255) + ","
                + Math.round(color.b * 255) + "," + alpha + ")";
        }

        function streamPoint(index, progress, radius, cx, cy, turn) {
            const p = Math.max(0, Math.min(1, progress));
            const eased = 1 - Math.pow(1 - p, 1.58);
            const outer = radius * (1.34 + (index % 4) * 0.08);
            const inner = radius * (0.54 + (index % 3) * 0.014);
            const base = index * Math.PI * 2 / 24 + Math.sin(index * 2.13) * 0.16;
            const curl = 1.02 + (index % 4) * 0.12;
            const angle = base + turn + curl * eased
                + Math.sin(p * Math.PI) * 0.10;
            const orbit = outer + (inner - outer) * eased;
            return {
                x: cx + Math.cos(angle) * orbit,
                y: cy + Math.sin(angle) * orbit
            };
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width * 0.5;
            const cy = height * 0.5;
            const radius = Math.min(width, height) * 0.29
                * Math.max(0.02, root.deployment + root.capture * 0.92);
            const turn = root.phase * Math.PI * 2;
            const stateColor = root.failed ? root.danger : root.accent;

            // Flat concentric fields survive SDDM's software renderer without
            // the polygonal banding produced by Canvas radial gradients.
            ctx.fillStyle = rgba(stateColor, 0.045 + root.energy * 0.025);
            ctx.beginPath();
            ctx.arc(cx, cy, radius * 1.48, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = rgba(root.secondary, 0.055 + root.energy * 0.025);
            ctx.beginPath();
            ctx.arc(cx, cy, radius * 1.29, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = rgba(root.voidColor, 1);
            ctx.beginPath();
            ctx.arc(cx, cy, radius * 0.69, 0, Math.PI * 2);
            ctx.fill();

            // Broken bands rotate at disagreeing speeds. The silhouette reads
            // as an instrument, but never as a conventional circular widget.
            ctx.lineCap = "round";
            for (let band = 0; band < 8; band++) {
                const bandRadius = radius * (0.76 + band * 0.105);
                const direction = band % 2 === 0 ? 1 : -1;
                const speed = 1 + band % 3;
                const start = turn * direction * speed
                    + band * 0.73 + Math.sin(turn + band) * 0.055;
                const span = 0.34 + (band % 5) * 0.19 + root.energy * 0.06;
                ctx.beginPath();
                ctx.arc(cx, cy, bandRadius, start, start + span);
                ctx.lineWidth = Math.max(1, radius * (band % 4 === 0 ? 0.020 : 0.006));
                ctx.strokeStyle = rgba(band % 3 === 0 ? stateColor : root.secondary,
                    0.18 + (band % 4 === 0 ? 0.34 : 0.09)
                    + root.energy * 0.12);
                ctx.stroke();

                ctx.beginPath();
                ctx.arc(cx, cy, bandRadius, start + Math.PI + 0.22,
                    start + Math.PI + 0.22 + span * 0.42);
                ctx.lineWidth = Math.max(0.8, radius * 0.005);
                ctx.strokeStyle = rgba(stateColor, 0.085 + root.energy * 0.07);
                ctx.stroke();
            }

            // A lensed flare breaks the radial symmetry without resembling a
            // generic ring or a card decoration.
            const flareStart = -0.62 + Math.sin(turn) * 0.08;
            ctx.fillStyle = rgba(root.secondary, 0.055 + root.energy * 0.04);
            ctx.beginPath();
            ctx.moveTo(cx, cy);
            ctx.arc(cx, cy, radius * 1.34, flareStart, flareStart + 0.31);
            ctx.closePath();
            ctx.fill();

            // A few quiet markers establish scale without competing with the
            // actual user and session satellites in Main.qml.
            for (let body = 0; body < 4; body++) {
                const angle = turn * (body % 2 ? -1 : 1) + body * 1.57;
                const orbit = radius * (1.14 + (body % 3) * 0.19);
                const x = cx + Math.cos(angle) * orbit;
                const y = cy + Math.sin(angle) * orbit;
                const size = radius * (body === 0 ? 0.024 : 0.011)
                    + root.energy * 1.7;
                ctx.fillStyle = rgba(body % 2 ? root.secondary : stateColor,
                    body === 0 ? 0.76 : 0.40);
                ctx.beginPath();
                ctx.arc(x, y, size, 0, Math.PI * 2);
                ctx.fill();
            }

            if (root.authenticating || root.success) {
                // Curved packets flow into the event horizon. Success speeds
                // the stream up and increases density instead of flashing out.
                const streams = root.success ? 32 : 24;
                for (let stream = 0; stream < streams; stream++) {
                    const tint = stream % 3 === 0 ? root.secondary : stateColor;
                    const head = (root.packetPhase + stream / streams) % 1;
                    const tail = root.success ? 0.27 : 0.16;
                    for (let segment = 0; segment < 7; segment++) {
                        const p0 = head - tail + tail * segment / 7;
                        const p1 = head - tail + tail * (segment + 1) / 7;
                        if (p1 <= 0 || p0 >= 1)
                            continue;
                        const a = streamPoint(stream, Math.max(0, p0), radius, cx, cy, turn);
                        const b = streamPoint(stream, Math.min(1, p1), radius, cx, cy, turn);
                        const glow = (segment + 1) / 7;
                        ctx.beginPath();
                        ctx.moveTo(a.x, a.y);
                        ctx.lineTo(b.x, b.y);
                        ctx.lineWidth = Math.max(1, radius * (0.003 + glow * 0.008));
                        ctx.strokeStyle = rgba(tint,
                            (root.success ? 0.28 : 0.16) + glow * 0.50);
                        ctx.stroke();
                    }
                }
            }

            if (root.failed && root.shock > 0.001) {
                // Rejection ejects a short red recoil against the normal flow.
                for (let fracture = 0; fracture < 7; fracture++) {
                    const angle = fracture * 0.91 - root.shock * 0.4;
                    const inner = radius * (0.68 + fracture * 0.04);
                    const outer = inner + radius * (0.20 + root.shock * 0.32);
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(angle) * inner,
                        cy + Math.sin(angle) * inner);
                    ctx.lineTo(cx + Math.cos(angle) * outer,
                        cy + Math.sin(angle) * outer);
                    ctx.lineWidth = Math.max(2, radius * 0.012 * root.shock);
                    ctx.strokeStyle = rgba(root.danger, 0.72 * root.shock);
                    ctx.stroke();
                }
            }
        }
    }
}
