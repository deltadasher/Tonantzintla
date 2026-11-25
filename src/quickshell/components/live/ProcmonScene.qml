import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"

pragma ComponentBehavior: Bound

// A calm system monitor drawn from the shared SysStats service: no second
// poller, and nothing leaves the machine. SysStats keeps its detailed
// two-second cadence while this scene is the applied wallpaper.
Item {
    id: scene
    property var values: ({})
    property bool running: true
    property point pointer: Qt.point(-1, -1)
    property bool pointerActive: false
    function pulse(x, y) {}

    readonly property real zoom: Math.max(0.6, (Number(values.scale) || 100) / 100) * Math.max(0.8, Math.min(1.6, width / 1920))
    function px(size) { return Math.round(size * zoom); }

    Rectangle { anchors.fill: parent; color: Theme.void_ }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(scene.width - scene.px(120), scene.px(1180))
        spacing: scene.px(40)

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: SysStats.hostname.toLowerCase()
                color: Theme.accent; font.family: Theme.fontDisplay; font.pixelSize: scene.px(52); font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Text {
                text: (SysStats.kernel.length ? "Linux " + SysStats.kernel + "  ·  " : "") + "up " + SysStats.uptimeLabel
                color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: scene.px(22)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: scene.px(36)
            Column {
                spacing: scene.px(2)
                Text {
                    text: SysStats.available ? SysStats.cpuPercent + "%" : "…"
                    color: SysStats.cpuPercent > 85 ? Theme.warning : Theme.moon
                    font.family: Theme.fontMono; font.pixelSize: scene.px(112); font.weight: Font.Light
                }
                Text { text: "Processor"; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: scene.px(23) }
            }
            Canvas {
                id: trace
                Layout.fillWidth: true; Layout.preferredHeight: scene.px(180)
                readonly property var samples: SysStats.trace
                readonly property color stroke: Theme.accent
                onSamplesChanged: requestPaint()
                onStrokeChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const data = trace.samples || [];
                    if (data.length < 2) return;
                    const stepX = width / (data.length - 1);
                    ctx.beginPath();
                    for (let i = 0; i < data.length; ++i) {
                        const y = height - 2 - Math.max(0, Math.min(100, data[i].cpu)) / 100 * (height - 6);
                        if (i === 0) ctx.moveTo(0, y); else ctx.lineTo(i * stepX, y);
                    }
                    ctx.lineWidth = Math.max(1.5, scene.px(2));
                    ctx.strokeStyle = String(trace.stroke);
                    ctx.stroke();
                    ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath();
                    ctx.fillStyle = Qt.rgba(trace.stroke.r, trace.stroke.g, trace.stroke.b, 0.12);
                    ctx.fill();
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: scene.px(10)
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Memory"; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: scene.px(23) }
                Item { Layout.fillWidth: true }
                Text {
                    text: SysStats.memoryUsedGb.toFixed(1) + " of " + SysStats.memoryTotalGb.toFixed(1) + " GB"
                    color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: scene.px(26)
                }
            }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: scene.px(10); radius: height / 2; color: Theme.elevated
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(100, SysStats.memoryPercent)) / 100
                    height: parent.height; radius: height / 2
                    color: SysStats.memoryPercent > 85 ? Theme.warning : Theme.cyan
                    Behavior on width { NumberAnimation { duration: Theme.duration(600); easing.type: Easing.OutCubic } }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: scene.px(18)
            Repeater {
                model: [
                    { label: "Download", value: SysStats.networkDownLabel },
                    { label: "Upload", value: SysStats.networkUpLabel },
                    { label: "Load", value: SysStats.loadAverage.toFixed(2) },
                    { label: "Processor heat", value: SysStats.cpuTemperature > 0 ? SysStats.cpuTemperature + " °C" : "Unavailable" },
                    { label: "Processes", value: SysStats.processCount > 0 ? String(SysStats.processCount) : "…" }
                ]
                Column {
                    id: reading
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: scene.px(4)
                    Text { text: reading.modelData.value; color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: scene.px(30) }
                    Text { text: reading.modelData.label; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: scene.px(20) }
                }
            }
        }
    }
}
