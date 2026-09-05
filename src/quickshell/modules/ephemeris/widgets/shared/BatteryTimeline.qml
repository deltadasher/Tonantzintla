import QtQuick
import "../../../.."

Item {
    id: root

    property bool available: false
    property bool charging: false
    property int percent: 0
    property int secondsRemaining: 0
    property real energy: 0
    property real capacity: 0
    property real rate: 0

    readonly property int projectedSeconds: secondsRemaining > 0 ? secondsRemaining
        : rate <= 0 ? 0
        : Math.round((charging ? Math.max(0, capacity - energy) : energy) / rate * 3600)
    readonly property int thresholdSeconds: !charging && percent > 20
        && projectedSeconds > 0
        ? Math.round(projectedSeconds * (percent - 20) / Math.max(1, percent)) : 0
    readonly property color curveColor: charging ? Theme.success
        : percent <= 20 ? Theme.danger : Theme.accent

    function clockAfter(seconds) {
        if (seconds <= 0)
            return "--:--";
        return Qt.formatTime(new Date(Date.now() + seconds * 1000), "HH:mm");
    }

    function projectedPercent(fraction) {
        const eased = Math.pow(Math.max(0, Math.min(1, fraction)), 1.08);
        return charging ? percent + (100 - percent) * eased
            : percent * (1 - eased);
    }

    Rectangle {
        anchors.fill: parent
        radius: 26
        color: Qt.rgba(Theme.elevated.r, Theme.elevated.g, Theme.elevated.b, 0.36)
    }

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 18
        spacing: 1
        Text {
            text: !root.available ? "EXTERNAL POWER"
                : root.projectedSeconds <= 0 ? "LEARNING YOUR DRAW"
                : root.charging ? "FULL AT " + root.clockAfter(root.projectedSeconds)
                : root.percent > 20 ? "20% AT " + root.clockAfter(root.thresholdSeconds)
                : "EMPTY AT " + root.clockAfter(root.projectedSeconds)
            color: root.curveColor
            font.family: Theme.fontDisplay
            font.pixelSize: 18
            font.weight: Font.Black
        }
        Text {
            text: !root.available ? "NO BATTERY DETECTED"
                : root.rate > 0 ? root.rate.toFixed(1) + " W LIVE RATE"
                : "WAITING FOR A STABLE RATE"
            color: Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }

    Canvas {
        id: curveCanvas
        anchors.fill: parent
        anchors.topMargin: 46
        antialiasing: true

        function xFor(fraction) {
            return 34 + fraction * (width - 68);
        }

        function yFor(value) {
            return 18 + (100 - value) / 100 * (height - 72);
        }

        function trace(ctx) {
            const samples = 52;
            for (let index = 0; index <= samples; index++) {
                const fraction = index / samples;
                const x = xFor(fraction);
                const y = yFor(root.projectedPercent(fraction));
                if (index === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            if (!root.available)
                return;

            const left = xFor(0);
            const right = xFor(1);
            const bottom = yFor(0);

            ctx.strokeStyle = Qt.rgba(Theme.danger.r, Theme.danger.g,
                Theme.danger.b, 0.34);
            ctx.lineWidth = 1;
            ctx.setLineDash([4, 7]);
            ctx.beginPath();
            ctx.moveTo(left, yFor(20));
            ctx.lineTo(right, yFor(20));
            ctx.stroke();
            ctx.setLineDash([]);

            ctx.beginPath();
            trace(ctx);
            ctx.lineTo(right, bottom);
            ctx.lineTo(left, bottom);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(root.curveColor.r, root.curveColor.g,
                root.curveColor.b, 0.15);
            ctx.fill();

            ctx.beginPath();
            trace(ctx);
            ctx.strokeStyle = root.curveColor;
            ctx.lineWidth = 3;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.stroke();

            ctx.beginPath();
            ctx.arc(left, yFor(root.percent), 6, 0, Math.PI * 2);
            ctx.fillStyle = Theme.moon;
            ctx.fill();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }

    Connections {
        target: root
        function onAvailableChanged() { curveCanvas.requestPaint(); }
        function onChargingChanged() { curveCanvas.requestPaint(); }
        function onPercentChanged() { curveCanvas.requestPaint(); }
        function onProjectedSecondsChanged() { curveCanvas.requestPaint(); }
        function onCurveColorChanged() { curveCanvas.requestPaint(); }
    }
    Connections {
        target: Theme
        function onAccentChanged() { curveCanvas.requestPaint(); }
        function onDangerChanged() { curveCanvas.requestPaint(); }
        function onMoonChanged() { curveCanvas.requestPaint(); }
    }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        anchors.bottomMargin: 12
        Text {
            width: parent.width / 3
            text: root.available ? "NOW  " + root.percent + "%" : "NOW"
            color: Theme.moon
            font.family: Theme.fontMono
            font.pixelSize: 10
            font.weight: Font.Black
        }
        Text {
            width: parent.width / 3
            horizontalAlignment: Text.AlignHCenter
            text: !root.available || root.charging || root.thresholdSeconds <= 0
                ? "" : "20%  " + root.clockAfter(root.thresholdSeconds)
            color: Theme.danger
            font.family: Theme.fontMono
            font.pixelSize: 10
            font.weight: Font.Black
        }
        Text {
            width: parent.width / 3
            horizontalAlignment: Text.AlignRight
            text: root.projectedSeconds > 0
                ? (root.charging ? "FULL  " : "EMPTY  ")
                    + root.clockAfter(root.projectedSeconds) : ""
            color: Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: 10
            font.weight: Font.Black
        }
    }
}
