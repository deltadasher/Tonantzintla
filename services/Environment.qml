pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: root

    property bool ready: false
    property bool hasGrim: false
    property bool hasSlurp: false
    property bool hasWlCopy: false
    property bool hasSatty: false
    property bool hasRecorder: false
    property bool recording: false
    property bool recordRefreshPending: false
    property bool hasSwaybg: false
    property bool hasSwww: false
    property bool hasAwww: false
    property bool hasMpvpaper: false
    property bool hasMatugen: false
    property bool wallpaperBusy: false
    property bool wallpaperRestored: false
    property bool onlineBusy: false
    property string onlineError: ""
    property string onlineQuery: ""
    property var localWallpapers: []
    property var onlineWallpapers: []
    readonly property var wallpapers: localWallpapers.concat(onlineWallpapers)
    readonly property bool captureActive: ShellState.ephemerisVisible
        && ShellState.ephemerisTab === "capture"
    readonly property string activeWallpaper: Settings.wallpaperPath
    readonly property var outputNames: {
        const names = [];
        for (const screen of Quickshell.screens) {
            if (screen && screen.name && names.indexOf(screen.name) < 0)
                names.push(screen.name);
        }
        for (const workspace of Niri.workspaces) {
            if (workspace.output && names.indexOf(workspace.output) < 0)
                names.push(workspace.output);
        }
        return names;
    }

    function pathFromUrl(url) {
        const value = url.toString();
        return value.indexOf("file://") === 0 ? decodeURIComponent(value.substring(7)) : value;
    }

    readonly property string scriptsRoot: pathFromUrl(Qt.resolvedUrl("../scripts"))

    function script(name) {
        return scriptsRoot + "/" + name;
    }

    readonly property string bundledRoot: pathFromUrl(Qt.resolvedUrl("../assets/wallpapers"))
    readonly property var bundledWallpapers: [
        pathFromUrl(Qt.resolvedUrl("../assets/wallpapers/astral-observatory.png")),
        pathFromUrl(Qt.resolvedUrl("../assets/wallpapers/aurora-tide.png")),
        pathFromUrl(Qt.resolvedUrl("../assets/wallpapers/ringfall-survey.png")),
        pathFromUrl(Qt.resolvedUrl("../assets/wallpapers/umbra-array.png")),
        pathFromUrl(Qt.resolvedUrl("../assets/wallpapers/violet-eclipse.png")),
        pathFromUrl(Qt.resolvedUrl("../assets/wallpapers/orbital-cartography.png"))
    ]
    readonly property string snippingTool: script("snipping-tool")
    readonly property string libraryHelper: script("wallpaper-library.py")
    readonly property string onlineHelper: script("wallpaper-online.py")
    readonly property string applyHelper: script("wallpaper-apply")
    readonly property bool canCaptureRegion: hasGrim && hasSlurp && hasWlCopy
    readonly property bool canCaptureScreen: hasGrim
    readonly property bool canEditCapture: hasGrim && hasSlurp && hasWlCopy && hasSatty
    readonly property bool canRecord: hasRecorder
    readonly property string screenshotStatus: canCaptureRegion
        ? "OPTICS CLIPBOARD ONLINE" : "INSTALL GRIM + SLURP + WL-COPY"
    readonly property bool canSetWallpaper: hasAwww || hasSwaybg || hasSwww || hasMpvpaper
    readonly property string wallpaperStatus: wallpaperBusy ? "SYNCHRONIZING WORLD"
        : hasAwww && hasMpvpaper ? "AWWW + MPVPAPER ONLINE"
        : hasAwww ? "AWWW TRANSITIONS ONLINE" : hasSwaybg
            ? "SWAYBG ONLINE" : hasSwww ? "SWWW ONLINE" : "NO BACKEND"

    function kindFor(path) {
        return /\.(mp4|mkv|mov|webm|avi|m4v)$/i.test(path || "") ? "video" : "image";
    }

    function outputsSelected(name) {
        if (Settings.wallpaperOutputs === "all")
            return true;
        return Settings.wallpaperOutputs.split(",").indexOf(name) >= 0;
    }

    function selectAllOutputs() {
        Settings.wallpaperOutputs = "all";
    }

    function toggleOutput(name) {
        if (!name)
            return;
        let selected = Settings.wallpaperOutputs === "all"
            ? outputNames.slice() : Settings.wallpaperOutputs.split(",").filter(Boolean);
        const index = selected.indexOf(name);
        if (index >= 0) {
            if (selected.length > 1)
                selected.splice(index, 1);
        } else {
            selected.push(name);
        }
        Settings.wallpaperOutputs = selected.length === outputNames.length ? "all" : selected.join(",");
    }

    function captureRegion(action) {
        if (canCaptureRegion)
            Quickshell.execDetached([snippingTool, "--region-" + (action || "copy")]);
    }

    function captureScreen(action) {
        if (!canCaptureScreen)
            return;
        Quickshell.execDetached([snippingTool, "--full-" + (action || "save")]);
    }

    function startRecording() {
        if (!canRecord || recording)
            return;
        Quickshell.execDetached([snippingTool, "--record-start"]);
        recordRefresh.restart();
    }

    function stopRecording() {
        if (!canRecord || !recording)
            return;
        Quickshell.execDetached([snippingTool, "--record-stop"]);
        recordRefresh.restart();
    }

    function refreshRecordingState() {
        if (recordStatusProcess.running) {
            recordRefreshPending = true;
            return;
        }
        recordStatusProcess.running = true;
    }

    function openCaptureFolder() {
        Quickshell.execDetached([snippingTool, "--open-captures"]);
    }

    function openRecordingFolder() {
        Quickshell.execDetached([snippingTool, "--open-recordings"]);
    }

    function applyWallpaper(path, kind) {
        if (!path || !canSetWallpaper)
            return;
        const resolvedKind = kind || kindFor(path);
        if (resolvedKind === "video" && !hasMpvpaper) {
            onlineError = "mpvpaper is required for video wallpaper";
            return;
        }
        wallpaperBusy = true;
        if (resolvedKind === "video" || hasAwww) {
            applyProcess.command = ["bash", applyHelper, resolvedKind, path,
                Settings.wallpaperOutputs, Settings.wallpaperTransition];
            applyProcess.running = true;
        } else if (hasSwaybg) {
            wallpaperBackend.command = ["swaybg", "-m", "fill", "-i", path];
            wallpaperBackend.running = true;
            wallpaperBusy = false;
        } else if (hasSwww) {
            Quickshell.execDetached(["swww", "img", path, "--transition-type",
                Settings.wallpaperTransition, "--transition-duration", "0.8"]);
            wallpaperBusy = false;
        }
        Settings.wallpaperPath = path;
        Settings.wallpaperKind = resolvedKind;
    }

    function setWallpaper(entry) {
        if (!entry)
            return;
        if (typeof entry === "string") {
            applyWallpaper(entry, kindFor(entry));
            return;
        }
        if (entry.remoteUrl && entry.remoteUrl.length) {
            downloadOnline(entry);
            return;
        }
        applyWallpaper(entry.path, entry.kind);
    }

    function restoreWallpaper() {
        if (!canSetWallpaper || wallpaperRestored)
            return;
        const selected = Settings.wallpaperPath.length > 0
            ? Settings.wallpaperPath : bundledWallpapers[0];
        wallpaperRestored = true;
        applyWallpaper(selected, Settings.wallpaperKind || kindFor(selected));
    }

    function refreshWallpapers() {
        if (!libraryProcess.running)
            libraryProcess.running = true;
    }

    function searchOnline(query) {
        const cleaned = String(query || "").trim();
        if (!cleaned.length || onlineSearchProcess.running)
            return;
        onlineQuery = cleaned;
        onlineBusy = true;
        onlineError = "";
        onlineWallpapers = [];
        onlineSearchProcess.command = ["python3", onlineHelper, "search", cleaned];
        onlineSearchProcess.running = true;
    }

    function clearOnline() {
        onlineWallpapers = [];
        onlineQuery = "";
        onlineError = "";
    }

    function downloadOnline(entry) {
        if (!entry || !entry.remoteUrl || onlineDownloadProcess.running)
            return;
        wallpaperBusy = true;
        onlineError = "";
        onlineDownloadProcess.command = ["python3", onlineHelper, "download", entry.remoteUrl];
        onlineDownloadProcess.running = true;
    }

    property Process wallpaperBackend: Process {}

    property Process applyProcess: Process {
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length) root.onlineError = text.trim()
        }
        onRunningChanged: {
            if (!running) {
                root.wallpaperBusy = false;
                AdaptivePalette.refresh();
            }
        }
    }

    property Process libraryProcess: Process {
        command: ["python3", root.libraryHelper, "--bundled-root", root.bundledRoot]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.localWallpapers = JSON.parse(text);
                } catch (error) {
                    root.onlineError = "Wallpaper index decode failed";
                }
            }
        }
    }

    property Process onlineSearchProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text);
                    if (Array.isArray(payload))
                        root.onlineWallpapers = payload;
                    else
                        root.onlineError = payload.error || "Online search failed";
                } catch (error) {
                    root.onlineError = "Online search returned invalid data";
                }
            }
        }
        onRunningChanged: if (!running) root.onlineBusy = false
    }

    property Process onlineDownloadProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text);
                    if (payload.ok === true && payload.path) {
                        root.applyWallpaper(payload.path, payload.kind || "image");
                        root.refreshWallpapers();
                    } else {
                        root.wallpaperBusy = false;
                        root.onlineError = payload.error || "Wallpaper download failed";
                    }
                } catch (error) {
                    root.wallpaperBusy = false;
                    root.onlineError = "Wallpaper download returned invalid data";
                }
            }
        }
    }

    property Connections settingsConnection: Connections {
        target: Settings
        function onPersistenceReadyChanged() {
            if (Settings.persistenceReady)
                root.restoreWallpaper();
        }
    }

    property Timer initialRestore: Timer {
        interval: 750
        running: true
        onTriggered: root.restoreWallpaper()
    }

    property Timer recordPoll: Timer {
        interval: root.recording ? 1000 : 2500
        running: root.recording || root.captureActive
        repeat: true
        onTriggered: root.refreshRecordingState()
    }

    property Timer recordRefresh: Timer {
        interval: 450
        onTriggered: root.refreshRecordingState()
    }

    property Process recordStatusProcess: Process {
        command: [root.snippingTool, "--record-status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.recording = text.trim() === "recording"
        }
        onRunningChanged: {
            if (!running && root.recordRefreshPending) {
                root.recordRefreshPending = false;
                root.recordRefresh.restart();
            }
        }
    }

    onCaptureActiveChanged: if (captureActive) recordRefresh.restart()

    property Process probeProcess: Process {
        command: ["sh", "-c",
            "for c in grim slurp wl-copy satty gpu-screen-recorder swaybg swww awww awww-daemon mpvpaper matugen; do command -v \"$c\" >/dev/null 2>&1 && printf '%s=1\\n' \"$c\" || printf '%s=0\\n' \"$c\"; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasGrim = text.indexOf("grim=1") >= 0;
                root.hasSlurp = text.indexOf("slurp=1") >= 0;
                root.hasWlCopy = text.indexOf("wl-copy=1") >= 0;
                root.hasSatty = text.indexOf("satty=1") >= 0;
                root.hasRecorder = text.indexOf("gpu-screen-recorder=1") >= 0;
                root.hasSwaybg = text.indexOf("swaybg=1") >= 0;
                root.hasSwww = text.indexOf("swww=1") >= 0;
                root.hasAwww = text.indexOf("awww=1") >= 0 && text.indexOf("awww-daemon=1") >= 0;
                root.hasMpvpaper = text.indexOf("mpvpaper=1") >= 0;
                root.hasMatugen = text.indexOf("matugen=1") >= 0;
                root.ready = true;
                root.restoreWallpaper();
            }
        }
    }
}
