import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../.."
import "../.."
import "../../../../services"

Item {
    id: root

    property string query: ""
    property var selectedApp: null
    // Quickshell already excludes Hidden and NoDisplay entries. Generic
    // "About …" helpers are not launch targets and should not own prime slots.
    readonly property var allApps: DesktopEntries.applications.values.filter(function(app) {
        const name = String(app.name || "").trim();
        const command = String(app.command || "").trim();
        return name.length > 0 && command.length > 0 && !/^about(?:\s|$)/i.test(name);
    })
    readonly property var stableApps: {
        const apps = allApps.slice();
        apps.sort(function(first, second) {
            const delta = stableHash(first.id || first.name) - stableHash(second.id || second.name);
            return delta !== 0 ? delta : first.name.localeCompare(second.name);
        });
        // Every installed app keeps a permanent slot; slicing here would make
        // apps past the cap unreachable even by search.
        return apps;
    }
    readonly property var displayApps: {
        const needle = query.trim();
        if (!needle)
            return stableApps;
        const matching = [];
        stableApps.forEach(function(app) { if (matches(app)) matching.push(app); });
        return matching;
    }

    function stableHash(value) {
        let hash = 2166136261;
        const text = String(value || "");
        for (let index = 0; index < text.length; index++) {
            hash ^= text.charCodeAt(index);
            hash = Math.imul(hash, 16777619);
        }
        return hash >>> 0;
    }

    function matches(app) {
        const needle = query.trim().toLowerCase();
        if (!needle)
            return true;
        const haystack = [app.name, app.genericName, app.comment, app.id].join(" ").toLowerCase();
        if (haystack.indexOf(needle) >= 0)
            return true;
        let cursor = 0;
        for (let index = 0; index < needle.length; index++) {
            cursor = haystack.indexOf(needle.charAt(index), cursor);
            if (cursor < 0)
                return false;
            cursor++;
        }
        return true;
    }

    function focusPrimary() {
        searchInput.forceActiveFocus();
        searchInput.cursorPosition = searchInput.text.length;
    }

    function launch(app) {
        if (!app)
            return;
        LaunchHistory.record(app.id || app.name);
        app.execute();
        ShellState.closeEphemeris();
    }

    function moveSelection(delta) {
        if (displayApps.length === 0) {
            selectedApp = null;
            return;
        }
        let cursor = displayApps.indexOf(selectedApp);
        if (cursor < 0)
            cursor = delta > 0 ? -1 : 0;
        cursor = (cursor + delta + displayApps.length) % displayApps.length;
        selectedApp = displayApps[cursor];
        appList.positionViewAtIndex(cursor, ListView.Contain);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "APPLICATIONS"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 22
                font.weight: Font.Black
            }
            Text {
                text: "SIZE = USE  ·  POSITION = PERMANENT"
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.letterSpacing: 0.8
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: Theme.radiusMedium
            color: Theme.mantle

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.moon
                selectionColor: Theme.accent
                selectedTextColor: Theme.void_
                font.family: Theme.fontMono
                font.pixelSize: 12
                clip: true
                text: root.query
                onTextChanged: {
                    root.query = text;
                    root.selectedApp = root.displayApps.length > 0 ? root.displayApps[0] : null;
                }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Down) {
                        root.moveSelection(1); event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.moveSelection(-1); event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.selectedApp)
                            root.launch(root.selectedApp);
                        event.accepted = true;
                    }
                }
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text.length === 0
                text: "Type to pull matching names into focus…"
                color: Theme.lineBright
                font.family: Theme.fontMono
                font.pixelSize: 11
            }
        }

        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 3
            model: root.displayApps

            delegate: AppResult {
                width: appList.width
                selected: modelData === root.selectedApp
                matched: true
                launchCount: LaunchHistory.count(modelData.id || modelData.name)
                onHovered: function(index) { root.selectedApp = modelData; }
                onActivated: root.launch(modelData)
            }

            Text {
                anchors.centerIn: parent
                visible: root.displayApps.length === 0
                text: "No matches"
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 10
            }
        }
    }
}
