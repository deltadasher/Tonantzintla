import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../components"
import "../../components/DockModel.js" as DockModel

ColumnLayout {
    id: root
    property string outputName: ""
    property string page: "apps"
    property string query: ""
    property string editingPin: ""
    signal closeRequested()
    Keys.onEscapePressed: root.closeRequested()
    readonly property var pins: DockModel.pins(Settings.dockPins)
    readonly property var applications: DesktopEntries.applications.values.slice().filter(function(app) {
        return app.name && app.id && app.command && !/^about(?:\s|$)/i.test(app.name)
            && app.name.toLowerCase().indexOf(root.query.toLowerCase()) >= 0;
    }).sort(function(a, b) { return a.name.localeCompare(b.name); })
    spacing: 16

    function appFor(id) {
        return DesktopEntries.applications.values.find(app => DockModel.key(app.id) === DockModel.key(id));
    }
    function isPinned(id) { return pins.some(p => DockModel.key(p) === DockModel.key(id)); }
    function togglePin(id) {
        const next = pins.slice();
        const index = next.findIndex(p => DockModel.key(p) === DockModel.key(id));
        if (index >= 0) next.splice(index, 1); else next.push(id);
        Settings.dockPins = JSON.stringify(next);
    }
    function saveIcon(id, value) {
        let next;
        try { next = JSON.parse(Settings.dockIconOverrides || "{}"); } catch (_) { next = {}; }
        if (!next || Array.isArray(next) || typeof next !== "object") next = {};
        if (value.trim()) next[DockModel.key(id)] = value.trim();
        else delete next[DockModel.key(id)];
        Settings.dockIconOverrides = JSON.stringify(next);
        editingPin = "";
    }

    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            Text { text: "DOCK"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 22; font.bold: true }
            Text { text: "Your applications, at the edge of Aperture."; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 12 }
        }
        DockChip { text: "Done"; onClicked: root.closeRequested() }
    }
    RowLayout {
        Repeater {
            model: ["apps", "appearance", "behavior"]
            DockChip {
                required property string modelData
                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                selected: root.page === modelData
                onClicked: root.page = modelData
            }
        }
        Item { Layout.fillWidth: true }
    }
    Text {
        Layout.fillWidth: true
        text: "Move the dock by dragging its island in Bar Studio. Click without dragging to return here."
        color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontText; wrapMode: Text.Wrap
    }

    RowLayout {
        visible: root.page === "apps"
        Layout.fillWidth: true; Layout.fillHeight: true
        spacing: 22
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.preferredWidth: 360
            Text { text: "ON YOUR DOCK"; color: Theme.accent; font.pixelSize: 11; font.family: Theme.fontMono }
            Text { visible: !root.pins.length; text: "No pins yet. Add apps from the list →"; color: Theme.muted; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 6
                model: root.pins
                delegate: Rectangle {
                    id: pinRow
                    required property string modelData
                    required property int index
                    readonly property var app: root.appFor(modelData)
                    width: ListView.view.width
                    height: 76
                    radius: 12; color: Theme.controlRest
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 8; spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Image { Layout.preferredWidth: 26; Layout.preferredHeight: 26; source: Quickshell.iconPath(DockModel.iconFor({appId:pinRow.modelData,icon:pinRow.app ? pinRow.app.icon : ""}, Settings.dockIconOverrides), "application-x-executable") }
                            Text { Layout.fillWidth: true; text: pinRow.app ? pinRow.app.name : pinRow.modelData + " (missing)"; color: Theme.moon; font.pixelSize: 12; elide: Text.ElideRight }
                        }
                        RowLayout {
                            DockChip { text: "↑"; enabled: pinRow.index > 0; Accessible.name: "Move pin earlier"; onClicked: Settings.dockPins = DockModel.movePin(Settings.dockPins, pinRow.modelData, -1) }
                            DockChip { text: "↓"; enabled: pinRow.index < root.pins.length - 1; Accessible.name: "Move pin later"; onClicked: Settings.dockPins = DockModel.movePin(Settings.dockPins, pinRow.modelData, 1) }
                            DockChip { text: "Icon"; onClicked: { root.editingPin = pinRow.modelData; iconInput.text = DockModel.iconFor({appId:pinRow.modelData,icon:pinRow.app ? pinRow.app.icon : ""}, Settings.dockIconOverrides); } }
                            DockChip { text: "×"; Accessible.name: "Unpin application"; onClicked: root.togglePin(pinRow.modelData) }
                        }
                    }
                }
                ScrollBar.vertical: ScrollBar {}
            }
            ColumnLayout {
                visible: root.editingPin !== ""
                Layout.fillWidth: true
                Text { text: "Theme icon name · blank restores the app icon"; color: Theme.muted; font.pixelSize: 10 }
                TextField {
                    id: iconInput
                    Layout.fillWidth: true; color: Theme.moon; font.pixelSize: 12
                    background: Rectangle { color: Theme.fieldRest; radius: 8 }
                    Accessible.name: "Theme icon name"
                    onAccepted: root.saveIcon(root.editingPin, text)
                }
                RowLayout {
                    DockChip { text: "Save icon"; onClicked: root.saveIcon(root.editingPin, iconInput.text) }
                    DockChip { text: "Reset"; onClicked: root.saveIcon(root.editingPin, "") }
                    DockChip { text: "Cancel"; onClicked: root.editingPin = "" }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.preferredWidth: 360
            Text { text: "ADD APPLICATIONS"; color: Theme.accent; font.pixelSize: 11; font.family: Theme.fontMono }
            TextField {
                Layout.fillWidth: true
                placeholderText: "Search installed apps…"
                color: Theme.moon; placeholderTextColor: Theme.muted; font.pixelSize: 12
                onTextChanged: root.query = text
                background: Rectangle { color: Theme.fieldRest; radius: 10 }
                Accessible.name: "Find an app to pin"
            }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 4
                model: root.applications
                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    width: ListView.view.width; height: 46; radius: 10
                    color: Theme.controlRest
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 6
                        Image { Layout.preferredWidth: 26; Layout.preferredHeight: 26; source: Quickshell.iconPath(appRow.modelData.icon, "application-x-executable") }
                        Text { Layout.fillWidth: true; text: appRow.modelData.name; color: Theme.moon; font.pixelSize: 12; elide: Text.ElideRight }
                        DockChip { text: root.isPinned(appRow.modelData.id) ? "Pinned" : "+"; selected: root.isPinned(appRow.modelData.id); Accessible.name: "Toggle pin for " + appRow.modelData.name; onClicked: root.togglePin(appRow.modelData.id) }
                    }
                }
                ScrollBar.vertical: ScrollBar {}
            }
        }
    }
    ColumnLayout {
        visible: root.page === "appearance"
        Layout.fillWidth: true; Layout.fillHeight: true
        spacing: 14
        DockSettingSlider { Layout.fillWidth: true; label: "Icon size"; suffix: " px"; from: 28; to: 64; stepSize: 4; value: Settings.dockIconSize; onEdited: value => Settings.dockIconSize = value }
        SettingToggle { Layout.fillWidth: true; label: "Hover lift"; detail: "Enlarge icons without moving their click targets."; checked: Settings.dockHoverLift; onToggled: Settings.dockHoverLift = !Settings.dockHoverLift }
        Text { text: "DISPLAY"; color: Theme.muted; font.pixelSize: 11 }
        Flow {
            Layout.fillWidth: true; spacing: 6
            DockChip { text: "First display"; selected: Settings.dockOutput === ""; onClicked: Settings.dockOutput = "" }
            DockChip { text: "This display"; selected: Settings.dockOutput === root.outputName; onClicked: Settings.dockOutput = root.outputName }
            DockChip { text: "All displays"; selected: Settings.dockOutput === "*"; onClicked: Settings.dockOutput = "*" }
        }
        Item { Layout.fillHeight: true }
    }
    ColumnLayout {
        visible: root.page === "behavior"
        Layout.fillWidth: true; Layout.fillHeight: true
        spacing: 12
        SettingToggle { Layout.fillWidth: true; label: "Show running applications"; detail: "Include unpinned apps while they have open windows."; checked: Settings.dockShowRunning; onToggled: Settings.dockShowRunning = !Settings.dockShowRunning }
        SettingToggle { Layout.fillWidth: true; label: "Applications shortcut"; detail: "Keep the launcher button. It also appears when the dock is empty."; checked: Settings.dockShowLauncher; onToggled: Settings.dockShowLauncher = !Settings.dockShowLauncher }
        DockSettingSlider { Layout.fillWidth: true; label: "Reveal delay"; suffix: " ms"; from: 0; to: 600; stepSize: 20; value: Settings.dockShowDelay; onEdited: value => Settings.dockShowDelay = value }
        DockSettingSlider { Layout.fillWidth: true; label: "Hide delay"; suffix: " ms"; from: 150; to: 1500; stepSize: 50; value: Settings.dockHideDelay; onEdited: value => Settings.dockHideDelay = value }
        Text { Layout.fillWidth: true; text: "Click to focus or cycle windows. Middle-click / Shift-click to launch another instance."; wrapMode: Text.Wrap; color: Theme.muted; font.pixelSize: 11 }
        Item { Layout.fillHeight: true }
    }
}
