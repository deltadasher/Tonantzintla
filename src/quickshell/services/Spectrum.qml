pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: root

    property var values: Array(28).fill(0)
    property bool available: false
    property var consumers: []
    readonly property bool requested: consumers.length > 0
    function acquire(owner) {
        if (consumers.indexOf(owner) < 0) consumers = consumers.concat([owner]);
    }
    function release(owner) {
        consumers = consumers.filter(function(item) { return item !== owner; });
    }
    readonly property string configPath: Quickshell.shellDir + "/../../config/cava-raw.conf"

    function consume(frame) {
        const parts = String(frame).trim().split(";");
        if (parts.length < 8)
            return;
        const next = [];
        for (let index = 0; index < 28; index++) {
            const raw = index < parts.length ? Number(parts[index]) : 0;
            next.push(isFinite(raw) ? Math.max(0, Math.min(1, raw / 100)) : 0);
        }
        values = next;
        available = true;
    }

    property Process cavaProcess: Process {
        // Visualization must never compete with PipeWire for scheduling.
        command: ["nice", "-n", "10", "cava", "-p", root.configPath]
        running: root.requested && Media.available && Media.playing
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) { root.consume(data); }
        }
        onRunningChanged: {
            if (!running && (!root.requested || !Media.available)) {
                root.available = false;
                root.values = Array(28).fill(0);
            }
        }
    }
}
