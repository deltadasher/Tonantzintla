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
    spacing: height < 420 ? 8 : 16
    onPageChanged: { editingPin = ""; pageViewport.contentY = 0; }
    function revealFocus() {
        const item = root.Window.window ? root.Window.window.activeFocusItem : null;
        if (!item) return;
        let ancestor = item.parent;
        while (ancestor && ancestor !== root) {
            if (typeof ancestor.contentY === "number" && ancestor.contentItem) {
                const point = item.mapToItem(ancestor.contentItem, 0, 0);
                if (point.y < ancestor.contentY) ancestor.contentY = point.y;
                else if (point.y + item.height > ancestor.contentY + ancestor.height)
                    ancestor.contentY = point.y + item.height - ancestor.height;
                ancestor.contentY = Math.max(0, Math.min(ancestor.contentY, Math.max(0, ancestor.contentHeight - ancestor.height)));
            }
            ancestor = ancestor.parent;
        }
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() { root.revealFocus(); }
    }

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
            Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Your applications, at the edge of Aperture."; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 12 }
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
        visible: root.height >= 420
        text: "Move the dock by dragging its island in Bar Studio. Click without dragging to return here."
        color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontText; wrapMode: Text.Wrap
    }

    Flickable {
        id: pageViewport
        objectName: "dock-settings-viewport"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        contentWidth: width
        contentHeight: pageLoader.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Loader {
            id: pageLoader
            width: pageViewport.width
            sourceComponent: root.page === "appearance" ? appearancePage : root.page === "behavior" ? behaviorPage : appsPage
        }
    }
    Component {
        id: appsPage
    GridLayout {
        columns: width < 600 ? 1 : 2
        columnSpacing: 22; rowSpacing: 16
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.preferredWidth: 360
            Layout.preferredHeight: Math.max(180, Math.min(320, root.height - 180))
            Text { text: "ON YOUR DOCK"; color: Theme.accent; font.pixelSize: 11; font.family: Theme.fontMono }
            Text { visible: !root.pins.length; text: "No pins yet. Add apps from the list →"; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
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
                            Image { Layout.preferredWidth: 26; Layout.preferredHeight: 26; sourceSize: Qt.size(Math.ceil(26 * Math.min(3, Math.max(1, Screen.devicePixelRatio))), Math.ceil(26 * Math.min(3, Math.max(1, Screen.devicePixelRatio)))); source: Quickshell.iconPath(DockModel.iconFor({appId:pinRow.modelData,icon:pinRow.app ? pinRow.app.icon : ""}, Settings.dockIconOverrides), "application-x-executable") }
                            Text { Layout.fillWidth: true; text: pinRow.app ? pinRow.app.name : pinRow.modelData + " (missing)"; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 12; elide: Text.ElideRight }
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
                Text { text: "Theme icon name · blank restores the app icon"; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 10 }
                TextField {
                    id: iconInput
                    Layout.fillWidth: true; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 12
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
            Layout.preferredHeight: Math.max(180, Math.min(320, root.height - 180))
            Text { text: "ADD APPLICATIONS"; color: Theme.accent; font.pixelSize: 11; font.family: Theme.fontMono }
            TextField {
                Layout.fillWidth: true
                text: root.query
                placeholderText: "Search installed apps…"
                color: Theme.moon; placeholderTextColor: Theme.muted; font.family: Theme.fontText; font.pixelSize: 12
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
                        Image { Layout.preferredWidth: 26; Layout.preferredHeight: 26; sourceSize: Qt.size(Math.ceil(26 * Math.min(3, Math.max(1, Screen.devicePixelRatio))), Math.ceil(26 * Math.min(3, Math.max(1, Screen.devicePixelRatio)))); source: Quickshell.iconPath(appRow.modelData.icon, "application-x-executable") }
                        Text { Layout.fillWidth: true; text: appRow.modelData.name; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 12; elide: Text.ElideRight }
                        DockChip { text: root.isPinned(appRow.modelData.id) ? "Pinned" : "+"; selected: root.isPinned(appRow.modelData.id); Accessible.name: "Toggle pin for " + appRow.modelData.name; onClicked: root.togglePin(appRow.modelData.id) }
                    }
                }
                ScrollBar.vertical: ScrollBar {}
            }
        }
    }
    }
    Component {
        id: appearancePage
    ColumnLayout {
        spacing: 14
        DockSettingSlider { Layout.fillWidth: true; label: "Icon size"; suffix: " px"; from: 28; to: 72; stepSize: 4; value: Settings.dockIconSize; onEdited: value => Settings.dockIconSize = value }
        SettingToggle { Layout.fillWidth: true; label: "Hover lift"; detail: "Enlarge icons without moving their click targets."; checked: Settings.dockHoverLift; onToggled: Settings.dockHoverLift = !Settings.dockHoverLift }
        DockSettingSlider { Layout.fillWidth: true; enabled: Settings.dockHoverLift; label: "Hover size"; suffix: "%"; from: 100; to: 160; stepSize: 4; value: Settings.dockHoverScale * 100; onEdited: value => Settings.dockHoverScale = value / 100 }
        SettingToggle { Layout.fillWidth: true; label: "Neighbor lift"; detail: "Adjacent icons follow at half strength. Click targets stay fixed."; checked: Settings.dockHoverNeighbors; onToggled: Settings.dockHoverNeighbors = !Settings.dockHoverNeighbors }
        SettingToggle { Layout.fillWidth: true; label: "Dock backing"; checked: Settings.dockBackground; onToggled: Settings.dockBackground = !Settings.dockBackground }
        SettingToggle { Layout.fillWidth: true; label: "Running indicators"; checked: Settings.dockShowIndicators; onToggled: Settings.dockShowIndicators = !Settings.dockShowIndicators }
        Text { text: "DISPLAY"; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11 }
        Flow {
            Layout.fillWidth: true; spacing: 6
            DockChip { text: "First display"; selected: Settings.dockOutput === ""; onClicked: Settings.dockOutput = "" }
            DockChip { text: "This display"; selected: Settings.dockOutput === root.outputName; onClicked: Settings.dockOutput = root.outputName }
            DockChip { text: "All displays"; selected: Settings.dockOutput === "*"; onClicked: Settings.dockOutput = "*" }
        }
    }
    }
    Component {
        id: behaviorPage
    ColumnLayout {
        spacing: 12
        SettingToggle { Layout.fillWidth: true; label: "Show running applications"; detail: "Include unpinned apps while they have open windows."; checked: Settings.dockShowRunning; onToggled: Settings.dockShowRunning = !Settings.dockShowRunning }
        SettingToggle { Layout.fillWidth: true; label: "Applications shortcut"; detail: "Keep the launcher button. It also appears when the dock is empty."; checked: Settings.dockShowLauncher; onToggled: Settings.dockShowLauncher = !Settings.dockShowLauncher }
        SettingChoice {
            Layout.fillWidth: true; label: "Window scope"; value: Settings.dockWindowScope
            choices: [{label: "ALL", value: "all"}, {label: "THIS DISPLAY", value: "output"}, {label: "ACTIVE WORKSPACE", value: "workspace"}]
            onSelected: value => Settings.dockWindowScope = value
        }
        SettingToggle { Layout.fillWidth: true; label: "Auto-hide"; detail: "Turn off to keep the dock visible."; checked: Settings.dockAutoHide; onToggled: Settings.dockAutoHide = !Settings.dockAutoHide }
        SettingToggle { Layout.fillWidth: true; label: "Above application windows"; checked: Settings.dockAboveWindows; onToggled: Settings.dockAboveWindows = !Settings.dockAboveWindows }
        SettingToggle { Layout.fillWidth: true; enabled: !Settings.dockAutoHide; label: "Reserve screen space"; detail: "Keep application windows clear of the persistent dock."; checked: Settings.dockExclusive; onToggled: Settings.dockExclusive = !Settings.dockExclusive }
        DockSettingSlider { Layout.fillWidth: true; enabled: Settings.dockAutoHide; label: "Reveal delay"; suffix: " ms"; from: 0; to: 600; stepSize: 20; value: Settings.dockShowDelay; onEdited: value => Settings.dockShowDelay = value }
        DockSettingSlider { Layout.fillWidth: true; enabled: Settings.dockAutoHide; label: "Hide delay"; suffix: " ms"; from: 150; to: 1500; stepSize: 50; value: Settings.dockHideDelay; onEdited: value => Settings.dockHideDelay = value }
        Text { Layout.fillWidth: true; text: "Click to focus or cycle windows. Middle-click / Shift-click to launch another instance."; wrapMode: Text.Wrap; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11 }
    }
    }
}
