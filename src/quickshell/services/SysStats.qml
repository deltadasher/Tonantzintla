pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: root

    readonly property string helperPath: Environment.script("system-telemetry.py")
    readonly property bool detailActive: ShellState.ephemerisVisible
        && (ShellState.ephemerisTab === "system"
            || ShellState.ephemerisTab === "quickstats")

    property int cpuPercent: 0
    property int memoryPercent: 0
    property real memoryUsedGb: 0
    property real memoryTotalGb: 0
    property int cpuTemperature: 0
    property int gpuTemperature: 0
    property int diskPercent: 0
    property real diskUsedGb: 0
    property real diskTotalGb: 0
    property real networkDown: 0
    property real networkUp: 0
    property int uptimeSeconds: 0
    property string hostname: "TONANTZINTLA"
    property string kernel: ""
    property real loadAverage: 0
    property int processCount: 0

    property real previousCpuTotal: 0
    property real previousCpuIdle: 0
    property real previousRxTotal: 0
    property real previousTxTotal: 0
    property double previousSampleMs: 0

    // Bounded ring of readings for the System panel traces. Appended once per
    // poll and only while the panel is open, so it costs nothing when closed.
    readonly property int traceDepth: 60
    property var trace: []

    readonly property string uptimeLabel: {
        const days = Math.floor(uptimeSeconds / 86400);
        const hours = Math.floor((uptimeSeconds % 86400) / 3600);
        const minutes = Math.floor((uptimeSeconds % 3600) / 60);
        return days > 0 ? days + "D " + hours + "H"
            : hours > 0 ? hours + "H " + minutes + "M" : minutes + "M";
    }
    readonly property string networkDownLabel: formatRate(networkDown)
    readonly property string networkUpLabel: formatRate(networkUp)

    function bytesToGb(bytes) {
        return Math.round(bytes / 1073741824 * 10) / 10;
    }

    function clampPercent(value) {
        const number = Number(value);
        return isFinite(number) ? Math.max(0, Math.min(100, Math.round(number))) : 0;
    }

    function formatBytes(bytes) {
        if (!bytes || bytes <= 0)
            return "0 B";
        const units = ["B", "KB", "MB", "GB", "TB"];
        const index = Math.min(units.length - 1,
            Math.floor(Math.log(bytes) / Math.log(1024)));
        return (bytes / Math.pow(1024, index)).toFixed(index > 1 ? 1 : 0)
            + " " + units[index];
    }

    function formatRate(bytes) {
        return formatBytes(bytes) + "/s";
    }

    function applyCpu(raw) {
        const firstLine = String(raw).split("\n")[0].trim().split(/\s+/);
        if (firstLine.length < 5 || firstLine[0] !== "cpu")
            return;
        let total = 0;
        for (let index = 1; index < firstLine.length; index++)
            total += Number(firstLine[index] || 0);
        const idle = Number(firstLine[4] || 0) + Number(firstLine[5] || 0);
        const totalDelta = total - previousCpuTotal;
        const idleDelta = idle - previousCpuIdle;
        if (previousCpuTotal > 0 && totalDelta > 0)
            cpuPercent = clampPercent((1 - idleDelta / totalDelta) * 100);
        previousCpuTotal = total;
        previousCpuIdle = idle;
    }

    function applyMemory(raw) {
        const values = {};
        const lines = String(raw).split("\n");
        for (let index = 0; index < lines.length; index++) {
            const match = lines[index].match(/^([^:]+):\s+([0-9]+)/);
            if (match)
                values[match[1]] = Number(match[2]) * 1024;
        }
        const total = Number(values.MemTotal || 0);
        const available = Number(values.MemAvailable);
        const used = total > 0
            ? Math.max(0, Math.min(total,
                total - (isFinite(available) ? available : total))) : 0;
        memoryPercent = total > 0 ? clampPercent(used / total * 100) : 0;
        memoryUsedGb = bytesToGb(used);
        memoryTotalGb = bytesToGb(total);
    }

    function applyNetwork(raw) {
        const now = Date.now();
        let rx = 0;
        let tx = 0;
        const lines = String(raw).split("\n");
        for (let index = 2; index < lines.length; index++) {
            if (lines[index].indexOf(":") < 0)
                continue;
            const halves = lines[index].split(":");
            if (halves[0].trim() === "lo")
                continue;
            const fields = halves[1].trim().split(/\s+/);
            if (fields.length >= 9) {
                rx += Number(fields[0] || 0);
                tx += Number(fields[8] || 0);
            }
        }
        const elapsed = previousSampleMs > 0
            ? Math.max(0.25, (now - previousSampleMs) / 1000) : 0;
        if (elapsed > 0 && previousRxTotal > 0) {
            networkDown = Math.max(0, (rx - previousRxTotal) / elapsed);
            networkUp = Math.max(0, (tx - previousTxTotal) / elapsed);
        }
        previousRxTotal = rx;
        previousTxTotal = tx;
        previousSampleMs = now;
    }

    function applySlowSnapshot(data) {
        cpuTemperature = Number(data.cpu_temp || 0);
        gpuTemperature = Number(data.gpu_temp || 0);
        const diskTotal = Number(data.disk_total || 0);
        const diskUsed = Number(data.disk_used || 0);
        diskPercent = diskTotal > 0
            ? clampPercent(diskUsed / diskTotal * 100) : 0;
        diskUsedGb = bytesToGb(diskUsed);
        diskTotalGb = bytesToGb(diskTotal);
        hostname = data.hostname || "TONANTZINTLA";
        kernel = data.kernel || "";
        processCount = Number(data.processes || 0);
    }

    // Records the readings settled by the previous poll. Reassigns the array so
    // the change signal fires; in-place mutation would not repaint anything.
    function recordTrace() {
        const sample = {
            "cpu": cpuPercent,
            "memory": memoryPercent,
            "down": networkDown,
            "up": networkUp
        };
        if (trace.length === 0) {
            // Seed a full window so the traces read as a line from the first
            // frame instead of an empty plate that fills in over two minutes.
            const seeded = [];
            for (let index = 0; index < traceDepth; index++)
                seeded.push(sample);
            trace = seeded;
            return;
        }
        const next = trace.slice(Math.max(0, trace.length - traceDepth + 1));
        next.push(sample);
        trace = next;
    }

    function refreshFast() {
        cpuFile.reload();
        memoryFile.reload();
        if (detailActive) {
            networkFile.reload();
            uptimeFile.reload();
            loadFile.reload();
            recordTrace();
        }
    }

    function refreshSlow() {
        if (!slowProcess.running)
            slowProcess.running = true;
    }

    onDetailActiveChanged: {
        if (detailActive) {
            refreshFast();
            refreshSlow();
        } else {
            // Drop the window rather than showing a stale one on reopen.
            trace = [];
        }
    }

    property FileView cpuFile: FileView {
        path: "/proc/stat"
        printErrors: false
        onLoaded: root.applyCpu(text())
    }

    property FileView memoryFile: FileView {
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: root.applyMemory(text())
    }

    property FileView networkFile: FileView {
        path: "/proc/net/dev"
        printErrors: false
        onLoaded: root.applyNetwork(text())
    }

    property FileView uptimeFile: FileView {
        path: "/proc/uptime"
        printErrors: false
        onLoaded: root.uptimeSeconds = Number(text().trim().split(/\s+/)[0] || 0)
    }

    property FileView loadFile: FileView {
        path: "/proc/loadavg"
        printErrors: false
        onLoaded: root.loadAverage = Number(text().trim().split(/\s+/)[0] || 0)
    }

    property Process slowProcess: Process {
        command: ["python3", root.helperPath, "--slow"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applySlowSnapshot(JSON.parse(text));
                } catch (error) {
                    console.warn("[Tonantzintla/System] Slow telemetry decode failed:", error);
                }
            }
        }
    }

    property Timer bootProbe: Timer {
        interval: 400
        running: true
        repeat: false
        onTriggered: root.refreshSlow()
    }

    property Timer fastTimer: Timer {
        interval: root.detailActive ? 2000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshFast()
    }

    property Timer slowTimer: Timer {
        interval: 30000
        running: root.detailActive
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshSlow()
    }
}
