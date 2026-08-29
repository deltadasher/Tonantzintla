import QtQuick
import QtQuick.Layouts
import "../shared" as Shared
import "../../../../design/concepts" as Concepts
import "../../../.."
import "../../../../services"

pragma ComponentBehavior: Bound

Item {
    id: root

    property int currentTab: 0
    property int selectedModule: 0

    readonly property var tabs: [
        { "label": "Mission", "code": "OVR" },
        { "label": "Modules", "code": "MOD" },
        { "label": "Controls", "code": "NIR" },
        { "label": "Port map", "code": "MAP" }
    ]

    readonly property var modules: [
        { "name": "Application catalog", "code": "APP", "widget": "apps", "glyph": "󰀻", "detail": "Desktop entry search and launch" },
        { "name": "Celestial calendar", "code": "CAL", "widget": "calendar", "glyph": "󰃭", "detail": "Calendar, weather, and orbital forecast" },
        { "name": "Optics bay", "code": "OPT", "widget": "capture", "glyph": "󰹑", "detail": "Screenshots, Satty editing, and 60 FPS recording" },
        { "name": "Resonance console", "code": "MPR", "widget": "media", "glyph": "󰎆", "detail": "Lyrics, expanded MPRIS controls, spectrum, and EQ" },
        { "name": "Acoustic array", "code": "AUD", "widget": "audio", "glyph": "󰕾", "detail": "PipeWire outputs, inputs, and streams" },
        { "name": "Link array", "code": "NET", "widget": "network", "glyph": "󰤨", "detail": "Wi-Fi, Bluetooth, and Ethernet" },
        { "name": "Reactor telemetry", "code": "PWR", "widget": "battery", "glyph": "󰁹", "detail": "Battery health, energy flow, and power profiles" },
        { "name": "Parallax archive", "code": "WAL", "widget": "walls", "glyph": "󰸉", "detail": "Persistent wallpaper observatory" },
        { "name": "Transit signals", "code": "SIG", "widget": "notifications", "glyph": "󰂚", "detail": "Notification history and DND" },
        { "name": "Clipboard orbit", "code": "CLP", "widget": "clipboard", "glyph": "󰅌", "detail": "Searchable clipboard history" },
        { "name": "Focus orbit", "code": "FCS", "widget": "focus", "glyph": "󰔟", "detail": "Persistent focus/drift cycles, seven-day totals, and streaks" },
        { "name": "Chronos array", "code": "TMR", "widget": "timer", "glyph": "󰔟", "detail": "Countdown, lap stopwatch, and focus controls" },
        { "name": "Quick telemetry", "code": "TEL", "widget": "quickstats", "glyph": "󰍛", "detail": "Compact animated workstation signals" },
        { "name": "System observatory", "code": "SYS", "widget": "system", "glyph": "󰍛", "detail": "Live Niri workstation telemetry" },
        { "name": "Field tools", "code": "FLD", "widget": "tools", "glyph": "󰒓", "detail": "Capture, overview, lock, and terminal" },
        { "name": "Observatory settings", "code": "CFG", "widget": "settings", "glyph": "󰒓", "detail": "Live suite configuration" }
    ]

    readonly property var controls: [
        { "keys": "META + ENTER", "name": "Terminology", "detail": "Open the nEri terminal" },
        { "keys": "META + UP / DOWN", "name": "Workspace travel", "detail": "Move one desktop up or down" },
        { "keys": "META + K / J", "name": "Vertical window focus", "detail": "Focus the window above or below" },
        { "keys": "META + D", "name": "Application catalog", "detail": "Search installed desktop entries" },
        { "keys": "META + SHIFT + N", "name": "Observatory settings", "detail": "Open Astralith configuration" },
        { "keys": "META + SHIFT + Q", "name": "Essential deck", "detail": "Toggle timer and performance quick actions" },
        { "keys": "META + SHIFT + S", "name": "Clipboard snip", "detail": "Niri crop selection, clipboard copy, and screenshot archive" },
        { "keys": "META + SHIFT + ESC", "name": "System monitor", "detail": "Open btop in a terminal" },
        { "keys": "ALT + F4", "name": "Close window", "detail": "Ask Niri to close the focused window" }
    ]

    readonly property var parity: [
        { "name": "Top bar and workspaces", "state": "NATIVE", "tone": Theme.success, "detail": "Niri-aware capsules, media, tray, and telemetry" },
        { "name": "Calendar and weather", "state": "NATIVE", "tone": Theme.success, "detail": "Astralith forecast orbit with responsive Niri geometry" },
        { "name": "Typography system", "state": "PORTED", "tone": Theme.success, "detail": "JetBrains Mono plus Iosevka roles with live settings" },
        { "name": "Audio and network", "state": "NATIVE", "tone": Theme.success, "detail": "PipeWire and NetworkManager without Hyprland hooks" },
        { "name": "Music, lyrics, and EQ", "state": "NATIVE", "tone": Theme.success, "detail": "MPRIS, CAVA, synchronized lyrics, and original EasyEffects profiles" },
        { "name": "Focus cycles and statistics", "state": "NATIVE", "tone": Theme.success, "detail": "Persistent focus/drift phases, seven-day totals, and streaks" },
        { "name": "Online and video walls", "state": "NATIVE", "tone": Theme.success, "detail": "Commons search, filters, monitor targets, and animated media" },
        { "name": "Floating quick actions", "state": "PORTED", "tone": Theme.success, "detail": "On-demand timer and compact performance telemetry" },
        { "name": "Capture and recording", "state": "PORTED", "tone": Theme.success, "detail": "Region and output capture, Satty editing, and portal recording" },
        { "name": "Umbra lock surface", "state": "ONLINE", "tone": Theme.success, "detail": "Fluid multi-output veil with PAM authentication and safe preview" },
        { "name": "Updater and release view", "state": "BLOCKED", "tone": Theme.rose, "detail": "Activates after Astralith has its own repository" },
        { "name": "Stewart assistant core", "state": "LATER", "tone": Theme.muted, "detail": "Visual shell exists upstream; assistant is currently reserved" },
        { "name": "Movies surface", "state": "LATER", "tone": Theme.muted, "detail": "Large external-media integration" }
    ]

    function focusPrimary() {
        tabRow.forceActiveFocus();
    }

    function openWidget(name) {
        ShellState.openEphemeris(name);
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left) {
            currentTab = (currentTab + tabs.length - 1) % tabs.length;
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            currentTab = (currentTab + 1) % tabs.length;
            event.accepted = true;
        }
    }

    component SectionTitle: ColumnLayout {
        property string title: "SECTION"
        property string detail: ""
        spacing: 2
        Text {
            text: parent.title
            color: Theme.moon
            font.family: Theme.fontDisplay
            font.pixelSize: 21
            font.weight: Font.Black
            font.letterSpacing: 0.4
        }
        Text {
            text: parent.detail
            color: Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: 11
            font.letterSpacing: 1
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: "FLIGHT MANUAL"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 24
                font.weight: Font.Black
            }
        }

        RowLayout {
            id: tabRow
            Layout.fillWidth: true
            spacing: 6
            focus: true

            Repeater {
                model: root.tabs
                Rectangle {
                    id: tabButton
                    required property var modelData
                    required property int index
                    readonly property bool active: root.currentTab === index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: Theme.radiusSmall
                    color: active ? Theme.accentVeil : tabPointer.containsMouse ? Theme.elevated : Theme.mantle
                    border.width: 0
                    border.color: active ? Theme.accentLine : Theme.line

                    Text {
                        anchors.centerIn: parent
                        text: tabButton.modelData.label
                        color: tabButton.active ? Theme.moon : Theme.muted
                        font.family: Theme.fontText
                        font.pixelSize: 13
                        font.weight: tabButton.active ? Font.Bold : Font.Normal
                    }
                    MouseArea { id: tabPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.currentTab = tabButton.index }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Loader {
                id: pageLoader
                anchors.fill: parent
                sourceComponent: root.currentTab === 0 ? missionPage
                    : root.currentTab === 1 ? modulesPage
                    : root.currentTab === 2 ? controlsPage
                    : parityPage
            }
        }
    }

    Component {
        id: missionPage
        RowLayout {
            spacing: 12

            Rectangle {
                Layout.preferredWidth: Math.min(390, parent.width * 0.37)
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: Theme.mantle
                border.width: 0
                border.color: Theme.line

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14
                    Text { text: "ASTRALITH"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 29; font.weight: Font.Black; font.letterSpacing: 2; Layout.alignment: Qt.AlignHCenter }
                    Concepts.WabiSabiBlackHole {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 156
                        diskColor: Theme.accent
                        horizonColor: Theme.void_
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "A composable observatory for Niri."
                        color: Theme.muted
                        font.family: Theme.fontText
                        font.pixelSize: 13
                        lineHeight: 1.3
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                SectionTitle { title: "Launch coordinates"; detail: "" }
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 1
                    columnSpacing: 0
                    rowSpacing: 5
                    Repeater {
                        model: [root.modules[0], root.modules[1], root.modules[2], root.modules[3], root.modules[5], root.modules[9]]
                        Shared.SpectralAction {
                            id: quickCard
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            title: modelData.name
                            detail: modelData.detail
                            glyph: modelData.glyph
                            code: modelData.code
                            tone: Theme.moduleAccent(modelData.widget)
                            onActivated: root.openWidget(modelData.widget)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: modulesPage
        ColumnLayout {
            spacing: 10
            SectionTitle { title: "Interactive modules"; detail: "EVERY ACTIVE EPHEMERIS SURFACE // CLICK TO MORPH" }
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 3
                columnSpacing: 9
                rowSpacing: 9
                Repeater {
                    model: root.modules
                    Shared.SpectralAction {
                        id: moduleCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        title: modelData.name
                        detail: modelData.detail
                        glyph: modelData.glyph
                        code: modelData.code
                        tone: Theme.moduleAccent(modelData.widget)
                        onActivated: root.openWidget(modelData.widget)
                    }
                }
            }
        }
    }

    Component {
        id: controlsPage
        ColumnLayout {
            spacing: 10
            SectionTitle { title: "Niri flight controls"; detail: "WINDOWS-FAMILIAR BINDS // ASTRALITH ACTIONS" }
            Repeater {
                model: root.controls
                Rectangle {
                    id: controlRow
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusMedium
                    color: Theme.mantle
                    border.width: 0
                    border.color: Theme.line
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 16
                        Rectangle {
                            Layout.preferredWidth: 190
                            Layout.preferredHeight: 34
                            radius: Theme.radiusSmall
                            color: Theme.elevated
                            border.width: 0
                            border.color: Theme.lineBright
                            Text { anchors.centerIn: parent; text: controlRow.modelData.keys; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.6 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: controlRow.modelData.name; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 12; font.weight: Font.Bold }
                            Text { text: controlRow.modelData.detail; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 10 }
                        }
                        Text { text: "NIRI"; color: Theme.success; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1 }
                    }
                }
            }
        }
    }

    Component {
        id: parityPage
        ColumnLayout {
            spacing: 10
            SectionTitle { title: "Serpantinum port map"; detail: "FEATURE PARITY // REBUILT FOR NIRI // HYPRLAND UNTOUCHED" }
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                columnSpacing: 9
                rowSpacing: 9
                Repeater {
                    model: root.parity
                    Rectangle {
                        id: parityCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusMedium
                        color: Theme.mantle
                        border.width: 0
                        border.color: Qt.rgba(modelData.tone.r, modelData.tone.g, modelData.tone.b, 0.34)
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 11
                            Rectangle { Layout.preferredWidth: 7; Layout.fillHeight: true; radius: 4; color: parityCard.modelData.tone }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { Layout.fillWidth: true; text: parityCard.modelData.name; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 11; font.weight: Font.Bold; elide: Text.ElideRight }
                                Text { Layout.fillWidth: true; text: parityCard.modelData.detail; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 11; elide: Text.ElideRight }
                            }
                            Text { text: parityCard.modelData.state; color: parityCard.modelData.tone; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.8 }
                        }
                    }
                }
            }
        }
    }
}
