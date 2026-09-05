import QtQuick
import QtQuick.Layouts
import "../../../.."
import "../../../../services"

Item {
    id: root

    readonly property int therm: Math.max(SysStats.cpuTemperature, SysStats.gpuTemperature)
    readonly property color thermTone: therm >= 85 ? Theme.danger
        : therm >= 70 ? Theme.rose
        : therm >= 55 ? Theme.warning
        : Theme.cyan
    readonly property real cpuRatio: Math.max(0, Math.min(1, SysStats.cpuPercent / 100))
    readonly property real memRatio: Math.max(0, Math.min(1, SysStats.memoryPercent / 100))
    readonly property real diskRatio: Math.max(0, Math.min(1, SysStats.diskPercent / 100))

    // Canvas colour stops need CSS strings; Theme hands out colours.
    function tint(base, alpha) {
        return "rgba(" + Math.round(base.r * 255) + "," + Math.round(base.g * 255)
            + "," + Math.round(base.b * 255) + "," + alpha + ")";
    }

    function focusPrimary() {
        forceActiveFocus();
    }

    // Instantiated twice rather than driven by a Repeater: an inline model of
    // live readings would rebuild both delegates on every poll and restart the
    // fill animation from zero.
    component Meter: ColumnLayout {
        id: meter

        property string label: ""
        property real ratio: 0
        property int percent: 0
        property string detail: ""
        property color tone: Theme.accent

        Layout.fillWidth: true
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: meter.label
                color: meter.tone
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 1
            }
            Item { Layout.fillWidth: true }
            Text {
                text: meter.detail
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 11
            }
            Text {
                text: meter.percent + "%"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 14
                font.weight: Font.Black
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            radius: 4
            color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.07)

            Rectangle {
                width: Math.max(parent.height, parent.width * meter.ratio)
                height: parent.height
                radius: parent.radius
                color: meter.tone
                opacity: 0.88
                Behavior on width {
                    NumberAnimation {
                        duration: Settings.motion ? Theme.motionNormal : 0
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                text: "SYSTEM"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 22
                font.weight: Font.Black
            }
            Item { Layout.fillWidth: true }
            Text {
                text: SysStats.hostname
                color: Theme.muted
                font.family: Theme.fontText
                font.pixelSize: 12
            }
            Text {
                text: "LOAD " + SysStats.loadAverage.toFixed(2)
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.weight: Font.Bold
            }
            Text {
                text: SysStats.uptimeLabel + "  ·  " + SysStats.processCount + " PROCESSES"
                color: Theme.moon
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // ── Processor load, drawn as an orbit ────────────────────────────
            Rectangle {
                Layout.preferredWidth: Math.max(210, Math.min(268, root.width * 0.27))
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: Theme.mantle

                Canvas {
                    id: orbitDial
                    anchors.fill: parent
                    antialiasing: true

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const cx = width / 2;
                        const cy = height / 2;
                        const radius = Math.min(width, height) * 0.33;
                        const start = Math.PI * 0.75;
                        const sweep = Math.PI * 1.5;

                        // Orbital plane: flattened rings behind the dial. Paths
                        // are transformed as they are built, so restoring before
                        // the stroke keeps the line width even.
                        for (let ring = 0; ring < 3; ring++) {
                            ctx.save();
                            ctx.translate(cx, cy);
                            ctx.scale(1, 0.30);
                            ctx.beginPath();
                            ctx.arc(0, 0, radius * (1.18 + ring * 0.30), 0, Math.PI * 2);
                            ctx.restore();
                            ctx.strokeStyle = root.tint(Theme.lineBright, 0.16 - ring * 0.04);
                            ctx.lineWidth = 1;
                            ctx.stroke();
                        }

                        // Graduations every ten percent.
                        for (let step = 0; step <= 10; step++) {
                            const angle = start + sweep * (step / 10);
                            const inner = radius + 11;
                            const outer = radius + (step % 5 === 0 ? 19 : 15);
                            ctx.beginPath();
                            ctx.moveTo(cx + Math.cos(angle) * inner,
                                cy + Math.sin(angle) * inner);
                            ctx.lineTo(cx + Math.cos(angle) * outer,
                                cy + Math.sin(angle) * outer);
                            ctx.strokeStyle = root.tint(Theme.lineBright,
                                step % 5 === 0 ? 0.55 : 0.25);
                            ctx.lineWidth = step % 5 === 0 ? 2 : 1;
                            ctx.stroke();
                        }

                        ctx.lineCap = "round";

                        // Unswept track.
                        ctx.beginPath();
                        ctx.arc(cx, cy, radius, start, start + sweep);
                        ctx.strokeStyle = root.tint(Theme.moon, 0.09);
                        ctx.lineWidth = 7;
                        ctx.stroke();

                        // Swept load. Always visible: a floor keeps a near-idle
                        // reading from vanishing into the track.
                        const swept = Math.max(0.012, root.cpuRatio);
                        ctx.beginPath();
                        ctx.arc(cx, cy, radius, start, start + sweep * swept);
                        ctx.strokeStyle = root.tint(root.thermTone, 0.95);
                        ctx.lineWidth = 7;
                        ctx.stroke();

                        // The body riding the orbit at the current reading.
                        const head = start + sweep * swept;
                        const hx = cx + Math.cos(head) * radius;
                        const hy = cy + Math.sin(head) * radius;
                        ctx.beginPath();
                        ctx.arc(hx, hy, 11, 0, Math.PI * 2);
                        ctx.fillStyle = root.tint(root.thermTone, 0.20);
                        ctx.fill();
                        ctx.beginPath();
                        ctx.arc(hx, hy, 5, 0, Math.PI * 2);
                        ctx.fillStyle = root.tint(Theme.moon, 1);
                        ctx.fill();
                    }

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    Connections {
                        target: SysStats
                        function onCpuPercentChanged() { orbitDial.requestPaint(); }
                        function onCpuTemperatureChanged() { orbitDial.requestPaint(); }
                        function onGpuTemperatureChanged() { orbitDial.requestPaint(); }
                    }
                    Connections {
                        target: Theme
                        function onAccentChanged() { orbitDial.requestPaint(); }
                        function onMoonChanged() { orbitDial.requestPaint(); }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: SysStats.cpuPercent + "%"
                        color: Theme.moon
                        font.family: Theme.fontDisplay
                        font.pixelSize: 40
                        font.weight: Font.Black
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "PROCESSOR"
                        color: Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.4
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    spacing: 7
                    visible: root.therm > 0
                    Rectangle {
                        width: 7
                        height: 7
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.thermTone
                    }
                    Text {
                        text: root.therm + "° "
                            + (root.therm >= 85 ? "HOT"
                                : root.therm >= 70 ? "WARM" : "COOL")
                        color: root.thermTone
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // ── Load over time ──────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 150
                    radius: Theme.radiusLarge
                    color: Theme.mantle
                    clip: true

                    Canvas {
                        id: traceCanvas
                        anchors.fill: parent
                        anchors.topMargin: 34
                        anchors.bottomMargin: 14
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        antialiasing: true

                        function plot(ctx, key, base, fillAlpha) {
                            const samples = SysStats.trace;
                            if (!samples || samples.length < 2)
                                return;
                            const step = width / (samples.length - 1);
                            ctx.beginPath();
                            for (let index = 0; index < samples.length; index++) {
                                const ratio = Math.max(0, Math.min(1,
                                    Number(samples[index][key] || 0) / 100));
                                const x = index * step;
                                const y = height - ratio * height;
                                if (index === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                            }
                            ctx.strokeStyle = root.tint(base, 0.92);
                            ctx.lineWidth = 2;
                            ctx.lineJoin = "round";
                            ctx.stroke();

                            const gradient = ctx.createLinearGradient(0, 0, 0, height);
                            gradient.addColorStop(0, root.tint(base, fillAlpha));
                            gradient.addColorStop(1, root.tint(base, 0));
                            ctx.lineTo(width, height);
                            ctx.lineTo(0, height);
                            ctx.closePath();
                            ctx.fillStyle = gradient;
                            ctx.fill();
                        }

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();

                            // Fixed starfield: deterministic, unanimated depth.
                            for (let star = 0; star < 22; star++) {
                                const sx = ((star * 137) % 991) / 991 * width;
                                const sy = ((star * 71 + 13) % 397) / 397 * height;
                                ctx.beginPath();
                                ctx.arc(sx, sy, star % 6 === 0 ? 1.4 : 0.8, 0, Math.PI * 2);
                                ctx.fillStyle = root.tint(Theme.moon,
                                    star % 6 === 0 ? 0.16 : 0.09);
                                ctx.fill();
                            }

                            for (let line = 1; line < 4; line++) {
                                const y = height * line / 4;
                                ctx.beginPath();
                                ctx.moveTo(0, y);
                                ctx.lineTo(width, y);
                                ctx.strokeStyle = root.tint(Theme.lineBright, 0.14);
                                ctx.lineWidth = 1;
                                ctx.stroke();
                            }

                            plot(ctx, "memory", Theme.cyan, 0.20);
                            plot(ctx, "cpu", Theme.violet, 0.30);
                        }

                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Component.onCompleted: requestPaint()

                        Connections {
                            target: SysStats
                            function onTraceChanged() { traceCanvas.requestPaint(); }
                        }
                        Connections {
                            target: Theme
                            function onAccentChanged() { traceCanvas.requestPaint(); }
                        }
                    }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 16
                        spacing: 14

                        Text {
                            text: "LAST 2 MINUTES"
                            color: Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                        }
                        Item { Layout.fillWidth: true }
                        Row {
                            spacing: 6
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.violet
                            }
                            Text {
                                text: "PROCESSOR"
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }
                        Row {
                            spacing: 6
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.cyan
                            }
                            Text {
                                text: "MEMORY"
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }
                    }
                }

                // ── Network, mirrored about a horizon ───────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 148
                    radius: Theme.radiusLarge
                    color: Theme.mantle
                    clip: true

                    Canvas {
                        id: netCanvas
                        anchors.fill: parent
                        anchors.topMargin: 34
                        anchors.bottomMargin: 14
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        antialiasing: true

                        // Scale to the busiest moment in the window so a quiet
                        // link still shows shape instead of a flat nothing.
                        function ceiling() {
                            let peak = 65536;
                            const samples = SysStats.trace || [];
                            for (let index = 0; index < samples.length; index++) {
                                peak = Math.max(peak,
                                    Number(samples[index].down || 0),
                                    Number(samples[index].up || 0));
                            }
                            return peak;
                        }

                        function plot(ctx, key, base, upward, peak) {
                            const samples = SysStats.trace;
                            if (!samples || samples.length < 2)
                                return;
                            const horizon = height / 2;
                            const extent = height / 2 - 4;
                            const step = width / (samples.length - 1);
                            ctx.beginPath();
                            ctx.moveTo(0, horizon);
                            for (let index = 0; index < samples.length; index++) {
                                const ratio = Math.max(0, Math.min(1,
                                    Number(samples[index][key] || 0) / peak));
                                const x = index * step;
                                const y = horizon + (upward ? -1 : 1) * ratio * extent;
                                ctx.lineTo(x, y);
                            }
                            ctx.lineTo(width, horizon);
                            ctx.closePath();
                            ctx.fillStyle = root.tint(base, 0.26);
                            ctx.fill();
                            ctx.strokeStyle = root.tint(base, 0.90);
                            ctx.lineWidth = 1.6;
                            ctx.stroke();
                        }

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const peak = ceiling();
                            plot(ctx, "up", Theme.rose, true, peak);
                            plot(ctx, "down", Theme.cyan, false, peak);
                            ctx.beginPath();
                            ctx.moveTo(0, height / 2);
                            ctx.lineTo(width, height / 2);
                            ctx.strokeStyle = root.tint(Theme.lineBright, 0.45);
                            ctx.lineWidth = 1;
                            ctx.stroke();
                        }

                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Component.onCompleted: requestPaint()

                        Connections {
                            target: SysStats
                            function onTraceChanged() { netCanvas.requestPaint(); }
                        }
                    }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 16
                        spacing: 14

                        Text {
                            text: "NETWORK"
                            color: Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "↓ " + SysStats.networkDownLabel
                            color: Theme.cyan
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                        Text {
                            text: "↑ " + SysStats.networkUpLabel
                            color: Theme.rose
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }

        // ── Memory and disk, as full-width meters ───────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 104
            radius: Theme.radiusLarge
            color: Theme.mantle

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Meter {
                    label: "MEMORY"
                    ratio: root.memRatio
                    percent: SysStats.memoryPercent
                    detail: SysStats.memoryUsedGb + " / " + SysStats.memoryTotalGb + " GB"
                    tone: Theme.cyan
                }

                Meter {
                    label: "DISK"
                    ratio: root.diskRatio
                    percent: SysStats.diskPercent
                    detail: SysStats.diskUsedGb + " / " + SysStats.diskTotalGb + " GB"
                    tone: Theme.warning
                }
            }
        }
    }
}
