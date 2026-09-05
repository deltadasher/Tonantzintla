pragma Singleton

import QtQuick
import Quickshell.Io
import ".."

QtObject {
    id: root

    property string displayResolved: ""
    property string textResolved: ""
    property string monoResolved: ""
    property string iconResolved: ""

    readonly property bool displayOk: classification(Settings.fontDisplay, displayResolved) !== "fallback"
    readonly property bool textOk: classification(Settings.fontText, textResolved) !== "fallback"
    readonly property bool monoOk: classification(Settings.fontMono, monoResolved) !== "fallback"
    readonly property bool iconOk: classification(Settings.fontIcon, iconResolved) !== "fallback"

    readonly property string displayStatus: status(Settings.fontDisplay, displayResolved)
    readonly property string textStatus: status(Settings.fontText, textResolved)
    readonly property string monoStatus: status(Settings.fontMono, monoResolved)
    readonly property string iconStatus: status(Settings.fontIcon, iconResolved)

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
            return "FONTCONFIG OFFLINE";
        if (kind === "fallback")
            return "FALLBACK  //  " + resolved.toUpperCase();
        if (kind === "alias")
            return "SYSTEM ALIAS  //  " + resolved.toUpperCase();
        return "INSTALLED  //  " + resolved.toUpperCase();
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
        triggeredOnStart: true
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
