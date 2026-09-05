import QtQuick 2.15

Item {
    id: root

    property int count: 0
    property int maxNodes: 32
    property color accent: "#a99cff"
    property color secondary: "#72d9e7"
    property color danger: "#ed7d8f"
    property bool authenticating: false
    property bool failed: false
    property real deployment: 1
    property real phase: 0
    readonly property real progress: Math.min(1, count / Math.max(1, maxNodes))

    function point(t) {
        const u = 1 - t;
        const p0x = width * 0.02;
        const p0y = height * 0.74;
        const p1x = width * 0.27;
        const p1y = height * -0.08;
        const p2x = width * 0.62;
        const p2y = height * 1.10;
        const p3x = width * 0.98;
        const p3y = height * 0.24;
        return {
            x: u * u * u * p0x + 3 * u * u * t * p1x
                + 3 * u * t * t * p2x + t * t * t * p3x,
            y: u * u * u * p0y + 3 * u * u * t * p1y
                + 3 * u * t * t * p2y + t * t * t * p3y
        };
    }

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: 5200
        loops: Animation.Infinite
        running: root.visible
    }

    Canvas {
        id: path
        anchors.fill: parent

        Connections {
            target: root
            function onCountChanged() { path.requestPaint(); }
            function onPhaseChanged() { path.requestPaint(); }
            function onAuthenticatingChanged() { path.requestPaint(); }
            function onFailedChanged() { path.requestPaint(); }
            function onDeploymentChanged() { path.requestPaint(); }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        function rgba(color, alpha) {
            return "rgba(" + Math.round(color.r * 255) + ","
                + Math.round(color.g * 255) + ","
                + Math.round(color.b * 255) + "," + alpha + ")";
        }

        function strokeCurve(ctx, until, color, lineWidth, alpha) {
            const steps = 120;
            const limit = Math.max(0.01, until * root.deployment);
            const first = root.point(0);
            ctx.beginPath();
            ctx.moveTo(first.x, first.y);
            for (let i = 1; i <= steps * limit; i++) {
                const p = root.point(i / steps);
                ctx.lineTo(p.x, p.y);
            }
            ctx.lineCap = "round";
            ctx.lineWidth = lineWidth;
            ctx.strokeStyle = rgba(color, alpha);
            ctx.stroke();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const stateColor = root.failed ? root.danger : root.accent;
            strokeCurve(ctx, 1, root.secondary, Math.max(1, height * 0.005), 0.08);
            if (root.progress > 0)
                strokeCurve(ctx, root.progress, stateColor,
                    Math.max(2, height * 0.013), 0.76);

            if (root.authenticating) {
                const scan = root.point(root.phase);
                const glow = ctx.createRadialGradient(scan.x, scan.y, 0,
                    scan.x, scan.y, height * 0.11);
                glow.addColorStop(0, rgba(root.secondary, 0.92));
                glow.addColorStop(1, rgba(root.secondary, 0));
                ctx.fillStyle = glow;
                ctx.beginPath();
                ctx.arc(scan.x, scan.y, height * 0.11, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    Repeater {
        model: root.maxNodes

        Item {
            id: node
            required property int index
            readonly property real pathTime: root.maxNodes > 1
                ? index / (root.maxNodes - 1) : 0
            readonly property var location: root.point(pathTime)
            readonly property bool lit: index < Math.min(root.count, root.maxNodes)
            readonly property bool newest: lit
                && index === Math.min(root.count, root.maxNodes) - 1
            readonly property real nodeSize: Math.max(7, root.height * 0.044)

            x: location.x - width / 2
            y: location.y - height / 2
            width: nodeSize * (newest ? 1.32 : 1)
            height: width
            opacity: lit && pathTime <= root.deployment ? 1 : 0
            scale: lit && pathTime <= root.deployment ? 1 : 0.05

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.failed ? root.danger
                    : node.newest ? root.secondary : root.accent
                opacity: node.newest ? 1 : 0.76
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 3.4
                height: width
                radius: width / 2
                color: root.failed ? root.danger : root.secondary
                opacity: node.newest ? 0.13 : 0
            }

            Behavior on opacity { NumberAnimation { duration: 160 } }
            Behavior on scale {
                NumberAnimation {
                    duration: 330
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.8
                }
            }
        }
    }
}
