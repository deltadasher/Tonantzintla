pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../../.."
import "../../../../services"
import "../../../../components"
import "../../EphemerisRegistry.js" as Registry
import "LauncherModel.js" as Model

Item {
    id: root

    property string query: ""
    property string category: "all"
    property string selection: ""
    property string feedback: ""
    readonly property var applications: Model.applications(DesktopEntries.applications.values)
    readonly property var entries: applications.concat(Model.surfaceCommands(Registry.widgets()), settingsCommands, sessionCommands)
    readonly property var results: Model.filter(entries, query, category, LaunchHistory.favorites)
        .slice(0, Math.max(1, Settings.launcherMaxResults))
    readonly property var selected: results.find(function(entry) { return entry.id === selection; }) || null
    readonly property var settingsCommands: [
        { id: "settings:appearance", kind: "settings", target: "appearance", name: "Appearance settings", detail: "Palette, typography and atmosphere", keywords: "theme colors colour font motion density" },
        { id: "settings:bar", kind: "settings", target: "bar", name: "Bar settings", detail: "Aperture layout and indicators", keywords: "aperture bar clock position" },
        { id: "settings:launcher", kind: "settings", target: "launcher", name: "Panel settings", detail: "Launcher and surface behavior", keywords: "apps ephemeris animation transition" },
        { id: "settings:umbra", kind: "settings", target: "umbra", name: "Lock screen settings", detail: "Umbra appearance and behavior", keywords: "lock umbra" },
        { id: "settings:system", kind: "settings", target: "system", name: "System settings", detail: "Preferred applications and integrations", keywords: "browser terminal file manager defaults" },
        { id: "settings:extensions", kind: "settings", target: "extensions", name: "Extension settings", detail: "Module availability", keywords: "modules integrations diagnostic" }
    ]
    readonly property var sessionCommands: [
        { id: "launch:terminal", kind: "launch", target: "terminal", name: "Open terminal", detail: "Your configured terminal", keywords: "console command prompt" },
        { id: "launch:browser", kind: "launch", target: "browser", name: "Open browser", detail: "Your default browser", keywords: "web internet" },
        { id: "launch:files", kind: "launch", target: "files", name: "Open files", detail: "Your configured file manager", keywords: "home folders directory" },
        { id: "media:toggle", kind: "media", target: "toggle", name: Media.playing ? "Pause media" : "Play media", detail: Media.available ? Media.title : "No media player connected", keywords: "music audio playback play pause toggle", enabled: Media.available && Media.player.canTogglePlaying },
        { id: "media:next", kind: "media", target: "next", name: "Next track", detail: Media.available ? Media.identity : "No media player connected", keywords: "music skip forward", enabled: Media.available && Media.player.canGoNext },
        { id: "media:previous", kind: "media", target: "previous", name: "Previous track", detail: Media.available ? Media.identity : "No media player connected", keywords: "music back previous", enabled: Media.available && Media.player.canGoPrevious },
        { id: "focus:toggle", kind: "focus", name: ShellState.deepFocus ? "Leave event horizon" : "Enter event horizon", detail: ShellState.deepFocus ? "Restore the bar and notifications" : "Quiet the bar and notifications for deep focus", keywords: "focus concentration distractions zen event horizon" },
        { id: "session:lock", kind: "lock", name: "Lock screen", detail: "Secure this session with Umbra", keywords: "lock session umbra" }
    ]

    function focusPrimary() {
        searchInput.forceActiveFocus();
        searchInput.cursorPosition = searchInput.text.length;
    }

    function reconcileSelection() {
        selection = Model.selectedId(results, selection);
        Qt.callLater(keepSelectionVisible);
    }

    function keepSelectionVisible() {
        const index = results.findIndex(function(entry) { return entry.id === selection; });
        if (index >= 0)
            resultList.positionViewAtIndex(index, ListView.Contain);
    }

    function moveSelection(delta) {
        selection = Model.moveSelection(results, selection, delta);
        keepSelectionVisible();
    }

    function activate(entry) {
        if (!entry || entry.enabled === false)
            return;
        feedback = "";
        if (entry.kind === "app") {
            try {
                entry.app.execute();
                LaunchHistory.record(entry.appId);
                ShellState.closeEphemeris();
            } catch (error) {
                feedback = "Could not launch " + entry.name;
            }
        } else if (entry.kind === "surface") {
            ShellState.openEphemeris(entry.target);
        } else if (entry.kind === "settings") {
            ShellState.settingsSection = entry.target;
            ShellState.openEphemeris("settings");
        } else if (entry.kind === "launch" && ["terminal", "browser", "files"].indexOf(entry.target) >= 0) {
            Quickshell.execDetached([Environment.controlPath, entry.target]);
            ShellState.closeEphemeris();
        } else if (entry.kind === "media") {
            if (entry.target === "toggle") Media.toggle();
            else if (entry.target === "next") Media.next();
            else if (entry.target === "previous") Media.previous();
            // Stay open so repeated track changes remain one keyboard action.
        } else if (entry.kind === "focus") {
            ShellState.toggleDeepFocus();
            ShellState.closeEphemeris();
        } else if (entry.kind === "lock") {
            Umbra.launchLock();
            ShellState.closeEphemeris();
        }
    }

    function toggleSelectedFavorite() {
        if (selected && selected.kind === "app")
            LaunchHistory.toggleFavorite(selected.appId);
    }

    function selectCategory(value) {
        category = value;
        if (query.trim().charAt(0) === ">")
            searchInput.text = query.trim().substring(1).trim();
        focusPrimary();
    }

    onResultsChanged: reconcileSelection()
    Component.onCompleted: reconcileSelection()

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            WabiSabiBlackHole {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 52
                diskColor: Theme.accent
                horizonColor: Theme.void_
            }

            Text {
                text: "BLACKHOLE"
                color: Theme.moon
                font.family: Theme.fontText
                font.pixelSize: 17
                font.weight: Font.DemiBold
                font.letterSpacing: 2
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.preferredHeight: 1
                color: Theme.accentLine
                opacity: 0.3
            }

            Rectangle {
                id: closeButton
                Layout.preferredWidth: 42
                Layout.preferredHeight: 32
                radius: 9
                color: closePointer.containsMouse || activeFocus ? Theme.controlHover : Theme.controlRest
                border.width: 1
                border.color: activeFocus ? Theme.accent : Theme.line
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Close launcher"
                Accessible.onPressAction: ShellState.closeEphemeris()
                Keys.onReturnPressed: ShellState.closeEphemeris()
                Keys.onSpacePressed: ShellState.closeEphemeris()
                Text {
                    anchors.centerIn: parent
                    text: "esc"
                    color: closePointer.containsMouse || closeButton.activeFocus ? Theme.moon : Theme.muted
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                }
                MouseArea {
                    id: closePointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellState.closeEphemeris()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            radius: Theme.radiusMedium
            color: searchInput.activeFocus ? Theme.fieldFocus : Theme.mantle
            border.width: 1
            border.color: searchInput.activeFocus ? Theme.accentLine : "transparent"

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.moon
                selectionColor: Theme.accent
                selectedTextColor: Theme.void_
                font.family: Theme.fontText
                font.pixelSize: 15
                clip: true
                text: root.query
                onTextChanged: { root.query = text; root.feedback = ""; }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Down) {
                        root.moveSelection(1); event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.moveSelection(-1); event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.activate(root.selected); event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        if (root.query.length) searchInput.clear();
                        else ShellState.closeEphemeris();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                        root.toggleSelectedFavorite(); event.accepted = true;
                    }
                }
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text.length === 0
                text: "Find apps, actions or settings…"
                color: Theme.muted
                font.family: Theme.fontText
                font.pixelSize: 14
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [{ id: "all", name: "ALL" }, { id: "apps", name: "APPS" },
                    { id: "actions", name: "ACTIONS" }, { id: "saved", name: "SAVED" }]
                Rectangle {
                    id: categoryChip
                    required property var modelData
                    readonly property bool active: root.query.trim().charAt(0) === ">"
                        ? modelData.id === "actions" : root.category === modelData.id
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: Theme.radiusSmall
                    color: active ? Theme.controlActive : categoryPointer.containsMouse ? Theme.controlHover : Theme.controlRest
                    Accessible.role: Accessible.Button
                    Accessible.name: "Show " + modelData.name.toLowerCase()
                    Accessible.onPressAction: root.selectCategory(modelData.id)
                    Text {
                        anchors.centerIn: parent
                        text: categoryChip.modelData.name
                        color: categoryChip.active ? Theme.accent : Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                    }
                    MouseArea {
                        id: categoryPointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectCategory(categoryChip.modelData.id)
                    }
                }
            }
        }

        ListView {
            id: resultList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.results
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true

            delegate: Rectangle {
                id: result
                required property var modelData
                required property int index
                readonly property bool selected: modelData.id === root.selection
                readonly property bool available: modelData.enabled !== false
                readonly property int uses: modelData.kind === "app" ? LaunchHistory.count(modelData.appId) : 0
                readonly property bool saved: modelData.kind === "app" && LaunchHistory.isFavorite(modelData.appId)
                width: resultList.width
                height: 66
                radius: Theme.radiusMedium
                color: selected ? Theme.controlActive : pointer.containsMouse ? Theme.controlHover : Theme.controlRest
                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.name + ". " + modelData.detail
                Accessible.selected: selected
                Accessible.onPressAction: root.activate(modelData)

                MouseArea {
                    id: pointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: result.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPositionChanged: if (containsMouse) root.selection = result.modelData.id
                    onClicked: { root.selection = result.modelData.id; root.activate(result.modelData); }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 11
                        color: result.selected ? Theme.accentVeil : Theme.controlRest
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 25
                            visible: result.modelData.kind === "app"
                            source: result.modelData.kind === "app"
                                ? Quickshell.iconPath(result.modelData.app.icon, "application-x-executable") : ""
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: result.modelData.kind !== "app"
                            text: result.modelData.kind === "media" ? "♪" : result.modelData.kind === "settings" ? "⚙" : "›"
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: 19
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            Layout.fillWidth: true
                            text: result.modelData.name
                            color: Theme.moon
                            font.family: Theme.fontText
                            font.pixelSize: Math.min(22, 14 + Math.log(result.uses + 1) * 2)
                            font.weight: result.selected || result.uses > 5 ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: result.modelData.kind !== "app" || Settings.showAppDescriptions
                            text: result.modelData.detail
                            color: Theme.muted
                            font.family: Theme.fontText
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        id: favoriteButton
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 34
                        visible: result.modelData.kind === "app"
                        radius: Theme.radiusSmall
                        color: favoritePointer.containsMouse ? Theme.controlHover : "transparent"
                        Accessible.role: Accessible.Button
                        Accessible.name: (result.saved ? "Unsave " : "Save ") + result.modelData.name
                        Accessible.onPressAction: LaunchHistory.toggleFavorite(result.modelData.appId)
                        Text {
                            anchors.centerIn: parent
                            text: result.saved ? "★" : "☆"
                            color: result.saved ? Theme.accent : Theme.muted
                            opacity: result.saved || result.selected || pointer.containsMouse ? 1 : 0.4
                            font.pixelSize: 18
                        }
                        MouseArea {
                            id: favoritePointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LaunchHistory.toggleFavorite(result.modelData.appId)
                        }
                    }
                }
                Behavior on color { ColorAnimation { duration: Settings.motion ? Theme.motionFast : 0 } }
            }

            Column {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - 32)
                spacing: 10
                visible: root.results.length === 0
                Text {
                    width: parent.width
                    text: root.category === "saved" && !root.query ? "Your saved apps appear here" : "No matches"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: Theme.moon
                    font.family: Theme.fontText
                    font.pixelSize: 16
                }
                Text {
                    width: parent.width
                    text: root.category === "saved" && !root.query ? "Use the star beside an app to keep it close."
                        : "Try an app name, wallpaper, audio or settings."
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: Theme.muted
                    font.family: Theme.fontText
                    font.pixelSize: 12
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.feedback || "↑↓  SELECT     ↵  OPEN     >  ACTIONS     CTRL P  SAVE"
            color: root.feedback ? Theme.accent : Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: 9
            wrapMode: Text.WordWrap
        }
    }
}
