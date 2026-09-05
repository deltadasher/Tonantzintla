pragma Singleton

import QtQuick
import Quickshell.Io
import ".."

QtObject {
    readonly property var counts: adapter.counts

    function count(appId) {
        return Number(adapter.counts[String(appId)] || 0);
    }

    function record(appId) {
        const key = String(appId || "unknown");
        const next = Object.assign({}, adapter.counts);
        next[key] = Number(next[key] || 0) + 1;
        adapter.counts = next;
        saveDelay.restart();
    }

    property Timer saveDelay: Timer {
        interval: 180
        onTriggered: stateFile.writeAdapter()
    }

    property FileView stateFile: FileView {
        path: Settings.configRoot + "/launches.json"
        watchChanges: true
        printErrors: Settings.debug
        onFileChanged: reload()
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound) {
                writeAdapter();
            }
        }
        adapter: JsonAdapter {
            id: adapter
            property var counts: ({})
        }
    }
}
