pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "services"

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

    function colorOf(data, name, fallback) {
        const entry = data && data.colors ? data.colors[name] : null;
        if (!entry)
            return fallback;
        const variant = entry.default || entry.dark;
        return variant && variant.color ? variant.color : fallback;
    }

    function applyPalette(data) {
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
        warning = colorOf(data, "tertiary_fixed_dim", warning);
        danger = colorOf(data, "error", danger);
        success = colorOf(data, "secondary_fixed_dim", success);
        ready = true;
    }

    function applyPayload(payload) {
        if (!payload || payload.ok !== true || !payload.palette) {
            ready = false;
            console.warn("[Tonantzintla/Palette]", payload && payload.error
                ? String(payload.error) : "Invalid Matugen response");
            return;
        }
        applyPalette(payload.palette);
    }

    function regenerate() {
        if (!Settings.adaptivePalette) {
            return;
        }
        if (!Settings.wallpaperPath || paletteProcess.running)
            return;
        busy = true;
        paletteProcess.command = ["python3", helperPath, Settings.wallpaperPath];
        paletteProcess.running = true;
    }

    function refresh() {
        refreshDelay.restart();
    }

    property Process paletteProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyPayload(JSON.parse(text));
                } catch (error) {
                    root.ready = false;
                    console.warn("[Tonantzintla/Palette] Matugen decode failed:", error);
                }
            }
        }
        onRunningChanged: {
            if (!running)
                root.busy = false;
        }
    }

    property Process cachedProcess: Process {
        command: ["python3", root.helperPath, "--cached"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text);
                    if (payload.ok === true)
                        root.applyPayload(payload);
                } catch (error) {
                    // A missing first-run cache is expected and not an error.
                }
            }
        }
    }

    property Timer refreshDelay: Timer {
        interval: 280
        onTriggered: root.regenerate()
    }

    property Connections settingConnections: Connections {
        target: Settings
        function onAdaptivePaletteChanged() { root.refreshDelay.restart(); }
        function onWallpaperPathChanged() { root.refreshDelay.restart(); }
        function onPersistenceReadyChanged() {
            if (Settings.persistenceReady)
                root.refreshDelay.restart();
        }
    }
}
