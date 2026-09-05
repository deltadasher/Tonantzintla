import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"

Item {
    id: root

    property bool railMode: false
    property var cpuHistory: []
    property var memoryHistory: []
    property var networkHistory: []

    function appendHistory(list, value) {
        const next = list.concat([Number(value || 0)]);
        return next.length > 42 ? next.slice(next.length - 42) : next;
    }

    function captureSample() {
        cpuHistory = appendHistory(cpuHistory, SysStats.cpuPercent / 100);
        memoryHistory = appendHistory(memoryHistory, SysStats.memoryPercent / 100);
        networkHistory = appendHistory(networkHistory,
            Math.min(1, (SysStats.networkDown + SysStats.networkUp) / (40 * 1024 * 1024)));
        historyGraph.requestPaint();
    }

    component MetricCard: Rectangle {
        id: metric
        required property string code
        required property string value
        required property string detail
        required property real amount
        property color tone: Theme.accent
        Layout.fillWidth: true
        Layout.preferredHeight: root.railMode ? 82 : 98
        radius: Theme.radiusMedium
        color: Theme.mantle
        border.width: 0
        border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.38)
        clip: true
        Rectangle { width: 78; height: 78; radius: 39; x: metric.width - 45; y: -37; color: metric.tone; opacity: 0.07 }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 11; spacing: 3
            RowLayout {
                Layout.fillWidth: true
                Text { text: metric.code; color: metric.tone; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1 }
                Item { Layout.fillWidth: true }
                Rectangle { width: 6; height: 6; radius: 3; color: metric.amount > 0.9 ? Theme.danger : metric.amount > 0.72 ? Theme.warning : Theme.success }
            }
            Text { text: metric.value; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: root.railMode ? 20 : 25; font.weight: Font.Black }
            Text { Layout.fillWidth: true; text: metric.detail; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; elide: Text.ElideRight }
            Item { Layout.fillHeight: true }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 5; radius: 3; color: Theme.line; clip: true
                Rectangle { width: parent.width * Math.max(0, Math.min(1, metric.amount)); height: parent.height; radius: 3; color: metric.tone; Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } } }
            }
        }
    }

    Component.onCompleted: captureSample()
    Connections {
        target: SysStats
        function onCpuPercentChanged() { root.captureSample(); }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text { text: "NOTIFICATIONS"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 18; font.weight: Font.Black; font.letterSpacing: 0.5 }
                Text { text: SysStats.hostname.toUpperCase() + " // " + SysStats.uptimeLabel + " UPTIME"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.8 }
            }
            ColumnLayout { spacing: 0
                Text { Layout.alignment: Qt.AlignRight; text: "LOAD " + SysStats.loadAverage.toFixed(2); color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10 }
                Text { Layout.alignment: Qt.AlignRight; text: SysStats.processCount + " PROCESSES"; color: Theme.lineBright; font.family: Theme.fontMono; font.pixelSize: 10 }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            MetricCard { code: "CPU"; value: SysStats.cpuPercent + "%"; detail: SysStats.cpuTemperature > 0 ? SysStats.cpuTemperature + "°C CPU" : "NO READING"; amount: SysStats.cpuPercent / 100; tone: Theme.violet }
            MetricCard { code: "MEM"; value: SysStats.memoryPercent + "%"; detail: SysStats.memoryUsedGb + " / " + SysStats.memoryTotalGb + " GB"; amount: SysStats.memoryPercent / 100; tone: Theme.cyan }
            MetricCard { code: "DISK"; value: SysStats.diskPercent + "%"; detail: SysStats.diskUsedGb + " / " + SysStats.diskTotalGb + " GB"; amount: SysStats.diskPercent / 100; tone: Theme.warning }
            MetricCard { code: "THERM"; value: (SysStats.gpuTemperature || SysStats.cpuTemperature) + "°C"; detail: SysStats.gpuTemperature > 0 ? "GPU " + SysStats.gpuTemperature + "° // CPU " + SysStats.cpuTemperature + "°" : "CPU"; amount: (SysStats.gpuTemperature || SysStats.cpuTemperature) / 100; tone: Theme.rose }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 105
            radius: Theme.radiusMedium
            color: Theme.mantle
            border.width: 0
            border.color: Theme.line
            clip: true

            Canvas {
                id: historyGraph
                anchors.fill: parent
                anchors.margins: 10
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const series = [
                        { data: root.cpuHistory, color: Theme.violet },
                        { data: root.memoryHistory, color: Theme.cyan },
                        { data: root.networkHistory, color: Theme.rose }
                    ];
                    ctx.lineWidth = 1;
                    ctx.strokeStyle = Theme.line.toString();
                    for (let row = 1; row < 4; row++) {
                        const y = height * row / 4;
                        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                    }
                    for (const signal of series) {
                        if (signal.data.length < 2) continue;
                        ctx.lineWidth = 2.5;
                        ctx.lineJoin = "round";
                        ctx.strokeStyle = signal.color.toString();
                        ctx.beginPath();
                        for (let index = 0; index < signal.data.length; index++) {
                            const x = index / Math.max(1, signal.data.length - 1) * width;
                            const y = height - 10 - Math.max(0, Math.min(1, signal.data[index])) * (height - 28);
                            if (index === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                        }
                        ctx.stroke();
                    }
                }
            }

            Row {
                anchors.left: parent.left; anchors.leftMargin: 13; anchors.top: parent.top; anchors.topMargin: 10; spacing: 12
                Repeater {
                    model: [
                        { "label": "CPU", "tone": Theme.violet },
                        { "label": "MEM", "tone": Theme.cyan },
                        { "label": "LINK", "tone": Theme.rose }
                    ]
                    Row {
                        required property var modelData
                        spacing: 4
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 4; color: parent.modelData.tone }
                        Text { text: parent.modelData.label; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text { text: "↓ " + SysStats.networkDownLabel; color: Theme.cyan; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold }
            Text { text: "↑ " + SysStats.networkUpLabel; color: Theme.rose; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold }
            Item { Layout.fillWidth: true }
            Text { text: SysStats.kernel; color: Theme.lineBright; font.family: Theme.fontMono; font.pixelSize: 10; elide: Text.ElideMiddle; Layout.maximumWidth: 180 }
        }
    }
}
