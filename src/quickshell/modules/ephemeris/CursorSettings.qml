import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../.."
import "../../services"
import "../../components"

ColumnLayout {
    id: root
    property var state: ({ themes: [], theme: "", size: 24, editable: false })
    property string message: "Reading installed cursor themes…"
    property string selectedTheme: ""
    property int selectedSize: 24
    property bool hideTyping: false
    property int hideAfter: 0
    property bool showDetails: false
    readonly property bool dirty: selectedTheme !== root.state.theme || selectedSize !== root.state.size
        || hideTyping !== root.state.hideTyping || hideAfter !== root.state.hideAfter
    spacing: 14

    component ChoiceButton: Rectangle {
        id: button
        property string text: ""
        property bool chosen: false
        signal clicked()
        implicitWidth: caption.implicitWidth + 28
        implicitHeight: 38
        radius: Theme.radiusSmall
        color: chosen ? Theme.accent : pointer.containsMouse || activeFocus ? Theme.controlHover : Theme.controlRest
        opacity: enabled ? 1 : 0.45
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: text
        Accessible.onPressAction: if (enabled) clicked()
        Keys.onSpacePressed: clicked()
        Keys.onReturnPressed: clicked()
        Text {
            id: caption
            anchors.centerIn: parent
            text: button.text
            color: button.chosen ? Theme.void_ : Theme.moon
            font.family: Theme.fontMono
            font.pixelSize: 11
        }
        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { button.forceActiveFocus(); button.clicked(); }
        }
    }
    Component.onCompleted: refresh()
    function refresh() {
        if (worker.running) return;
        worker.command = ["python3", Environment.script("cursor-settings.py")];
        worker.running = true;
    }
    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (result.error) { root.message = result.error; return; }
                    root.state = result;
                    root.selectedTheme = result.theme;
                    root.selectedSize = result.size;
                    root.hideTyping = result.hideTyping;
                    root.hideAfter = result.hideAfter;
                    root.message = result.message || "Choose an installed theme. Apply validates and backs up your Niri config.";
                } catch (error) { root.message = "Could not read cursor settings: " + error; }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.message = text.trim() }
    }
    Text { text: "CURSOR"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 22; font.bold: true }
    Text {
        Layout.fillWidth: true
        text: "Installed themes · changes apply to your Niri configuration"
        wrapMode: Text.Wrap
        color: Theme.muted
        font.family: Theme.fontText
        font.pixelSize: 12
    }
    Flow {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: root.state.themes
            ChoiceButton {
                required property string modelData
                text: modelData.replace(/-/g, " ")
                chosen: root.selectedTheme === modelData
                enabled: !worker.running
                onClicked: root.selectedTheme = modelData
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Text { text: "SIZE"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 11 }
        ChoiceButton { text: "−"; Accessible.name: "Decrease cursor size"; enabled: !worker.running && root.selectedSize > 16; onClicked: root.selectedSize = Math.max(16, root.selectedSize - 4) }
        Text { text: root.selectedSize + " px"; color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 14 }
        ChoiceButton { text: "+"; Accessible.name: "Increase cursor size"; enabled: !worker.running && root.selectedSize < 96; onClicked: root.selectedSize = Math.min(96, root.selectedSize + 4) }
        Item { Layout.fillWidth: true }
        ChoiceButton {
            text: worker.running ? "Working…" : "Apply"
            chosen: true
            enabled: !worker.running && root.state.editable && root.dirty && root.state.themes.indexOf(root.selectedTheme) >= 0
            onClicked: {
                worker.command = ["python3", Environment.script("cursor-settings.py"), "apply", root.selectedTheme, String(root.selectedSize), JSON.stringify({hideTyping: root.hideTyping, hideAfter: root.hideAfter})];
                worker.running = true;
            }
        }
        ChoiceButton { text: "Refresh"; enabled: !worker.running; onClicked: root.refresh() }
    }
    SettingToggle {
        Layout.fillWidth: true
        label: "Hide cursor while typing"
        detail: "May interfere with mouse-look in some games"
        checked: root.hideTyping
        enabled: !worker.running && root.state.editable
        onToggled: root.hideTyping = !root.hideTyping
    }
    SettingChoice {
        Layout.fillWidth: true
        label: "Hide when idle"
        value: root.hideAfter
        enabled: !worker.running && root.state.editable
        choices: [{label: "NEVER", value: 0}, {label: "2s", value: 2000}, {label: "5s", value: 5000}, {label: "10s", value: 10000}]
        onSelected: function(value) { root.hideAfter = value; }
    }
    Text { text: root.dirty ? "Unsaved changes · press Apply" : "Matches saved configuration"; color: root.dirty ? Theme.accent : Theme.muted; font.family: Theme.fontText; font.pixelSize: 12 }
    Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: root.message.split("Backup:")[0].trim(); color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11 }
    ChoiceButton { text: root.showDetails ? "Hide details" : "Details"; onClicked: root.showDetails = !root.showDetails }
    Text { Layout.fillWidth: true; visible: root.showDetails; wrapMode: Text.WrapAnywhere; text: root.state.path + "\n" + root.message; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11 }
    Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Install additional Xcursor themes separately, then Refresh. Apply keeps a backup before changing your configuration."; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11 }
}
