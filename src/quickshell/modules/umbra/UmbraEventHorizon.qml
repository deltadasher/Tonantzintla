import QtQuick
import "../.."

Item {
    id: root

    property color primary: Theme.accent
    property color secondary: Theme.cyan
    property real energy: 0
    property real deployment: 1
    property bool failed: false
    property bool authenticating: false
    property bool collapseActive: false
    property real collapseProgress: 0
    property real shock: 0
    property bool motionActive: true
    property real phase: 0
    property real suctionPhase: 0

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: Settings.motion && Settings.umbraMotion ? 26000 : 1
        loops: Animation.Infinite
        running: root.motionActive && Settings.motion && Settings.umbraMotion && root.visible
    }

    NumberAnimation on suctionPhase {
        from: 0
        to: 1
        duration: Settings.motion && Settings.umbraMotion ? 760 : 1
        loops: Animation.Infinite
        running: root.collapseActive && root.motionActive && root.visible
    }

    Canvas {
        id: horizon
        anchors.fill: parent

        Connections {
            target: root
            function onPhaseChanged() { horizon.requestPaint(); }
            function onEnergyChanged() { horizon.requestPaint(); }
            function onDeploymentChanged() { horizon.requestPaint(); }
            function onFailedChanged() { horizon.requestPaint(); }
            function onAuthenticatingChanged() { horizon.requestPaint(); }
            function onCollapseActiveChanged() { horizon.requestPaint(); }
            function onCollapseProgressChanged() { horizon.requestPaint(); }
            function onSuctionPhaseChanged() { horizon.requestPaint(); }
            function onShockChanged() { horizon.requestPaint(); }
            function onPrimaryChanged() { horizon.requestPaint(); }
            function onSecondaryChanged() { horizon.requestPaint(); }
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
            const cx = width * 0.5;
            const cy = height * 0.5;
            const radius = Math.min(width, height) * 0.315 * Math.max(0.02, root.deployment);
            const turn = root.phase * Math.PI * 2;
            const stateColor = root.failed ? Theme.danger : root.primary;

            // The eclipse itself is a deep radial well, not a bordered circle.
            const well = ctx.createRadialGradient(cx, cy, radius * 0.05, cx, cy, radius * 1.42);
            well.addColorStop(0, rgba(Theme.void_, 1));
            well.addColorStop(0.56, rgba(Theme.void_, 0.98));
            well.addColorStop(0.73, rgba(stateColor, 0.16 + root.energy * 0.08));
            well.addColorStop(0.80, rgba(root.secondary, 0.045));
            well.addColorStop(1, rgba(Theme.void_, 0));
            ctx.fillStyle = well;
            ctx.beginPath();
            ctx.arc(cx, cy, radius * 1.46, 0, Math.PI * 2);
            ctx.fill();

            // Broken accretion bands rotate at conflicting speeds. Their gaps
            // are the identity of the shape; no rounded panel contains them.
            ctx.lineCap = "round";
            for (let band = 0; band < 9; band++) {
                const bandRadius = radius * (0.74 + band * 0.095);
                const direction = band % 2 === 0 ? 1 : -1;
                const start = turn * direction * (0.18 + band * 0.018)
                    + band * 0.78 + Math.sin(turn * 0.7 + band) * 0.06;
                const span = 0.44 + (band % 4) * 0.22 + root.energy * 0.08;
                ctx.beginPath();
                ctx.arc(cx, cy, bandRadius, start, start + span);
                ctx.lineWidth = Math.max(1, radius * (band % 3 === 0 ? 0.018 : 0.008));
                ctx.strokeStyle = rgba(band % 3 === 0 ? stateColor : root.secondary,
                    0.18 + (band % 3 === 0 ? 0.25 : 0.08) + root.energy * 0.15);
                ctx.stroke();

                ctx.beginPath();
                ctx.arc(cx, cy, bandRadius, start + Math.PI + 0.3, start + Math.PI + 0.3 + span * 0.48);
                ctx.lineWidth = Math.max(0.8, radius * 0.006);
                ctx.strokeStyle = rgba(stateColor, 0.10 + root.energy * 0.08);
                ctx.stroke();
            }

            // The idle flare recedes during capture. The unlock field below
            // supplies its own directional light instead of emitting a wedge.
            const flareStart = -0.55 + Math.sin(turn * 0.34) * 0.08;
            ctx.fillStyle = rgba(root.failed ? Theme.danger : root.secondary,
                (0.08 + root.energy * 0.05) * (1 - root.collapseProgress));
            ctx.beginPath();
            ctx.moveTo(cx, cy);
            ctx.arc(cx, cy, radius * 1.32, flareStart, flareStart + 0.36);
            ctx.closePath();
            ctx.fill();

            // Tangent probes and satellites respond to input energy.
            for (let probe = 0; probe < 7; probe++) {
                const angle = turn * (probe % 2 ? -0.16 : 0.22) + probe * 0.91;
                const orbit = radius * (1.12 + (probe % 3) * 0.19);
                const x = cx + Math.cos(angle) * orbit;
                const y = cy + Math.sin(angle) * orbit;
                const size = radius * (probe === 0 ? 0.035 : 0.015) + root.energy * 2;
                ctx.fillStyle = rgba(probe % 2 ? root.secondary : stateColor,
                    probe === 0 ? 0.95 : 0.58);
                ctx.beginPath();
                ctx.arc(x, y, size, 0, Math.PI * 2);
                ctx.fill();
            }

            if (root.authenticating) {
                ctx.beginPath();
                ctx.arc(cx, cy, radius * (0.61 + (root.phase % 0.2)), 0, Math.PI * 2);
                ctx.lineWidth = radius * 0.025;
                ctx.strokeStyle = rgba(root.secondary, 0.58);
                ctx.stroke();
            }

            if (root.shock > 0.001) {
                ctx.lineCap = "butt";
                for (let fracture = 0; fracture < 6; fracture++) {
                    const angle = fracture * 1.07 - root.shock * 0.42;
                    const inner = radius * (0.68 + fracture * 0.055);
                    const outer = inner + radius * (0.22 + root.shock * 0.28);
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(angle) * inner, cy + Math.sin(angle) * inner);
                    ctx.lineTo(cx + Math.cos(angle) * outer, cy + Math.sin(angle) * outer);
                    ctx.lineWidth = Math.max(2, radius * 0.012 * root.shock);
                    ctx.strokeStyle = rgba(Theme.danger, 0.70 * root.shock);
                    ctx.stroke();
                }

                const recoil = ctx.createRadialGradient(cx, cy, radius * 0.48,
                    cx, cy, radius * (0.72 + root.shock * 0.32));
                recoil.addColorStop(0, rgba(Theme.danger, 0));
                recoil.addColorStop(0.72, rgba(Theme.danger, 0.16 * root.shock));
                recoil.addColorStop(1, rgba(Theme.danger, 0));
                ctx.fillStyle = recoil;
                ctx.beginPath();
                ctx.arc(cx, cy, radius * 1.12, 0, Math.PI * 2);
                ctx.fill();
            }

            if (root.collapseActive) {
                // Capture is a field of logarithmic streams, not radial spokes.
                // Every packet travels from the outer accretion field toward the
                // event horizon, curves with the disc, brightens, and disappears
                // before crossing the black interior.
                const capture = Math.max(0.001, Math.min(1, root.collapseProgress));
                const streamCount = 26;
                const streamAlpha = 0.18 + capture * 0.54;
                ctx.lineCap = "round";

                function streamPoint(index, progress) {
                    const p = Math.max(0, Math.min(1, progress));
                    const eased = 1 - Math.pow(1 - p, 1.55);
                    const outer = radius * (1.72 + (index % 5) * 0.095);
                    const inner = radius * (0.555 + (index % 3) * 0.012);
                    const base = index * Math.PI * 2 / streamCount
                        + Math.sin(index * 2.17) * 0.16;
                    const curl = 1.02 + (index % 4) * 0.11;
                    const angle = base + turn * 0.055 + curl * eased
                        + Math.sin(p * Math.PI) * 0.10;
                    const orbit = outer + (inner - outer) * eased;
                    return {
                        x: cx + Math.cos(angle) * orbit,
                        y: cy + Math.sin(angle) * orbit
                    };
                }

                // Quiet full-length paths establish the bent accretion flow.
                for (let stream = 0; stream < streamCount; stream++) {
                    const tint = stream % 3 === 0 ? root.secondary : stateColor;
                    ctx.beginPath();
                    for (let sample = 0; sample <= 24; sample++) {
                        const point = streamPoint(stream, sample / 24);
                        if (sample === 0) ctx.moveTo(point.x, point.y);
                        else ctx.lineTo(point.x, point.y);
                    }
                    ctx.lineWidth = Math.max(0.7, radius * (0.0028 + capture * 0.002));
                    ctx.strokeStyle = rgba(tint, streamAlpha * (0.16 + (stream % 4) * 0.025));
                    ctx.stroke();

                    // A short luminous packet moves inward along each curve.
                    const head = (root.suctionPhase * (1.02 + (stream % 4) * 0.08)
                        + stream * 0.071) % 1;
                    const tailLength = 0.20 + (stream % 3) * 0.025;
                    const segments = 9;
                    for (let segment = 0; segment < segments; segment++) {
                        const p0 = head - tailLength + tailLength * segment / segments;
                        const p1 = head - tailLength + tailLength * (segment + 1) / segments;
                        if (p1 <= 0 || p0 >= 1) continue;
                        const a = streamPoint(stream, Math.max(0, p0));
                        const b = streamPoint(stream, Math.min(1, p1));
                        const glow = (segment + 1) / segments;
                        ctx.beginPath();
                        ctx.moveTo(a.x, a.y);
                        ctx.lineTo(b.x, b.y);
                        ctx.lineWidth = Math.max(1.1,
                            radius * (0.004 + glow * 0.010 + capture * 0.004));
                        ctx.strokeStyle = rgba(tint,
                            streamAlpha * (0.16 + glow * glow * 0.76));
                        ctx.stroke();
                    }

                    // The packet condenses briefly at its leading edge.
                    const headPoint = streamPoint(stream, head);
                    const headGlow = 0.45 + 0.55 * head;
                    ctx.fillStyle = rgba(tint, streamAlpha * headGlow);
                    ctx.beginPath();
                    ctx.arc(headPoint.x, headPoint.y,
                        Math.max(1.2, radius * (0.004 + head * 0.006)), 0, Math.PI * 2);
                    ctx.fill();
                }

                // A restrained photon ring flashes where the streams vanish.
                ctx.beginPath();
                ctx.arc(cx, cy, radius * 0.57, 0, Math.PI * 2);
                ctx.lineWidth = Math.max(2, radius * (0.012 + capture * 0.012));
                ctx.strokeStyle = rgba(root.secondary, 0.26 + capture * 0.52);
                ctx.stroke();
            }

        }
    }
}
