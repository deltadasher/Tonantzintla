import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../.."
import "../.."

Item {
    id: root

    property string query: ""
    property int selectedIndex: 0
    readonly property var allApps: DesktopEntries.applications.values
    readonly property var filteredApps: {
        const needle = query.trim().toLowerCase();
        const matches = allApps.filter(function(app) {
            if (!needle)
                return true;
            const haystack = [app.name, app.genericName, app.comment, app.id]
                .join(" ").toLowerCase();
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
        });
        matches.sort(function(first, second) {
            const firstName = first.name.toLowerCase();
            const secondName = second.name.toLowerCase();
            const firstPrefix = needle && firstName.indexOf(needle) === 0 ? 1 : 0;
            const secondPrefix = needle && secondName.indexOf(needle) === 0 ? 1 : 0;
            return firstPrefix !== secondPrefix
                ? secondPrefix - firstPrefix : firstName.localeCompare(secondName);
        });
        return matches.slice(0, Settings.launcherMaxResults);
    }

    function focusPrimary() {
        searchInput.forceActiveFocus();
        searchInput.cursorPosition = searchInput.text.length;
    }

    function launch(app) {
        if (!app)
            return;
        app.execute();
        ShellState.closeEphemeris();
    }

    function moveSelection(delta) {
        if (filteredApps.length === 0) {
            selectedIndex = 0;
            return;
        }
        selectedIndex = (selectedIndex + delta + filteredApps.length) % filteredApps.length;
        appList.positionViewAtIndex(selectedIndex, ListView.Contain);
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
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: Theme.radiusMedium
            color: Theme.mantle
            border.width: 0
            border.color: searchInput.activeFocus ? Theme.accentLine : Theme.line

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
                onTextChanged: { root.query = text; root.selectedIndex = 0; }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Down) {
                        root.moveSelection(1); event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.moveSelection(-1); event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.filteredApps.length > 0)
                            root.launch(root.filteredApps[root.selectedIndex]);
                        event.accepted = true;
                    }
                }
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text.length === 0
                text: "Search apps…"
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
            model: root.filteredApps

            delegate: AppResult {
                width: appList.width
                selected: index === root.selectedIndex
                onHovered: function(index) { root.selectedIndex = index; }
                onActivated: root.launch(modelData)
            }

            Text {
                anchors.centerIn: parent
                visible: appList.count === 0
                text: "No matches"
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 10
            }
        }
    }
}
