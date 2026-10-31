pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components/ThemeMode.js" as ThemeMode

QtObject {
    id: root

    property bool ready: false
    property bool busy: false
    readonly property string helperPath: Environment.script("palette-state.py")

    property color void_: "#080910"
    property color mantle: "#10121d"
    property color elevated: "#171a28"
    property color line: "#30354a"
    property color lineBright: "#555d7c"
    property color moon: "#eee9dc"
    property color muted: "#8e94aa"
    property color accent: "#a99cff"
    property color rose: "#ec8eae"
    property color cyan: "#72d9e7"
    property color warning: "#e9b872"
    property color danger: "#ed7d8f"
    property color success: "#77d6ae"

    function colorOf(data, name, fallback, mode) {
        const entry = data && data.colors ? data.colors[name] : null;
        if (!entry)
            return fallback;
        const variant = entry[mode || appliedMode] || entry.default;
        return variant && variant.color ? variant.color : fallback;
    }

    function applyPalette(data, mode) {
        appliedMode = mode;
        void_ = colorOf(data, "surface_container_lowest", void_);
        mantle = colorOf(data, "surface_container_low", mantle);
        elevated = colorOf(data, "surface_container", elevated);
        line = colorOf(data, "outline_variant", line);
        lineBright = colorOf(data, "outline", lineBright);
        moon = colorOf(data, "on_surface", moon);
        muted = colorOf(data, "on_surface_variant", muted);
        accent = colorOf(data, "primary", accent);
        rose = colorOf(data, "tertiary", rose);
        cyan = colorOf(data, "secondary", cyan);
        warning = colorOf(data, mode === "light" ? "tertiary" : "tertiary_fixed_dim", warning);
        danger = colorOf(data, "error", danger);
        success = colorOf(data, mode === "light" ? "secondary" : "secondary_fixed_dim", success);
        ready = true;
    }

    property string sourceColor: ""
    property string error: ""
    property string appliedMode: ""
    property string appliedSeed: ""
    property string appliedSource: ""
    property string jobMode: "dark"
    property string jobOriginalMode: ""
    property string jobOriginalAccent: ""
    property string jobSeed: ""
    property string jobSource: ""
    property string jobOriginalSeed: ""
    property bool jobOriginalAdaptive: false
    property bool committing: false
    property bool started: false
    property bool pending: false
    property string output: ""

    function applyPayload(payload) {
        if (!payload || payload.ok !== true || !payload.palette
                || (payload.mode !== "dark" && payload.mode !== "light")
                || !/^#[0-9a-fA-F]{6}$/.test(colorOf(payload.palette, "primary", "", payload.mode))) {
            error = payload && payload.error ? String(payload.error) : "Invalid Matugen response";
            return false;
        }
        sourceColor = colorOf(payload.palette, "source_color", "", payload.mode);
        applyPalette(payload.palette, payload.mode);
        appliedSeed = payload.seed || "";
        appliedSource = payload.source || "";
        error = "";
        return true;
    }
    function launch(seed, commit) {
        if (busy || paletteProcess.running) return false;
        if (seed && !/^#[0-9a-fA-F]{6}$/.test(seed)) { error = "Use a color in #RRGGBB format."; return false; }
        if (!seed && !Settings.wallpaperPath) { error = "Apply a wallpaper before choosing Automatic."; return false; }
        refreshDelay.stop();
        jobSeed = seed.toLowerCase(); jobSource = Settings.wallpaperPath;
        jobMode = Theme.modeForSeed(jobSeed);
        jobOriginalMode = Settings.themeMode;
        jobOriginalAccent = Settings.spectralColors.accent || "";
        jobOriginalSeed = Settings.paletteSeedColor;
        jobOriginalAdaptive = Settings.adaptivePalette;
        committing = commit; output = ""; started = false; error = ""; busy = true;
        paletteProcess.command = ["python3", helperPath, jobSource, "--seed", jobSeed, "--mode", jobMode];
        paletteProcess.running = true;
        return true;
    }
    function setSeed(seed) { return launch(String(seed || "").trim(), true); }
    function regenerate() {
        if (!Settings.adaptivePalette || !Settings.persistenceReady) return;
        if (busy) { pending = true; return; }
        launch(Settings.paletteSeedColor, false);
    }
    function finish(exitCode) {
        if (!busy) return;
        const current = jobOriginalMode === Settings.themeMode
            && jobOriginalAccent === (Settings.spectralColors.accent || "")
            && jobMode === Theme.modeForSeed(jobSeed)
            && jobSource === Settings.wallpaperPath
            && jobOriginalSeed === Settings.paletteSeedColor
            && jobOriginalAdaptive === Settings.adaptivePalette;
        if (!current) {
            error = "Theme settings changed. Choose the color again.";
            pending = true;
        } else {
            try {
                const payload = JSON.parse(output);
                if (exitCode === 0 && payload.mode === jobMode && payload.source === jobSource && (payload.seed || "") === jobSeed
                        && applyPayload(payload)) {
                    if (jobMode !== Theme.mode) pending = true;
                    if (committing) {
                        Settings.paletteSeedColor = jobSeed;
                        Settings.adaptivePalette = true;
                        refreshDelay.stop();
                    }
                } else error = payload.error || "Matugen could not generate this theme.";
            } catch (exception) { error = "Matugen could not generate this theme."; }
        }
        busy = false; committing = false;
        if (pending) { pending = false; refreshDelay.restart(); }
    }
    function refresh() { refreshDelay.restart(); }

    property Process paletteProcess: Process {
        onStarted: root.started = true
        stdout: StdioCollector { onStreamFinished: root.output = text }
        onExited: function(code, status) { Qt.callLater(function() { root.finish(status === 0 ? code : 1); }); }
        onRunningChanged: if (!running) Qt.callLater(function() {
            if (!paletteProcess.running && !root.started && root.busy) {
                root.finish(1);
                root.error = "Could not start Matugen. Check Python 3 and Matugen are installed.";
            }
        })
    }
    property Process cachedProcess: Process {
        command: ["python3", root.helperPath, "--cached", "--mode", Theme.modeForSeed(Settings.paletteSeedColor)]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.busy || root.ready || !Settings.adaptivePalette) return;
                try {
                    const payload = JSON.parse(text);
                    if (payload.mode === Theme.modeForSeed(Settings.paletteSeedColor)
                            && payload.source === Settings.wallpaperPath
                            && (payload.seed || "") === Settings.paletteSeedColor) root.applyPayload(payload);
                } catch (exception) {}
            }
        }
    }
    property Timer refreshDelay: Timer { interval: 280; onTriggered: root.regenerate() }
    function initialize() {
        if (!Settings.persistenceReady) return;
        if (!cachedProcess.running) cachedProcess.running = true;
        refreshDelay.restart();
    }
    Component.onCompleted: initialize()
    property Connections settingConnections: Connections {
        target: Settings
        function onSpectralColorsChanged() { root.refresh(); }
        function onThemeModeChanged() { root.refresh(); }
        function onAdaptivePaletteChanged() { root.refresh(); }
        function onPaletteSeedColorChanged() { root.refresh(); }
        function onWallpaperPathChanged() { root.refresh(); }
        function onPersistenceReadyChanged() { root.initialize(); }
    }
}
