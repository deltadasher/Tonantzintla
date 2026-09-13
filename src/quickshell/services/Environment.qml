pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: root

    // Single source of truth for the version the shell reports. Keep this in
    // step with the newest heading in CHANGELOG.md.
    readonly property string version: "1.0.0"

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
    property bool wallpaperBusy: false
    property bool wallpaperRestored: false
    property bool onlineBusy: false
    property bool libraryLoading: true
    property string libraryError: ""
    property bool libraryRefreshPending: false
    property string wallpaperMessage: ""
    property bool wallpaperMessageError: false
    readonly property bool libraryOperationBusy: libraryOperation.running
    property var localWallpapers: []
    property var onlineWallpapers: []
    readonly property var wallpapers: (localWallpapers.length > 0
        ? localWallpapers : bundledEntries()).concat(onlineWallpapers)
    readonly property bool captureActive: ShellState.ephemerisVisible
        && ShellState.ephemerisTab === "capture"
    readonly property var outputNames: {
        const names = [];
        for (const screen of Quickshell.screens) {
            if (screen && screen.name && names.indexOf(screen.name) < 0)
                names.push(screen.name);
        }
        for (const workspace of Compositor.workspaces) {
            if (workspace.output && names.indexOf(workspace.output) < 0)
                names.push(workspace.output);
        }
        return names;
    }

    function pathFromUrl(url) {
        const value = url.toString();
        return value.indexOf("file://") === 0 ? decodeURIComponent(value.substring(7)) : value;
    }

    // Internal executables the shell spawns. They are not user commands, so
    // they live outside the single blackhole entry point.
    readonly property string helperRoot: Quickshell.shellDir + "/../libexec"
    readonly property string controlPath: Quickshell.shellDir + "/../../bin/blackhole"

    function script(name) {
        return helperRoot + "/" + name;
    }

    readonly property string bundledRoot: Quickshell.shellDir + "/../assets/wallpapers"
    readonly property var bundledWallpapers: [
        bundledRoot + "/astral-observatory.png",
        bundledRoot + "/aurora-tide.png",
        bundledRoot + "/ringfall-survey.png",
        bundledRoot + "/umbra-array.png",
        bundledRoot + "/violet-eclipse.png",
        bundledRoot + "/orbital-cartography.png"
    ]
    readonly property string snippingTool: script("snipping-tool")
    readonly property string libraryHelper: script("wallpaper-library.py")
    readonly property string onlineHelper: script("wallpaper-online.py")
    readonly property string applyHelper: script("wallpaper-apply")
    readonly property string wallpaperLibraryPath: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property bool canCaptureRegion: hasGrim && hasSlurp && hasWlCopy
    readonly property bool canCaptureScreen: hasGrim
    readonly property bool canEditCapture: hasGrim && hasSlurp && hasWlCopy && hasSatty
    readonly property bool canRecord: hasRecorder
    readonly property string screenshotStatus: canCaptureRegion
        ? "READY" : "INSTALL GRIM + SLURP + WL-COPY"
    readonly property bool canSetWallpaper: hasAwww || hasSwaybg || hasSwww || hasMpvpaper
    readonly property string wallpaperStatus: wallpaperBusy ? "APPLYING WALLPAPER"
        : hasAwww && hasMpvpaper ? "AWWW + MPVPAPER ONLINE"
        : hasAwww ? "AWWW TRANSITIONS ONLINE" : hasSwaybg
            ? "SWAYBG ONLINE" : hasSwww ? "SWWW ONLINE" : "NO BACKEND"

    function kindFor(path) {
        return /\.(mp4|mkv|mov|webm|avi|m4v)$/i.test(path || "") ? "video" : "image";
    }

    function bundledEntries() {
        return bundledWallpapers.map(function(path) {
            const name = path.split("/").pop();
            return {
                "path": path,
                "preview": path,
                "name": name,
                "kind": kindFor(path),
                "source": "Tonantzintla",
                "color": "",
                "bucket": "Unsorted",
                "remoteUrl": ""
            };
        });
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

    function launchTerminal() {
        Quickshell.execDetached([controlPath, "terminal"]);
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

    function openWallpaperLibrary() {
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p -- \"$1\" && exec \"$2\" files \"$1\"",
            "blackhole", wallpaperLibraryPath, controlPath]);
    }

    function wallpaperFeedback(message, failed) {
        wallpaperMessage = message;
        wallpaperMessageError = !!failed;
    }

    function importWallpapers(urls) {
        if (libraryOperation.running) return;
        const files = [];
        for (const url of urls) files.push(String(url));
        if (!files.length) return;
        wallpaperFeedback("Importing " + files.length + " file(s)…", false);
        libraryOperation.command = ["python3", libraryHelper, "--import-json", JSON.stringify(files)];
        libraryOperation.running = true;
    }

    function toggleWallpaperFavorite(entry) {
        if (!entry || libraryOperation.running) return;
        if (entry.remoteUrl) {
            wallpaperFeedback("Apply the online wallpaper to download it before saving a favorite.", false);
            return;
        }
        libraryOperation.command = ["python3", libraryHelper, "--favorite", entry.path,
            "--enabled", entry.favorite ? "false" : "true"];
        libraryOperation.running = true;
    }

    function applyWallpaper(path, kind) {
        if (!path || !canSetWallpaper) {
            wallpaperFeedback("No wallpaper backend is available. Install awww or swaybg.", true);
            return;
        }
        const resolvedKind = kind || kindFor(path);
        if (resolvedKind === "video" && !hasMpvpaper) {
            wallpaperFeedback("Install mpvpaper to apply a video wallpaper.", true);
            console.warn("[Tonantzintla/Wallpaper] mpvpaper is required for video wallpaper");
            return;
        }
        wallpaperBusy = true;
        wallpaperFeedback("Applying to " + (Settings.wallpaperOutputs === "all" ? "all displays" : Settings.wallpaperOutputs) + "…", false);
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
        if (libraryProcess.running) {
            libraryRefreshPending = true;
            return;
        }
        if (!libraryProcess.running) {
            libraryLoading = true;
            libraryError = "";
            libraryProcess.running = true;
        }
    }

    function searchOnline(query) {
        const cleaned = String(query || "").trim();
        if (!cleaned.length || onlineSearchProcess.running)
            return;
        onlineBusy = true;
        onlineWallpapers = [];
        onlineSearchProcess.command = ["python3", onlineHelper, "search", cleaned];
        onlineSearchProcess.running = true;
    }

    function downloadOnline(entry) {
        if (!entry || !entry.remoteUrl || onlineDownloadProcess.running)
            return;
        wallpaperBusy = true;
        onlineDownloadProcess.command = ["python3", onlineHelper, "download", entry.remoteUrl];
        onlineDownloadProcess.running = true;
    }

    property Process wallpaperBackend: Process {}

    property Process applyProcess: Process {
        onExited: (exitCode, exitStatus) => root.wallpaperFeedback(
            exitCode === 0 ? "Wallpaper applied." : "Wallpaper could not be applied. Check the selected display and backend.",
            exitCode !== 0)
        onRunningChanged: {
            if (!running) {
                root.wallpaperBusy = false;
                AdaptivePalette.refresh();
            }
        }
    }

    property Process libraryOperation: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text);
                    if (payload.action === "import") {
                        const count = (payload.imported || []).length;
                        const errors = payload.errors || [];
                        root.wallpaperFeedback(count + " file(s) ready in the library."
                            + (errors.length ? " " + errors.length + " failed: " + errors[0].error : ""), errors.length > 0);
                        if (count) root.refreshWallpapers();
                    } else if (payload.ok && payload.action === "favorite") {
                        root.localWallpapers = root.localWallpapers.map(function(entry) {
                            if (entry.path !== payload.path) return entry;
                            return Object.assign({}, entry, {favorite: payload.favorite});
                        });
                        root.wallpaperFeedback(payload.favorite ? "Saved to favorites." : "Removed from favorites.", false);
                    } else {
                        root.wallpaperFeedback(payload.error || "Library action failed.", true);
                    }
                } catch (error) {
                    root.wallpaperFeedback("Library action failed: " + String(error), true);
                }
            }
        }
    }

    property Process libraryProcess: Process {
        command: ["python3", root.libraryHelper, "--bundled-root", root.bundledRoot]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text);
                    if (!Array.isArray(payload))
                        throw new Error(payload.error || "Wallpaper index was not an array");
                    root.localWallpapers = payload;
                    root.libraryError = "";
                } catch (error) {
                    root.libraryError = String(error);
                    console.warn("[Tonantzintla/Wallpaper] Wallpaper index decode failed:", error);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0) {
                    root.libraryError = message.split("\n").pop();
                    console.warn("[Tonantzintla/Wallpaper] Wallpaper index failed:", message);
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                root.libraryLoading = false;
                if (root.libraryRefreshPending) {
                    root.libraryRefreshPending = false;
                    Qt.callLater(root.refreshWallpapers);
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
                        console.warn("[Tonantzintla/Wallpaper]", payload.error || "Online search failed");
                } catch (error) {
                    console.warn("[Tonantzintla/Wallpaper] Online search returned invalid data:", error);
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
                        console.warn("[Tonantzintla/Wallpaper]", payload.error || "Wallpaper download failed");
                    }
                } catch (error) {
                    root.wallpaperBusy = false;
                    console.warn("[Tonantzintla/Wallpaper] Wallpaper download returned invalid data:", error);
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
            "for c in grim slurp wl-copy satty gpu-screen-recorder swaybg swww awww awww-daemon mpvpaper; do command -v \"$c\" >/dev/null 2>&1 && printf '%s=1\\n' \"$c\" || printf '%s=0\\n' \"$c\"; done"]
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
                root.restoreWallpaper();
            }
        }
    }
}
