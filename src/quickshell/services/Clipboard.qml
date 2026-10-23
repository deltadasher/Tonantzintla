pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: root

    property bool available: false
    property bool loading: false
    property var historyEntries: []
    property var pins: []
    readonly property var entries: pins.concat(historyEntries)
    property string status: ""
    signal copied(string identifier)
    readonly property bool busy: actionProcess.running
    readonly property bool paused: Settings.clipboardPaused
    readonly property string actionHelper: Environment.script("clipboard-actions.py")
    readonly property string pinPath: (Quickshell.env("XDG_STATE_HOME") || ((Quickshell.env("HOME") || "/tmp")+"/.local/state"))+"/tonantzintla/clipboard-pins"
    function action(verb, identifier, kind) {
        if(actionProcess.running) { status="Wait for the current clipboard action."; return; }
        actionProcess.command=["python3",actionHelper,verb,pinPath,identifier || "","--kind",kind || "text"];
        actionProcess.running=true;
        status=verb==="list" ? "" : "Working…";
    }
    function togglePin(entry) { if(entry) action(entry.pinned?"unpin":"pin",String(entry.id),entry.type); }
    function remove(entry) { if(entry) action("delete",String(entry.id),entry.type); }
    function togglePaused() { Settings.clipboardPaused=!Settings.clipboardPaused; }
    onPausedChanged: status=paused ? "Shell-owned watchers paused. External clipboard managers may still record." : "Shell-owned clipboard watchers resumed."
    readonly property bool historyActive: ShellState.ephemerisVisible
        && ShellState.ephemerisTab === "clipboard"
    readonly property string helperPath: Environment.script("clipboard-index.py")
    readonly property string cachePath: {
        const xdg = Quickshell.env("XDG_CACHE_HOME") || "";
        const home = Quickshell.env("HOME") || "/tmp";
        return (xdg.length > 0 ? xdg : home + "/.cache")
            + "/tonantzintla/clipboard";
    }

    function refresh() {
        if (!available || fetchProcess.running)
            return;
        loading = true;
        fetchProcess.running = true;
        action("list", "", "text");
    }

    function copy(entryId) { action("copy",String(entryId),"text"); }

    function setText(text) {
        Quickshell.execDetached(["sh", "-c",
            "printf %s \"$1\" | wl-copy", "tonantzintla", String(text)]);
    }

    // Durable pins live independently of the cliphist database.
    function clear() { if(available) action("clear","","text"); }

    property Process probeProcess: Process {
        command: ["sh", "-c", "command -v cliphist >/dev/null && command -v wl-paste >/dev/null && command -v wl-copy >/dev/null && printf READY || printf MISSING"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text === "READY";
                if (root.available && root.historyActive)
                    root.refresh();
            }
        }
    }

    property Process textWatcher: Process {
        command: ["wl-paste", "--type", "text", "--watch", "cliphist", "store"]
        running: root.available && !root.paused
    }

    property Process imageWatcher: Process {
        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"]
        running: root.available && !root.paused
    }

    property Process fetchProcess: Process {
        command: ["python3", root.helperPath, root.cachePath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.historyEntries = JSON.parse(text.length > 0 ? text : "[]").slice(0,120);
                } catch (error) {
                    root.historyEntries = [];
                }
                root.loading = false;
            }
        }
    }

    property Process actionProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result=JSON.parse(text);
                    if(result.ok) {
                        root.pins=(result.pins || []).slice(0,24);
                        root.status=actionProcess.command[2]==="list" ? root.status : "Clipboard updated.";
                        if(actionProcess.command[2]==="copy") root.copied(String(actionProcess.command[4]));
                        else if(actionProcess.command[2]!=="list") root.refreshDelay.restart();
                    } else root.status=result.error || "Clipboard action failed.";
                } catch(error) { root.status="Could not complete clipboard action."; }
            }
        }
    }

    property Timer refreshDelay: Timer {
        interval: 180
        onTriggered: root.refresh()
    }

    property Timer refreshTimer: Timer {
        interval: 2200
        running: root.available && root.historyActive
        repeat: true
        onTriggered: root.refresh()
    }

    onHistoryActiveChanged: if (historyActive) refresh()
}
