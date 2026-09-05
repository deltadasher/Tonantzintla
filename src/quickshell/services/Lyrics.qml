pragma Singleton

import QtQuick
import Quickshell.Io
import ".."

QtObject {
    id: root

    property string status: "idle"
    property string source: ""
    property string plainText: ""
    property string syncedText: ""
    property var lines: []
    property bool instrumental: false
    property bool busy: false
    property string error: ""
    property string requestedKey: ""
    readonly property bool requested: ShellState.ephemerisVisible
        && ShellState.ephemerisTab === "media"
    readonly property bool available: lines.length > 0
    readonly property bool hasTiming: lines.length > 0 && lines[0].time >= 0
    readonly property string trackKey: Media.available
        ? [Media.title, Media.artist, Media.album, Math.round(Media.length)].join("\u001f") : ""
    readonly property int currentIndex: {
        if (!hasTiming)
            return -1;
        let active = -1;
        for (let index = 0; index < lines.length; index++) {
            if (lines[index].time <= Media.position + 0.16)
                active = index;
            else
                break;
        }
        return active;
    }
    readonly property string helperPath: Environment.script("lyrics-state.py")

    function plainLines(text) {
        return String(text || "").split(/\r?\n/).filter(function(line) {
            return line.trim().length > 0;
        }).map(function(line) { return { "time": -1, "text": line.trim() }; });
    }

    function syncedLines(text) {
        const parsed = [];
        String(text || "").split(/\r?\n/).forEach(function(line) {
            const matches = [];
            const timestampPattern = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
            let match = timestampPattern.exec(line);
            while (match !== null) {
                matches.push(match);
                match = timestampPattern.exec(line);
            }
            const lyric = line.replace(/(?:\[\d+:\d+(?:\.\d+)?\])+/g, "").trim();
            matches.forEach(function(match) {
                parsed.push({ "time": Number(match[1]) * 60 + Number(match[2]),
                    "text": lyric.length > 0 ? lyric : "···" });
            });
        });
        parsed.sort(function(left, right) { return left.time - right.time; });
        return parsed;
    }

    function applyPayload(payload) {
        status = payload.status || "missing";
        source = payload.source || "";
        plainText = payload.plain || "";
        syncedText = payload.synced || "";
        instrumental = payload.instrumental === true;
        error = payload.error || "";
        const timed = syncedLines(syncedText);
        lines = timed.length > 0 ? timed : plainLines(plainText);
        busy = false;
    }

    function clear(nextStatus) {
        status = nextStatus || "idle";
        source = "";
        plainText = "";
        syncedText = "";
        lines = [];
        instrumental = false;
        error = "";
        busy = false;
    }

    function refresh(forceOnline) {
        if (!Media.available) {
            clear("idle");
            return;
        }
        requestedKey = trackKey;
        if (Media.embeddedLyrics.length > 0 && !forceOnline) {
            const embedded = Media.embeddedLyrics;
            applyPayload({ "status": "ready", "source": "EMBEDDED MPRIS",
                "plain": embedded, "synced": embedded.indexOf("[") === 0 ? embedded : "" });
            return;
        }
        clear("loading");
        busy = true;
        const command = ["python3", helperPath,
            "--title", Media.title, "--artist", Media.artist,
            "--album", Media.album, "--duration", String(Math.round(Media.length))];
        if (forceOnline)
            command.push("--refresh");
        fetchProcess.command = command;
        fetchProcess.running = true;
    }

    onTrackKeyChanged: if (requested) requestTimer.restart()
    onRequestedChanged: if (requested) requestTimer.restart()

    property Timer requestTimer: Timer {
        interval: 520
        onTriggered: root.refresh(false)
    }

    property Process fetchProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.requestedKey !== root.trackKey)
                    return;
                try {
                    root.applyPayload(JSON.parse(text));
                } catch (decodeError) {
                    root.applyPayload({ "status": "error", "source": "LOCAL",
                        "error": String(decodeError) });
                }
            }
        }
        onRunningChanged: {
            if (!running && root.status === "loading")
                root.busy = false;
        }
    }
}
