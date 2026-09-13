pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import ".."

QtObject {
    id: root
    readonly property var counts: adapter.counts
    readonly property var favorites: adapter.favorites

    function isFavorite(appId) {
        return adapter.favorites.indexOf(String(appId)) >= 0;
    }

    function toggleFavorite(appId) {
        const key = String(appId || "");
        if (!key)
            return;
        const next = adapter.favorites.slice();
        const index = next.indexOf(key);
        if (index < 0)
            next.push(key);
        else
            next.splice(index, 1);
        adapter.favorites = next;
        saveDelay.restart();
    }

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
        onTriggered: root.stateFile.writeAdapter()
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
            property var favorites: []
        }
    }
}
