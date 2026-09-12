import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property bool enabled: false
    property int seconds: 300
    property string controlPath: ""
    property string executable: "swayidle"
    property string error: ""
    readonly property int effectiveSeconds: Math.max(60, Math.min(3600, seconds))
    readonly property string status: !enabled ? "Automatic locking is off"
        : error.length ? error
        : watcher.running ? "Idle watcher running · requests lock after " + Math.round(effectiveSeconds / 60) + " minutes"
        : "Starting idle watcher…"

    function quoted(value) { return "'" + value.replace(/'/g, "'\\''") + "'"; }
    function restart() {
        retry.stop();
        watcher.running = false;
        if (enabled) retry.restart();
    }
    onEnabledChanged: restart()
    onSecondsChanged: restart()
    onControlPathChanged: restart()
    onExecutableChanged: restart()
    Component.onCompleted: restart()

    // Failed executable launches do not necessarily emit Process.exited.
    property Timer health: Timer {
        interval: 5000
        repeat: true
        running: root.enabled
        onTriggered: {
            if (!watcher.running && !retry.running) {
                root.error = "Idle watcher is unavailable. Check that swayidle is installed.";
                retry.interval = 5000;
                retry.restart();
            }
        }
    }

    property Timer retry: Timer {
        interval: 1000
        onTriggered: {
            if (!root.enabled) return;
            if (watcher.running) { restart(); return; }
            root.error = "";
            if (!root.controlPath.length) { root.error = "Lock command unavailable"; return; }
            watcher.command = [root.executable, "-w", "timeout", String(root.effectiveSeconds),
                "exec " + root.quoted(root.controlPath) + " lock"];
            watcher.running = true;
        }
    }
    property Process watcher: Process {
        onStarted: root.error = ""
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = "Idle lock: " + text.trim();
        }
        onExited: function(code, exitStatus) {
            if (root.enabled) {
                if (code !== 0) root.error = "Idle watcher stopped (" + code + "). Check swayidle and the Wayland session.";
                retry.interval = 5000;
                retry.restart();
            }
        }
    }
}
