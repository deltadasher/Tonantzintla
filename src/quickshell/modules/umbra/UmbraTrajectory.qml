import QtQuick
import "../.."

Item {
    id: root

    property int count: 0
    property int maxNodes: 32
    property real deployment: 1
    property real energy: 0
    property bool failed: false
    property bool authenticating: false
    property bool motionActive: true
    property color primary: Theme.accent
    property color secondary: Theme.cyan
    property real phase: 0
    readonly property real progress: Math.min(1, count / Math.max(1, maxNodes))

    function point(t) {
        const u = 1 - t;
        const p0x = width * 0.035;
        const p0y = height * 0.72;
        const p1x = width * 0.27;
        const p1y = height * 0.03;
        const p2x = width * 0.68;
        const p2y = height * 0.98;
        const p3x = width * 0.94;
        const p3y = height * 0.27;
        return {
            x: u * u * u * p0x + 3 * u * u * t * p1x + 3 * u * t * t * p2x + t * t * t * p3x,
            y: u * u * u * p0y + 3 * u * u * t * p1y + 3 * u * t * t * p2y + t * t * t * p3y
        };
    }

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: Settings.motion && Settings.umbraMotion ? 6400 : 1
        loops: Animation.Infinite
        running: root.motionActive && Settings.motion && Settings.umbraMotion && root.visible
    }

    Canvas {
        id: trajectory
        anchors.fill: parent

        Connections {
            target: root
            function onCountChanged() { trajectory.requestPaint(); }
            function onDeploymentChanged() { trajectory.requestPaint(); }
            function onEnergyChanged() { trajectory.requestPaint(); }
            function onFailedChanged() { trajectory.requestPaint(); }
            function onAuthenticatingChanged() { trajectory.requestPaint(); }
            function onPhaseChanged() { trajectory.requestPaint(); }
            function onPrimaryChanged() { trajectory.requestPaint(); }
            function onSecondaryChanged() { trajectory.requestPaint(); }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        function rgba(color, alpha) {
            return "rgba(" + Math.round(color.r * 255) + ","
                + Math.round(color.g * 255) + ","
                + Math.round(color.b * 255) + "," + alpha + ")";
        }

        function strokeCurve(ctx, until, color, widthValue, alpha) {
            const steps = 100;
            const limit = Math.max(0.01, until * root.deployment);
            const first = root.point(0);
            ctx.beginPath();
            ctx.moveTo(first.x, first.y);
            for (let step = 1; step <= steps * limit; step++) {
                const p = root.point(step / steps);
                ctx.lineTo(p.x, p.y);
            }
            ctx.lineWidth = widthValue;
            ctx.lineCap = "round";
            ctx.strokeStyle = rgba(color, alpha);
            ctx.stroke();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const stateColor = root.failed ? Theme.danger : root.primary;
            strokeCurve(ctx, 1, Theme.moon, Math.max(1, height * 0.006), 0.10);
            if (root.progress > 0)
                strokeCurve(ctx, root.progress, stateColor,
                    Math.max(2, height * (0.012 + root.energy * 0.008)),
                    0.52 + root.energy * 0.30);

            // Two ghost trajectories imply possible futures without boxing the
            // password into a text field.
            ctx.setLineDash([2, 14]);
            ctx.lineDashOffset = root.phase * -32;
            ctx.beginPath();
            ctx.moveTo(width * 0.12, height * 0.92);
            ctx.bezierCurveTo(width * 0.37, height * 0.50, width * 0.55, height * 0.14,
                width * 0.86, height * 0.06);
            ctx.lineWidth = 1;
            ctx.strokeStyle = rgba(root.secondary, 0.12);
            ctx.stroke();
            ctx.setLineDash([]);

            if (root.authenticating) {
                const scan = root.point(root.phase);
                ctx.fillStyle = rgba(root.secondary, 0.9);
                ctx.beginPath();
                ctx.arc(scan.x, scan.y, height * 0.045, 0, Math.PI * 2);
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
            readonly property var pathPoint: root.point(pathTime)
            readonly property bool lit: index < Math.min(root.count, root.maxNodes)
            readonly property bool newest: lit
                && index === Math.min(root.count, root.maxNodes) - 1
            readonly property real dotSize: Math.max(7, root.height * 0.046)

            x: pathPoint.x - width / 2
            y: pathPoint.y - height / 2
            width: dotSize * (newest ? 1.18 : 1)
            height: width
            opacity: lit && pathTime <= root.deployment ? 1 : 0
            scale: lit && pathTime <= root.deployment ? 1 : 0.08

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.failed ? Theme.danger
                    : node.newest ? root.secondary : root.primary
                opacity: node.newest ? 1 : 0.86
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 2.7
                height: width
                radius: width / 2
                color: Qt.rgba(root.secondary.r, root.secondary.g,
                    root.secondary.b, 0.16)
                opacity: node.newest ? 0.22 + root.energy * 0.18 : 0
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Settings.motion && Settings.umbraMotion ? 170 : 0
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Settings.motion && Settings.umbraMotion ? 360 : 0
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.7
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: Settings.motion && Settings.umbraMotion ? 240 : 0
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
