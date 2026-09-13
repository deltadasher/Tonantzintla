import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.."
import "../../services"
import "../../components"

ColumnLayout {
    id: root
    property var outputs: []
    property var preview: ({phase: "idle"})
    property string error: ""
    readonly property bool pending: preview.phase === "applying" || preview.phase === "preview"
    spacing: 12
    function refresh() { if (!reader.running) reader.running = true; }
    Component.onCompleted: refresh()
    Timer { interval: 1000; running: root.visible; repeat: true; onTriggered: root.refresh() }
    Process {
        id: reader
        command: ["python3", Environment.script("output-preview.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    root.error = result.error || "";
                    if (!result.error) { root.outputs = result.outputs; root.preview = result.preview; }
                } catch (error) { root.error = "Display information is unavailable."; }
            }
        }
    }
    Text { text: "DISPLAYS"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 22 }
    Text {
        Layout.fillWidth: true; wrapMode: Text.Wrap
        text: "Preview a scale for 15 seconds. Keep confirms it for this session only; your Niri configuration stays untouched."
        color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 12
    }
    Repeater {
        model: root.outputs
        SettingChoice {
            required property var modelData
            Layout.fillWidth: true
            label: modelData.name
            detail: modelData.width + " × " + modelData.height + " logical pixels"
            value: modelData.scale
            enabled: !root.pending && !root.error.length
            choices: [{label: "100%", value: 1}, {label: "125%", value: 1.25},
                {label: "150%", value: 1.5}, {label: "175%", value: 1.75}, {label: "200%", value: 2}]
            onSelected: function(value) {
                if (value === modelData.scale) return;
                root.preview = {phase: "applying"};
                // Independent watchdog survives closing Settings or the shell.
                Quickshell.execDetached(["python3", Environment.script("output-preview.py"),
                    "preview", modelData.name, String(value)]);
            }
        }
    }
    SettingChoice {
        Layout.fillWidth: true
        visible: root.preview.phase === "preview"
        label: "Keep this scale?"
        detail: "Otherwise the watchdog restores it automatically"
        choices: [{label: "KEEP", value: true}]
        onSelected: Quickshell.execDetached(["python3", Environment.script("output-preview.py"), "keep", root.preview.token])
    }
    Text {
        Layout.fillWidth: true; wrapMode: Text.Wrap
        text: root.error || root.preview.message || (root.pending ? "Preview in progress…" : "Current Niri outputs")
        color: root.error.length || root.preview.phase === "failed" ? Theme.warning : Theme.muted
        font.family: Theme.fontText; font.pixelSize: 12
    }
}
