pragma Singleton

import QtQuick
import Quickshell.Io
import ".."

QtObject {
    id: root

    Component.onCompleted: refreshDelay.restart()

    property string displayResolved: ""
    property string textResolved: ""
    property string monoResolved: ""
    property string iconResolved: ""

    readonly property bool displayOk: classification(Settings.fontDisplay, displayResolved) !== "fallback"
    readonly property bool textOk: classification(Settings.fontText, textResolved) !== "fallback"
    readonly property bool monoOk: classification(Settings.fontMono, monoResolved) !== "fallback"
    readonly property bool iconOk: Theme.iconFontReady || classification(Settings.fontIcon, iconResolved) !== "fallback"

    readonly property string displayStatus: displayProcess.running ? "Checking…" : status(Settings.fontDisplay, displayResolved)
    readonly property string textStatus: textProcess.running ? "Checking…" : status(Settings.fontText, textResolved)
    readonly property string monoStatus: monoProcess.running ? "Checking…" : status(Settings.fontMono, monoResolved)
    readonly property string iconSystemStatus: iconProcess.running ? "Checking…" : status(Settings.fontIcon, iconResolved)
    readonly property string iconStatus: Theme.iconFontReady
        ? "Bundled symbols ready · other glyphs: " + iconSystemStatus
        : Theme.iconFontError ? "Bundled symbols unavailable · " + iconSystemStatus : iconSystemStatus

    function normalized(value) {
        return String(value || "").trim().toLowerCase();
    }

    function classification(requested, resolved) {
        const wanted = normalized(requested);
        const found = normalized(resolved);
        if (!found.length)
            return "offline";
        if (wanted === "sans-serif" || wanted === "serif" || wanted === "monospace")
            return "alias";
        const families = found.split(",");
        for (let index = 0; index < families.length; ++index) {
            if (families[index].trim() === wanted)
                return "installed";
        }
        return "fallback";
    }

    function status(requested, resolved) {
        const kind = classification(requested, resolved);
        if (kind === "offline")
            return "Not verified";
        if (kind === "fallback")
            return "Fallback: " + resolved;
        if (kind === "alias")
            return "System: " + resolved;
        return "Available";
    }

    function launch(process, family) {
        if (process.running)
            return;
        process.command = ["fc-match", "-f", "%{family}", family];
        process.running = true;
    }

    function refresh() {
        launch(displayProcess, Settings.fontDisplay);
        launch(textProcess, Settings.fontText);
        launch(monoProcess, Settings.fontMono);
        launch(iconProcess, Settings.fontIcon);
    }

    property Process displayProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: root.displayResolved = text.trim()
        }
    }
    property Process textProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: root.textResolved = text.trim()
        }
    }
    property Process monoProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: root.monoResolved = text.trim()
        }
    }
    property Process iconProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: root.iconResolved = text.trim()
        }
    }

    property Timer refreshDelay: Timer {
        interval: 180
        onTriggered: root.refresh()
    }

    property Connections settingConnections: Connections {
        target: Settings
        function onFontDisplayChanged() { root.refreshDelay.restart(); }
        function onFontTextChanged() { root.refreshDelay.restart(); }
        function onFontMonoChanged() { root.refreshDelay.restart(); }
        function onFontIconChanged() { root.refreshDelay.restart(); }
    }
}
