pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// On-demand processes only. Results remain in memory until cleared or replaced.
QtObject {
    id: root
    property string state: "idle"
    property string kind: "ocr"
    property string text: ""
    property string message: "Select an area to read text or inspect a QR code."
    property var values: []
    property var capabilities: ({})
    property string language: ""
    property bool copied: false
    property bool copyBusy: false
    property string _copyText: ""
    property bool _probeStarted: false
    property bool _readerStarted: false
    property bool _copyStarted: false
    readonly property bool busy: state === "selecting" || state === "reading"
    property string _output: ""
    property string _outputName: ""
    property bool _reopen: false
    property bool _cancelled: false
    property var _command: []

    function refresh() {
        if (!probe.running) { _probeStarted = false; probe.running = true; }
    }
    function start(mode, imagePath) {
        if (busy || reader.running || copyBusy || (mode !== "ocr" && mode !== "qr")) return false;
        kind = mode; text = ""; values = []; copied = false; _output = "";
        _cancelled = false; _reopen = !imagePath;
        _outputName = ShellState.ephemerisOutput;
        _command = ["python3", Environment.script("screen-extract.py"), mode];
        if (mode === "ocr" && language) _command.push("--language", language);
        if (imagePath) _command.push("--image", imagePath);
        state = imagePath ? "reading" : "selecting";
        message = imagePath ? "Reading image…" : "Drag to select an area. Escape cancels.";
        if (_reopen) ShellState.closeEphemeris();
        delay.interval = imagePath ? 0 : 350;
        delay.start();
        return true;
    }
    function cancel() {
        _cancelled = true;
        delay.stop();
        if (reader.running) reader.signal(15);
        else finish({state: "cancelled", text: "", message: "Selection cancelled."});
    }
    function clear() {
        if (busy || copyBusy) return;
        state = "idle"; text = ""; values = []; copied = false;
        message = "Select an area to read text or inspect a QR code.";
    }
    function finish(result) {
        deadline.stop();
        if (_cancelled) result = {state: "cancelled", text: "", message: "Selection cancelled."};
        state = ["ready", "empty", "cancelled", "error"].indexOf(result.state) >= 0 ? result.state : "error";
        text = state === "ready" ? String(result.text || "") : "";
        values = state === "ready" && Array.isArray(result.values) ? result.values : [];
        message = String(result.message || (state === "ready"
            ? (kind === "qr" ? "QR contents · inspect before using" : "Text extracted · select or copy below")
            : "Could not read the selected area."));
        if (_reopen && state !== "cancelled") ShellState.openEphemeris("capture", _outputName);
        _reopen = false;
    }
    function copy() {
        if (!text || busy || copyBusy) return;
        copied = false; copyBusy = true; _copyText = text;
        _copyStarted = false;
        copier.stdinEnabled = true;
        copyDeadline.start();
        copier.running = true;
    }
    property Timer delay: Timer {
        onTriggered: { root._readerStarted = false; reader.command = root._command; reader.running = true; deadline.start(); }
    }
    property Timer deadline: Timer {
        interval: 185000
        onTriggered: {
            root._cancelled = false;
            if (reader.running) reader.signal(15);
            root.finish({state: "error", message: "Reading timed out. Try a smaller area."});
        }
    }
    property Timer copyDeadline: Timer {
        interval: 10000
        onTriggered: {
            if (copier.running) copier.signal(15);
            root.copyBusy = false; root.copied = false; root._copyText = "";
            root.message = "Clipboard did not respond. Try copying again.";
        }
    }
    property Process probe: Process {
        command: ["python3", Environment.script("screen-extract.py"), "capabilities"]
        onStarted: root._probeStarted = true
        onRunningChanged: if (!running) Qt.callLater(function() {
            if (!probe.running && !root._probeStarted)
                root.capabilities = {state: "error", message: "Screen-reading tools could not be checked. Check Python 3.", languages: []};
        })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.capabilities = JSON.parse(text);
                    if (!root.language || root.capabilities.languages.indexOf(root.language) < 0)
                        root.language = root.capabilities.defaultLanguage || "";
                } catch (error) {
                    root.capabilities = {state: "error", message: "Screen-reading tools could not be checked.", languages: []};
                }
            }
        }
    }
    property Process reader: Process {
        onStarted: root._readerStarted = true
        onRunningChanged: if (!running) Qt.callLater(function() {
            if (!reader.running && !root._readerStarted && root.busy)
                root.finish({state: "error", message: "Screen reading could not start. Check that Python 3 is installed."});
        })
        stdout: StdioCollector { onStreamFinished: root._output = text }
        onExited: (exitCode, exitStatus) => Qt.callLater(function() {
            if (!root.busy) return;
            try { root.finish(JSON.parse(root._output)); }
            catch (error) { root.finish({state: "error", message: "Screen reading could not finish. Check that Python 3 is installed."}); }
        })
    }
    property Process copier: Process {
        command: ["wl-copy", "--type", "text/plain;charset=utf-8"]
        onStarted: { root._copyStarted = true; write(root._copyText); stdinEnabled = false; }
        onRunningChanged: if (!running) Qt.callLater(function() {
            if (!copier.running && !root._copyStarted && root.copyBusy) {
                copyDeadline.stop(); root.copyBusy = false; root._copyText = "";
                root.message = "Could not copy. Check that wl-copy is installed.";
            }
        })
        onExited: (exitCode, exitStatus) => {
            copyDeadline.stop();
            root.copyBusy = false;
            root._copyText = "";
            root.copied = exitCode === 0 && exitStatus === 0;
            if (!root.copied) root.message = "Could not copy. Check that wl-copy is installed.";
        }
    }
}
