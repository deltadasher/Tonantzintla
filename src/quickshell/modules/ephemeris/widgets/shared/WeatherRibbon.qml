import QtQuick
import "../../../../services"
import "../../../.."

Item {
    id: root

    property var forecast: []
    property string unitSymbol: "°C"
    property int selectedIndex: 0
    property int hoveredIndex: -1
    signal dayActivated(int index)

    readonly property int dayCount: Math.min(5, forecast ? forecast.length : 0)
    readonly property int activeIndex: hoveredIndex >= 0 ? hoveredIndex
        : Math.max(0, Math.min(dayCount - 1, selectedIndex))
    readonly property var activeDay: dayCount > 0 ? forecast[activeIndex] : null

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function clockMinutes(value) {
        const parts = String(value || "").split(":");
        if (parts.length !== 2)
            return -1;
        const hours = Number(parts[0]);
        const minutes = Number(parts[1]);
        return isFinite(hours) && isFinite(minutes) ? hours * 60 + minutes : -1;
    }

    function daylightHours(day) {
        const sunrise = clockMinutes(day ? day.sunrise : "");
        const sunset = clockMinutes(day ? day.sunset : "");
        return sunrise >= 0 && sunset > sunrise ? (sunset - sunrise) / 60 : 12;
    }

    function midpoint(day) {
        return (Number(day ? day.max : 0) + Number(day ? day.min : 0)) / 2;
    }

    function temperatureBounds() {
        let low = 0;
        let high = 1;
        if (dayCount > 0) {
            low = midpoint(forecast[0]);
            high = low;
            for (let index = 1; index < dayCount; index++) {
                low = Math.min(low, midpoint(forecast[index]));
                high = Math.max(high, midpoint(forecast[index]));
            }
        }
        if (high - low < 2) {
            low -= 1;
            high += 1;
        }
        return { "low": low, "high": high };
    }

    function plotX(index, canvasWidth) {
        const left = 32;
        const right = canvasWidth - 28;
        return dayCount <= 1 ? (left + right) / 2
            : left + (right - left) * index / (dayCount - 1);
    }

    function centerY(index, canvasHeight) {
        const bounds = temperatureBounds();
        const top = 62;
        const bottom = canvasHeight - 62;
        return top + (bounds.high - midpoint(forecast[index]))
            / (bounds.high - bounds.low) * (bottom - top);
    }

    function halfBand(index, canvasHeight) {
        let largestSwing = 1;
        for (let day = 0; day < dayCount; day++)
            largestSwing = Math.max(largestSwing,
                Math.abs(Number(forecast[day].max) - Number(forecast[day].min)));
        const swing = Math.abs(Number(forecast[index].max) - Number(forecast[index].min));
        return 8 + swing / largestSwing * Math.min(22, canvasHeight * 0.10);
    }

    function ribbonY(index, canvasHeight, edge) {
        return centerY(index, canvasHeight) + edge * halfBand(index, canvasHeight);
    }

    Rectangle {
        anchors.fill: parent
        radius: 28
        color: Qt.rgba(Theme.elevated.r, Theme.elevated.g, Theme.elevated.b, 0.32)
    }

    Canvas {
        id: ribbonCanvas
        anchors.fill: parent
        antialiasing: true

        function trace(edge, ctx) {
            if (root.dayCount === 0)
                return;
            ctx.moveTo(root.plotX(0, width), root.ribbonY(0, height, edge));
            for (let index = 1; index < root.dayCount; index++) {
                const previousX = root.plotX(index - 1, width);
                const currentX = root.plotX(index, width);
                const previousY = root.ribbonY(index - 1, height, edge);
                const currentY = root.ribbonY(index, height, edge);
                const midpoint = (previousX + currentX) / 2;
                ctx.bezierCurveTo(midpoint, previousY, midpoint, currentY,
                    currentX, currentY);
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            if (root.dayCount === 0)
                return;

            for (let index = 0; index < root.dayCount; index++) {
                const daylight = root.daylightHours(root.forecast[index]);
                const x = root.plotX(index, width);
                const nextX = index + 1 < root.dayCount
                    ? root.plotX(index + 1, width) : width - 16;
                const previousX = index > 0 ? root.plotX(index - 1, width) : 16;
                ctx.fillStyle = Qt.rgba(Theme.warning.r, Theme.warning.g,
                    Theme.warning.b, 0.008 + daylight / 24 * 0.026);
                ctx.fillRect((previousX + x) / 2, 18,
                    (nextX - previousX) / 2, height - 48);
            }

            ctx.beginPath();
            trace(-1, ctx);
            for (let index = root.dayCount - 1; index >= 0; index--)
                ctx.lineTo(root.plotX(index, width), root.ribbonY(index, height, 1));
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20);
            ctx.fill();

            for (let index = 0; index < root.dayCount; index++) {
                const precipitation = Number(root.forecast[index].precipitation);
                const dots = Math.round(precipitation / 18);
                const left = index === 0 ? 18
                    : (root.plotX(index - 1, width) + root.plotX(index, width)) / 2;
                const right = index === root.dayCount - 1 ? width - 18
                    : (root.plotX(index, width) + root.plotX(index + 1, width)) / 2;
                ctx.fillStyle = Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b,
                    0.30 + precipitation / 200);
                for (let dot = 0; dot < dots; dot++) {
                    const x = left + (dot + 1) * (right - left) / (dots + 1);
                    const upperY = root.ribbonY(index, height, -1);
                    const lowerY = root.ribbonY(index, height, 1);
                    const y = upperY + (lowerY - upperY)
                        * (0.28 + (dot % 3) * 0.22);
                    ctx.beginPath();
                    ctx.arc(x, y, 1.2, 0, Math.PI * 2);
                    ctx.fill();
                }
            }

            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.lineWidth = 2.4;
            ctx.strokeStyle = Theme.moon;
            ctx.beginPath();
            trace(-1, ctx);
            ctx.stroke();
            ctx.globalAlpha = 0.48;
            ctx.lineWidth = 1.4;
            ctx.beginPath();
            trace(1, ctx);
            ctx.stroke();
            ctx.globalAlpha = 1;
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }

    Connections {
        target: root
        function onForecastChanged() { ribbonCanvas.requestPaint(); }
        function onDayCountChanged() { ribbonCanvas.requestPaint(); }
    }
    Connections {
        target: Theme
        function onAccentChanged() { ribbonCanvas.requestPaint(); }
        function onCyanChanged() { ribbonCanvas.requestPaint(); }
        function onMoonChanged() { ribbonCanvas.requestPaint(); }
        function onWarningChanged() { ribbonCanvas.requestPaint(); }
    }

    Repeater {
        model: root.dayCount
        Item {
            id: dayTick
            required property int index
            readonly property var day: root.forecast[index]
            readonly property real centerX: root.plotX(index, root.width)
            x: centerX - width / 2
            y: 0
            width: Math.max(52, root.width / Math.max(1, root.dayCount) * 0.82)
            height: root.height

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.ribbonY(dayTick.index, root.height, -1) - 5
                width: dayPointer.containsMouse || root.activeIndex === dayTick.index ? 10 : 7
                height: width
                radius: width / 2
                color: dayPointer.containsMouse ? Theme.rose : Theme.moon
                Behavior on width { NumberAnimation { duration: Settings.motion ? 150 : 0 } }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 11
                spacing: 1
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: dayTick.day.day
                    color: root.activeIndex === dayTick.index ? Theme.moon : Theme.muted
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.weight: Font.Black
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: dayTick.day.precipitation + "%"
                    color: Theme.cyan
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
            }

            MouseArea {
                id: dayPointer
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredIndex = dayTick.index
                onExited: if (root.hoveredIndex === dayTick.index) root.hoveredIndex = -1
                onClicked: root.dayActivated(dayTick.index)
            }
        }
    }

    Rectangle {
        visible: root.activeDay !== null
        x: 18
        y: 14
        width: Math.min(parent.width - 36, detailRow.implicitWidth + 24)
        height: 34
        radius: 17
        color: Theme.controlRest
        Row {
            id: detailRow
            anchors.centerIn: parent
            spacing: 9
            Text { text: root.activeDay ? root.activeDay.icon : ""; color: Theme.cyan; font.family: Theme.fontDisplay; font.pixelSize: 17 }
            Text { text: root.activeDay ? root.activeDay.condition.toUpperCase() : ""; color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Black }
            Text { text: root.activeDay ? root.activeDay.max + " / " + root.activeDay.min + root.unitSymbol : ""; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Black }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.dayCount === 0
        text: Weather.loading ? "Loading forecast…" : Weather.status + " · Retry"
        color: Theme.muted
        font.family: Theme.fontMono
        font.pixelSize: 10
        font.weight: Font.Bold
        MouseArea {
            anchors.fill: parent
            enabled: !Weather.loading
            cursorShape: Qt.PointingHandCursor
            onClicked: Weather.refresh()
        }
    }
}
