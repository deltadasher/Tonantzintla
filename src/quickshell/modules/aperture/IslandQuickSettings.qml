import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../components"
import "../../components/BarLayout.js" as BarLayout
import "../../services"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // Flipped once the window exists so the scrim and card animate in from the
    // island rather than snapping into place fully formed.
    property bool settled: false
    Component.onCompleted: root.settled = true

    readonly property bool isVertical: Settings.barPosition === "left" || Settings.barPosition === "right"
    readonly property bool isBottom: Settings.barPosition === "bottom"
    readonly property bool isRight: Settings.barPosition === "right"

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tonantzintla-island-popover"

    readonly property var currentLayout: {
        Settings.layoutRevision;
        return isVertical ? Settings.activeLayoutVertical : Settings.activeLayoutHorizontal;
    }
    readonly property var myLocation: ShellState.activeIslandSettingsId ? BarLayout.locate(currentLayout, ShellState.activeIslandSettingsId) : null

    readonly property var islandGlyphs: ({
        launcher: "⌕",
        workspaces: "⊞",
        media: "♫",
        window_title: "▭",
        clock: "◷",
        system_stats: "▤",
        status: "◉",
        tray: "⋯",
        controls: "⚙"
    })

    readonly property var islandTitles: ({
        launcher: "Launcher",
        workspaces: "Workspaces",
        media: "Resonance",
        window_title: "Focused window",
        clock: "Clock and calendar",
        system_stats: "System stats",
        status: "Status and controls",
        tray: "System tray",
        controls: "Quick controls"
    })

    readonly property real popoverX: {
        if (Settings.barPosition === "left") {
            return Math.min(root.width - card.width - 16, Math.max(16, ShellState.activeIslandGlobalX + ShellState.activeIslandWidth + 12));
        } else if (Settings.barPosition === "right") {
            return Math.max(16, ShellState.activeIslandGlobalX - card.width - 12);
        } else {
            const desiredX = ShellState.activeIslandGlobalX + (ShellState.activeIslandWidth - card.width) / 2;
            return Math.max(16, Math.min(root.width - card.width - 16, desiredX));
        }
    }

    readonly property real popoverY: {
        if (Settings.barPosition === "bottom") {
            return Math.max(16, ShellState.activeIslandGlobalY - card.height - 12);
        } else if (Settings.barPosition === "left" || Settings.barPosition === "right") {
            const desiredY = ShellState.activeIslandGlobalY + (ShellState.activeIslandHeight - card.height) / 2;
            return Math.max(16, Math.min(root.height - card.height - 16, desiredY));
        } else {
            return Math.max(48, Math.min(root.height - card.height - 16, ShellState.activeIslandGlobalY + ShellState.activeIslandHeight + 12));
        }
    }

    // Everything except the island being configured drops away, so the thing
    // under the cursor is the only thing still lit.
    FocusScrim {
        anchors.fill: parent
        focusX: ShellState.activeIslandGlobalX
        focusY: ShellState.activeIslandGlobalY
        focusWidth: ShellState.activeIslandWidth
        focusHeight: ShellState.activeIslandHeight
        focusRadius: Settings.compact ? 8 : 10
        dim: 0.62
        opacity: root.settled ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Settings.motion ? Theme.motionNormal : 0 }
        }
    }

    // Dismiss popover on outside click or right-click
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: ShellState.closeIslandSettings()
    }

    // Keyboard navigation: Esc exits
    Item {
        focus: true
        Keys.onEscapePressed: ShellState.closeIslandSettings()
    }

    // Main Popover Card
    Rectangle {
        id: card
        x: root.popoverX
        y: root.popoverY
        width: 308
        height: contentCol.implicitHeight + 24
        radius: 10
        color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.96)
        border.width: 0

        // Grows out of the island it belongs to, so the panel reads as coming
        // from the thing you pressed rather than appearing over it.
        opacity: root.settled ? 1 : 0
        scale: root.settled ? 1 : 0.92
        transformOrigin: root.isVertical
            ? (root.isRight ? Item.Right : Item.Left)
            : (root.isBottom ? Item.Bottom : Item.Top)
        Behavior on opacity {
            NumberAnimation { duration: Settings.motion ? Theme.motionFast : 0 }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Settings.motion ? Theme.motionNormal : 0
                easing.type: Easing.OutBack
                easing.overshoot: 1.1
            }
        }

        // Block clicks from passing to the dismissal backdrop
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) { mouse.accepted = true; }
        }

        // Ambient hairline
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 0
        }

        ColumnLayout {
            id: contentCol
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            spacing: 12

            // Header: Glyph, Title, and Close Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    visible: false
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 8
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                    border.width: 0
                    Text {
                        anchors.centerIn: parent
                        text: root.islandGlyphs[ShellState.activeIslandSettingsId] || "✦"
                        color: Theme.accent
                        font.pixelSize: 15
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: root.islandTitles[ShellState.activeIslandSettingsId] || "Widget settings"
                        color: Theme.moon
                        font.family: Theme.fontDisplay
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        visible: false
                        text: myLocation ? ("Located in " + myLocation.zone.toUpperCase() + " zone") : "Bar widget"
                        color: Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 6
                    color: closeHover.containsMouse ? Theme.controlDanger : Theme.controlRest
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: closeHover.containsMouse ? Theme.danger : Theme.muted
                        font.pixelSize: 14
                        font.bold: true
                    }
                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.closeIslandSettings()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.08)
            }

            // 1. CLOCK / CALENDAR SPECIFIC SETTINGS
            ColumnLayout {
                visible: ShellState.activeIslandSettingsId === "clock"
                Layout.fillWidth: true
                spacing: 8

                // 12h vs 24h switch
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Clock format"
                        color: Theme.moon
                        font.pixelSize: 12
                    }
                    Rectangle {
                        implicitWidth: 100
                        implicitHeight: 26
                        radius: 6
                        color: Theme.controlRest
                        border.width: 0
                        border.color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.12)
                        RowLayout {
                            anchors.fill: parent
                            spacing: 0
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 5
                                color: !Settings.clock12h ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : "transparent"
                                Text { anchors.centerIn: parent; text: "24h"; color: !Settings.clock12h ? Theme.accent : Theme.muted; font.pixelSize: 10; font.bold: true }
                                MouseArea { anchors.fill: parent; onClicked: Settings.clock12h = false }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 5
                                color: Settings.clock12h ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : "transparent"
                                Text { anchors.centerIn: parent; text: "12h"; color: Settings.clock12h ? Theme.accent : Theme.muted; font.pixelSize: 10; font.bold: true }
                                MouseArea { anchors.fill: parent; onClicked: Settings.clock12h = true }
                            }
                        }
                    }
                }

                // Seconds visibility
                RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: "Show seconds"; color: Theme.moon; font.pixelSize: 12 }
                    Rectangle {
                        implicitWidth: 44; implicitHeight: 22; radius: 11
                        color: Settings.showSeconds ? Theme.accent : Theme.controlRest
                        Rectangle {
                            x: Settings.showSeconds ? 24 : 2; y: 2; width: 18; height: 18; radius: 9
                            color: Settings.showSeconds ? Theme.void_ : Theme.muted
                            Behavior on x { NumberAnimation { duration: Settings.motion ? 150 : 0 } }
                        }
                        MouseArea { anchors.fill: parent; onClicked: Settings.showSeconds = !Settings.showSeconds }
                    }
                }

                // Show Date Toggle
                RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: "Show date"; color: Theme.moon; font.pixelSize: 12 }
                    Rectangle {
                        implicitWidth: 44; implicitHeight: 22; radius: 11
                        color: Settings.showDate ? Theme.accent : Theme.controlRest
                        Rectangle {
                            x: Settings.showDate ? 24 : 2; y: 2; width: 18; height: 18; radius: 9
                            color: Settings.showDate ? Theme.void_ : Theme.muted
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }
                        MouseArea { anchors.fill: parent; onClicked: Settings.showDate = !Settings.showDate }
                    }
                }

                // Weather Unit Toggle
                RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: "Weather"; color: Theme.moon; font.pixelSize: 12 }
                    Rectangle {
                        implicitWidth: 80; implicitHeight: 24; radius: 6
                        color: Theme.controlRest
                        border.width: 0
                        border.color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.12)
                        Text {
                            anchors.centerIn: parent
                            text: (Weather.available ? Weather.current.temp + " " : "") + Weather.unitSymbol
                            color: Theme.accent
                            font.pixelSize: 10
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Settings.temperatureUnit = (Settings.temperatureUnit === "celsius" ? "fahrenheit" : "celsius");
                            }
                        }
                    }
                }

                // Launch Full Ephemeris Calendar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 7
                    color: calBtnHover.containsMouse ? Theme.controlActive : Theme.controlRest
                    border.width: 0
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
                    Text {
                        anchors.centerIn: parent
                        text: "Open calendar"
                        color: Theme.accent
                        font.pixelSize: 11
                        font.bold: true
                    }
                    MouseArea {
                        id: calBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ShellState.closeIslandSettings();
                            ShellState.openEphemeris("calendar");
                        }
                    }
                }
            }

            // 2. STATUS / NOTIFICATIONS SPECIFIC SETTINGS
            ColumnLayout {
                visible: ShellState.activeIslandSettingsId === "status"
                Layout.fillWidth: true
                spacing: 8

                Text { text: "Shown in the bar"; color: Theme.muted; font.pixelSize: 10; font.bold: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 26; radius: 6
                        color: Settings.showBattery ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : Theme.controlRest
                        border.width: 0
                        Text { anchors.centerIn: parent; text: "BAT"; color: Settings.showBattery ? Theme.accent : Theme.muted; font.pixelSize: 10; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: Settings.showBattery = !Settings.showBattery }
                    }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 26; radius: 6
                        color: Settings.showBluetooth ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : Theme.controlRest
                        border.width: 0
                        Text { anchors.centerIn: parent; text: "BT"; color: Settings.showBluetooth ? Theme.accent : Theme.muted; font.pixelSize: 10; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: Settings.showBluetooth = !Settings.showBluetooth }
                    }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 26; radius: 6
                        color: Settings.showMicrophone ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : Theme.controlRest
                        border.width: 0
                        Text { anchors.centerIn: parent; text: "MIC"; color: Settings.showMicrophone ? Theme.accent : Theme.muted; font.pixelSize: 10; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: Settings.showMicrophone = !Settings.showMicrophone }
                    }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 26; radius: 6
                        color: Settings.showBrightness ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : Theme.controlRest
                        border.width: 0
                        Text { anchors.centerIn: parent; text: "LUX"; color: Settings.showBrightness ? Theme.accent : Theme.muted; font.pixelSize: 10; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: Settings.showBrightness = !Settings.showBrightness }
                    }
                }

                // Quick Volume Nudge
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "VOL: " + Math.round(Audio.volume * 100) + "%"; color: Theme.moon; font.pixelSize: 11; font.family: Theme.fontMono }
                    Rectangle {
                        implicitWidth: 36; implicitHeight: 22; radius: 5
                        color: Theme.controlRest
                        Text { anchors.centerIn: parent; text: "-5%"; color: Theme.accent; font.pixelSize: 10 }
                        MouseArea { anchors.fill: parent; onClicked: Audio.change(-5) }
                    }
                    Rectangle {
                        implicitWidth: 36; implicitHeight: 22; radius: 5
                        color: Theme.controlRest
                        Text { anchors.centerIn: parent; text: "+5%"; color: Theme.accent; font.pixelSize: 10 }
                        MouseArea { anchors.fill: parent; onClicked: Audio.change(5) }
                    }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 22; radius: 5
                        color: Audio.muted ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.25) : Theme.controlRest
                        Text { anchors.centerIn: parent; text: Audio.muted ? "MUTED" : "MUTE"; color: Audio.muted ? Theme.danger : Theme.muted; font.pixelSize: 10 }
                        MouseArea { anchors.fill: parent; onClicked: Audio.toggleMute() }
                    }
                }

                // Launch Quick Settings Hub
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 7
                    color: sysBtnHover.containsMouse ? Theme.controlActive : Theme.controlRest
                    border.width: 0
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
                    Text {
                        anchors.centerIn: parent
                        text: "Open system settings"
                        color: Theme.accent
                        font.pixelSize: 11
                        font.bold: true
                    }
                    MouseArea {
                        id: sysBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ShellState.closeIslandSettings();
                            ShellState.openEphemeris("system");
                        }
                    }
                }
            }

            // SYSTEM TELEMETRY SPECIFIC SETTINGS
            ColumnLayout {
                visible: ShellState.activeIslandSettingsId === "system_stats"
                Layout.fillWidth: true
                spacing: 8

                Text { text: "Telemetry channels"; color: Theme.muted; font.pixelSize: 10; font.bold: true }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: [
                            { key: "showSystemStats", label: "CPU / MEM / GPU" },
                            { key: "showAudio", label: "Volume" }
                        ]
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; implicitHeight: 28; radius: 6
                            color: Settings[modelData.key] ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : Theme.controlRest
                            Text { anchors.centerIn: parent; text: modelData.label; color: Settings[modelData.key] ? Theme.accent : Theme.muted; font.pixelSize: 9; font.bold: true }
                            MouseArea { anchors.fill: parent; onClicked: Settings[modelData.key] = !Settings[modelData.key] }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 30; radius: 7
                    color: telemetryBtn.containsMouse ? Theme.controlActive : Theme.controlRest
                    Text { anchors.centerIn: parent; text: "Open full telemetry"; color: Theme.accent; font.pixelSize: 11; font.bold: true }
                    MouseArea { id: telemetryBtn; anchors.fill: parent; hoverEnabled: true; onClicked: { ShellState.closeIslandSettings(); ShellState.openEphemeris("system"); } }
                }
            }

            // 3. MEDIA SPECIFIC SETTINGS
            ColumnLayout {
                visible: ShellState.activeIslandSettingsId === "media"
                Layout.fillWidth: true
                // Resonance presentation controls
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Repeater {
                        model: [
                            { key: "showMedia", label: "Show in bar" },
                            { key: "showMediaProgress", label: "Progress bar" },
                            { key: "showMediaTime", label: "Elapsed time" }
                        ]
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: modelData.label; color: Theme.moon; font.pixelSize: 12 }
                            Rectangle {
                                implicitWidth: 44; implicitHeight: 22; radius: 11
                                color: Settings[modelData.key] ? Theme.accent : Theme.controlRest
                                Rectangle {
                                    x: Settings[modelData.key] ? 24 : 2; y: 2; width: 18; height: 18; radius: 9
                                    color: Settings[modelData.key] ? Theme.void_ : Theme.muted
                                    Behavior on x { NumberAnimation { duration: Settings.motion ? 150 : 0 } }
                                }
                                MouseArea { anchors.fill: parent; onClicked: Settings[modelData.key] = !Settings[modelData.key] }
                            }
                        }
                    }
                }

                spacing: 8

                Text {
                    text: Media.available ? (Media.title + " — " + Media.artist) : "No Active Media Player"
                    color: Theme.moon
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 28; radius: 6
                        color: Theme.controlRest
                        Text { anchors.centerIn: parent; text: "⏮ Prev"; color: Theme.moon; font.pixelSize: 11 }
                        MouseArea { anchors.fill: parent; onClicked: if (Media.player) Media.player.previous() }
                    }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 28; radius: 6
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                        border.width: 0
                        Text { anchors.centerIn: parent; text: Media.playing ? "⏸ Pause" : "▶ Play"; color: Theme.accent; font.pixelSize: 11; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: if (Media.player) Media.player.togglePlaying() }
                    }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 28; radius: 6
                        color: Theme.controlRest
                        Text { anchors.centerIn: parent; text: "⏭ Next"; color: Theme.moon; font.pixelSize: 11 }
                        MouseArea { anchors.fill: parent; onClicked: if (Media.player) Media.player.next() }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 30; radius: 7
                    color: mediaBtnHover.containsMouse ? Theme.controlActive : Theme.controlRest
                    border.width: 0
                    Text { anchors.centerIn: parent; text: "Open Resonance"; color: Theme.accent; font.pixelSize: 11; font.bold: true }
                    MouseArea {
                        id: mediaBtnHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { ShellState.closeIslandSettings(); ShellState.openEphemeris("media"); }
                    }
                }
            }

            // 4. WORKSPACES SPECIFIC SETTINGS
            ColumnLayout {
                visible: ShellState.activeIslandSettingsId === "workspaces"
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 30; radius: 7
                    color: wsBtnHover.containsMouse ? Theme.controlActive : Theme.controlRest
                    border.width: 0
                    Text { anchors.centerIn: parent; text: "Open workspaces"; color: Theme.accent; font.pixelSize: 11; font.bold: true }
                    MouseArea {
                        id: wsBtnHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { ShellState.closeIslandSettings(); ShellState.openEphemeris("workspaces"); }
                    }
                }
            }

            // 5. OTHER ISLANDS (Generic Launchers)
            ColumnLayout {
                visible: ["clock", "status", "media", "workspaces"].indexOf(ShellState.activeIslandSettingsId) === -1
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: "Quickly manage this widget placement or configure the Aperture bar below."
                    color: Theme.muted
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.08)
            }

            // Universal Zone Transfer: Start, Center, End
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text { text: "Position in bar"; color: Theme.muted; font.pixelSize: 10; font.bold: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 28; radius: 6
                        color: (myLocation && myLocation.zone === "start") ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24) : Theme.controlRest
                        border.width: 0
                        Text { anchors.centerIn: parent; text: "◀ Start"; color: (myLocation && myLocation.zone === "start") ? Theme.accent : Theme.moon; font.pixelSize: 10; font.bold: true }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (myLocation && myLocation.zone !== "start") {
                                    Settings.transferIsland(root.isVertical, myLocation.zone, "start", ShellState.activeIslandSettingsId);
                                    ShellState.closeIslandSettings();
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 28; radius: 6
                        color: (myLocation && myLocation.zone === "center") ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24) : Theme.controlRest
                        border.width: 0
                        Text { anchors.centerIn: parent; text: "◉ Center"; color: (myLocation && myLocation.zone === "center") ? Theme.accent : Theme.moon; font.pixelSize: 10; font.bold: true }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (myLocation && myLocation.zone !== "center") {
                                    Settings.transferIsland(root.isVertical, myLocation.zone, "center", ShellState.activeIslandSettingsId);
                                    ShellState.closeIslandSettings();
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 28; radius: 6
                        color: (myLocation && myLocation.zone === "end") ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24) : Theme.controlRest
                        border.width: 0
                        Text { anchors.centerIn: parent; text: "▶ End"; color: (myLocation && myLocation.zone === "end") ? Theme.accent : Theme.moon; font.pixelSize: 10; font.bold: true }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (myLocation && myLocation.zone !== "end") {
                                    Settings.transferIsland(root.isVertical, myLocation.zone, "end", ShellState.activeIslandSettingsId);
                                    ShellState.closeIslandSettings();
                                }
                            }
                        }
                    }
                }
            }

            // Action Row: Bar Positioning Mode & Remove
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 7
                    color: editModeBtnHover.containsMouse ? Theme.controlActive : Theme.controlRest
                    border.width: 0
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.32)
                    Text {
                        anchors.centerIn: parent
                        text: "Move and arrange"
                        color: Theme.accent
                        font.pixelSize: 10
                        font.bold: true
                    }
                    MouseArea {
                        id: editModeBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ShellState.enterBarEditMode();
                        }
                    }
                }

                Rectangle {
                    implicitWidth: 78
                    implicitHeight: 30
                    radius: 7
                    color: removeBtnHover.containsMouse ? Theme.controlDanger : Theme.controlRest
                    border.width: 0
                    border.color: removeBtnHover.containsMouse ? Theme.danger : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.12)
                    Text {
                        anchors.centerIn: parent
                        text: "✕ Remove"
                        color: removeBtnHover.containsMouse ? Theme.danger : Theme.muted
                        font.pixelSize: 10
                        font.bold: true
                    }
                    MouseArea {
                        id: removeBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Settings.removeIslandFromLayout(root.isVertical, ShellState.activeIslandSettingsId);
                            ShellState.closeIslandSettings();
                        }
                    }
                }
            }
        }
    }
}
