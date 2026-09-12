import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../components"
import "../../components/BarLayout.js" as BarLayout
import "islands"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property string outputName: modelData ? modelData.name : ""
    visible: !ShellState.islandSettingsVisible

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "tonantzintla-bar-studio"
    anchors { top: true; bottom: true; left: true; right: true }

    // The studio is visually fullscreen, but only its two edge instruments
    // accept input. The live Aperture bar remains directly draggable.
    mask: Region {
        Region { item: bottomDrawer }
        Region { item: sideDrawer }
        Region { item: sideToggle }
    }

    readonly property string currentEdge: Settings.getEffectiveBarPosition(outputName)
    readonly property bool isVertical: currentEdge === "left" || currentEdge === "right"
    // Matches the real bar so the undimmed strip lands exactly on it. Mirrors
    // the island sizing in components/BarIsland.qml, plus its bar padding.
    readonly property real barThickness: (isVertical
        ? (Settings.compact ? 42 : 46)
        : (Settings.compact ? 36 : Theme.barHeight)) + 8
    readonly property var currentLayout: {
        Settings.layoutRevision;
        return Settings.getEdgeBarLayout(outputName, currentEdge);
    }
    readonly property string rawLayout: isVertical ? Settings.barLayoutVertical : Settings.barLayoutHorizontal

    property string activeTab: "shelf" // "colors", "position", "presets", "shelf"
    property bool bottomDrawerRevealed: false
    // Keep the canvas calm by default. Advanced spacing controls are opt-in
    // through the small handle instead of competing with the bar.
    property bool sideDrawerOpen: false
    property string toastText: "Drag islands on the bar to move them · Esc to finish"
    property string undoLayout: ""
    property string undoPlacements: ""
    property bool hasUndo: false

    Component.onCompleted: {
        bottomDrawerRevealed = true;
        sideDrawerOpen = true;
    }

    readonly property var catalog: [
        { id: "launcher",     name: "Launcher",     glyph: "⌕", desc: "Search and run apps" },
        { id: "workspaces",   name: "Workspaces",   glyph: "⊞", desc: "Niri workspace indicators" },
        { id: "media",        name: "Media Player", glyph: "♫", desc: "Now playing and controls" },
        { id: "window_title", name: "Window Title", glyph: "▭", desc: "Active focused application" },
        { id: "clock",        name: "Clock & Date", glyph: "◷", desc: "Clock and calendar" },
        { id: "system_stats", name: "System Stats", glyph: "▤", desc: "Processor, memory, and temperature" },
        { id: "status",       name: "Status Array", glyph: "◉", desc: "Battery, network, Bluetooth, brightness" },
        { id: "tray",         name: "System Tray",  glyph: "⋯", desc: "StatusNotifier tray icons" },
        { id: "controls",     name: "Controls",     glyph: "⚙", desc: "Quick actions and lock" }
    ]

    readonly property var colorSwatches: [
        { id: "violet",  name: "Violet",  hex: "#a99cff" },
        { id: "cyan",    name: "Cyan",   hex: "#72d9e7" },
        { id: "rose",    name: "Rose",    hex: "#ec8eae" },
        { id: "amber",   name: "Amber",    hex: "#e9b872" },
        { id: "emerald", name: "Emerald", hex: "#77d6ae" },
        { id: "solar",   name: "Ember",    hex: "#ff9e64" },
        { id: "silver",  name: "Silver", hex: "#d4d8e8" }
    ]

    function rememberUndo() {
        undoLayout = rawLayout;
        undoPlacements = Settings.barIslandPlacements;
        hasUndo = true;
    }

    function applyUndo() {
        if (!hasUndo) return;
        if (isVertical) Settings.barLayoutVertical = undoLayout;
        else Settings.barLayoutHorizontal = undoLayout;
        Settings.barIslandPlacements = undoPlacements;
        hasUndo = false;
        showToast("Layout reverted");
    }

    function exitStudio() {
        ShellState.exitBarEditMode();
    }

    function showToast(msg) {
        toastText = msg;
        toastTimer.restart();
    }

    function addIsland(zone, id) {
        rememberUndo();
        Settings.clearIslandPlacement(outputName, id);
        Settings.addIslandToZone(isVertical, zone, id);
        showToast("Added " + id + " to " + zone);
    }

    function removeIsland(id) {
        rememberUndo();
        Settings.clearIslandPlacement(outputName, id);
        Settings.removeIslandFromLayout(isVertical, id);
        showToast("Removed " + id);
    }

    function moveIsland(zone, fromIdx, toIdx) {
        rememberUndo();
        Settings.moveIsland(isVertical, zone, fromIdx, toIdx);
    }

    function transferIsland(fromZone, toZone, id) {
        rememberUndo();
        Settings.clearIslandPlacement(outputName, id);
        Settings.transferIsland(isVertical, fromZone, toZone, id);
        showToast("Moved " + id + " to " + toZone);
    }

    function applyPresetLayout(preset) {
        rememberUndo();
        Settings.clearIslandPlacement(outputName, "");
        const layoutObj = {
            start: preset.start.slice(),
            center: preset.center.slice(),
            end: preset.end.slice()
        };
        Settings.saveBarLayout(false, layoutObj);
        Settings.saveBarLayout(true, layoutObj);
        showToast("Applied " + preset.name);
    }

    function resetLayout() {
        rememberUndo();
        Settings.clearIslandPlacement(outputName, "");
        Settings.resetBarLayout(isVertical);
        showToast("Reset to default profile");
    }

    // Keyboard controls
    Item {
        focus: true
        Keys.onEscapePressed: root.exitStudio()
        Keys.onTabPressed: root.sideDrawerOpen = !root.sideDrawerOpen
        Keys.onPressed: function(event) {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
                root.applyUndo();
                event.accepted = true;
            } else if (event.key === Qt.Key_1) {
                root.activeTab = "colors";
                event.accepted = true;
            } else if (event.key === Qt.Key_2) {
                root.activeTab = "position";
                event.accepted = true;
            } else if (event.key === Qt.Key_3) {
                root.activeTab = "presets";
                event.accepted = true;
            } else if (event.key === Qt.Key_4) {
                root.activeTab = "shelf";
                event.accepted = true;
            }
        }
    }

    // The bar stays lit and everything else falls away, so positioning happens
    // against the real desktop instead of a flat sheet of dimming.
    FocusScrim {
        id: backdrop
        anchors.fill: parent
        focusX: root.isVertical
            ? (Settings.barPosition === "right" ? root.width - root.barThickness : 0)
            : 0
        focusY: root.isVertical
            ? 0
            : (Settings.barPosition === "bottom" ? root.height - root.barThickness : 0)
        focusWidth: root.isVertical ? root.barThickness : root.width
        focusHeight: root.isVertical ? root.height : root.barThickness
        focusRadius: 0
        halo: 0
        // Editing happens over the real desktop. Only the two instruments paint;
        // the canvas between them remains genuinely transparent.
        dim: 0.0

    }

    QtObject {
        id: proxyBarContext
        readonly property string effectivePosition: ShellState.dragHoverEdge || ShellState.dragSourceEdge
        readonly property bool isVertical: effectivePosition === "left" || effectivePosition === "right"
        readonly property var activeLayout: Settings.getEdgeBarLayout(root.outputName, effectivePosition)
        readonly property string outputName: root.outputName
        readonly property real width: root.width
        readonly property real height: root.height
        readonly property real leftReveal: 1
        readonly property real workspaceReveal: 1
        readonly property real mediaReveal: 1
        readonly property real centerReveal: 1
        readonly property real systemReveal: 1
        readonly property real rightReveal: 1
    }

    // A second live host—not a label or screenshot—reflows the actual island
    // for whichever edge is currently under the pointer.
    Item {
        id: dragProxy
        z: 900
        visible: ShellState.isDraggingIsland || ShellState.dropAnimating
            && (ShellState.dragSourceOutput === "" || ShellState.dragSourceOutput === root.outputName)
        x: (ShellState.dropAnimating ? ShellState.dropFlightX : ShellState.dragScreenX) - width / 2
        y: (ShellState.dropAnimating ? ShellState.dropFlightY : ShellState.dragScreenY) - height / 2
        width: proxyHost.width
        height: proxyHost.height
        rotation: Math.max(-4.5, Math.min(4.5, ShellState.dragVelocityX * 0.12))
        scale: 1 + Math.min(0.045, Math.sqrt(ShellState.dragVelocityX * ShellState.dragVelocityX
            + ShellState.dragVelocityY * ShellState.dragVelocityY) * 0.0014)

        Behavior on x { SmoothedAnimation { velocity: 3200; duration: 82 } }
        Behavior on y { SmoothedAnimation { velocity: 3200; duration: 82 } }
        Behavior on rotation { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

        IslandHost {
        id: proxyHost
        anchors.centerIn: parent
            islandId: ShellState.dropAnimating ? ShellState.dropFlightIslandId : ShellState.draggedIslandId
            outputName: root.outputName
            barWindow: proxyBarContext
        }
    }

    // One edge-attached landing tongue replaces the old cursor circle/tether.
    // Its location communicates both the chosen edge and aligned third.
    Rectangle {
        id: edgeLanding
        z: 850
        visible: ShellState.isDraggingIsland
        readonly property bool vertical: ShellState.dragHoverEdge === "left"
            || ShellState.dragHoverEdge === "right"
        readonly property real zoneCenter: ShellState.dragHoverZone === "start" ? 1 / 6
            : ShellState.dragHoverZone === "end" ? 5 / 6 : 0.5
        width: vertical ? 10 : Math.min(150, root.width / 7)
        height: vertical ? Math.min(150, root.height / 7) : 10
        x: ShellState.dragHoverEdge === "left" ? 0
            : ShellState.dragHoverEdge === "right" ? root.width - width
            : root.width * zoneCenter - width / 2
        y: ShellState.dragHoverEdge === "top" ? 0
            : ShellState.dragHoverEdge === "bottom" ? root.height - height
            : root.height * zoneCenter - height / 2
        radius: 6
        color: Theme.accent
        opacity: 0.7

        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    Timer {
        id: dropFlightTimer
        interval: 240
        running: ShellState.dropAnimating
        onTriggered: ShellState.dropAnimating = false
    }

    // Toast pill for user feedback
    Rectangle {
        id: toastPill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: isVertical ? 24 : (Settings.barPosition === "top" ? 82 : 24)
        implicitWidth: toastLabel.implicitWidth + 28
        implicitHeight: 32
        radius: 8
        color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.94)
        border.width: 0
        border.color: Theme.accent
        opacity: 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        RowLayout {
            anchors.centerIn: parent
            spacing: 6
            Text { text: "✦"; color: Theme.accent; font.pixelSize: 11; font.bold: true }
            Text {
                id: toastLabel
                text: root.toastText
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 11
                font.bold: true
            }
        }

        Timer {
            id: toastTimer
            interval: 2200
            running: true
            repeat: false
        }
    }

    // =========================================================================
    // BOTTOM DRAWER: THEMES, PRESETS, AND BAR POSITION
    // =========================================================================
    Item {
        id: bottomDrawer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomDrawerRevealed ? 0 : -height
        width: Math.min(1080, parent.width - (root.sideDrawerOpen ? 310 : 48))
        height: 310

        EdgeFluidSurface {
            anchors.fill: parent
            edge: "bottom"
            reveal: root.bottomDrawerRevealed ? 1 : 0
            energy: ShellState.isDraggingIsland ? ShellState.dragVelocityY * 0.04 : 0
            cursorAlong: ShellState.isDraggingIsland && root.width > 0
                ? ShellState.dragScreenX / root.width : 0.47
            fillColor: Theme.mantle
        }

        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 380; easing.type: Easing.OutBack }
        }
        Behavior on width {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        // Catch clicks so clicking drawer body does not close edit mode
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) { mouse.accepted = true; }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            anchors.topMargin: 38
            anchors.bottomMargin: 16
            spacing: 12

            // Header Bar & Navigation Tabs
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                RowLayout {
                    spacing: 6
                    Rectangle {
                        implicitWidth: 20; implicitHeight: 20; radius: 5
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                        Text { anchors.centerIn: parent; text: "✦"; color: Theme.accent; font.pixelSize: 11; font.bold: true }
                    }
                    Text {
                        text: "BAR STUDIO"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 13
                        font.bold: true
                        font.letterSpacing: 1.2
                    }
                }

                Item { Layout.fillWidth: true }

                // Mode Tabs
                RowLayout {
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "colors",   label: "Appearance" },
                            { id: "position", label: "Position" },
                            { id: "presets",  label: "Layouts" },
                            { id: "shelf",    label: "Islands" }
                        ]

                        Rectangle {
                            implicitWidth: tabText.implicitWidth + 20
                            implicitHeight: 28
                            radius: 7
                            color: root.activeTab === modelData.id
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                                : (tabH.containsMouse ? Theme.controlActive : Theme.controlRest)
                            border.width: 0

                            Text {
                                id: tabText
                                anchors.centerIn: parent
                                text: modelData.label
                                color: root.activeTab === modelData.id ? Theme.accent : Theme.moon
                                font.family: Theme.fontDisplay
                                font.pixelSize: 11
                                font.bold: root.activeTab === modelData.id
                            }

                            MouseArea {
                                id: tabH
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeTab = modelData.id
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Done Button
                Rectangle {
                    implicitWidth: 82; implicitHeight: 30; radius: 15
                    color: doneH.containsMouse ? Theme.accent : Theme.controlRest
                    border.width: 0

                    Text {
                        anchors.centerIn: parent
                        text: "Done"
                        color: doneH.containsMouse ? Theme.void_ : Theme.accent
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: doneH
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.exitStudio()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.08)
            }

            // Tab Pages Container
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ==========================================
                // PAGE 1: COLORS & THEMES
                // ==========================================
                Item {
                    anchors.fill: parent
                    visible: root.activeTab === "colors"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12

                        // Accent Swatches
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "Accent color"
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.bold: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Repeater {
                                    model: root.colorSwatches

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 52
                                        radius: 10
                                        color: Settings.accentName === modelData.id
                                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                                            : (colorHover.containsMouse ? Theme.controlActive : Theme.controlRest)
                                        border.width: 0
                                        border.color: Settings.accentName === modelData.id ? modelData.hex : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.12)

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 8

                                            Rectangle {
                                                implicitWidth: 20; implicitHeight: 20; radius: 10
                                                color: modelData.hex
                                                border.width: 0
                                            }

                                            ColumnLayout {
                                                spacing: 1
                                                Text {
                                                    text: modelData.name
                                                    color: Settings.accentName === modelData.id ? Theme.moon : Theme.muted
                                                    font.pixelSize: 10
                                                    font.bold: Settings.accentName === modelData.id
                                                }
                                                Text {
                                                    text: modelData.id.toUpperCase()
                                                    color: Theme.muted
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: 8
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: colorHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Settings.accentName = modelData.id;
                                                root.showToast("Accent shifted to " + modelData.name);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Desktop Presets Row (Serpantinum, Caelestia, Solaris, etc.)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "Appearance presets"
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.bold: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: [
                                        { id: "serpantinum", name: "Serpantinum", desc: "Violet • Top • Capsules • Fluid" },
                                        { id: "caelestia",   name: "Caelestia",   desc: "Cyan • Left • Rail • Snappy" },
                                        { id: "solaris",     name: "Solaris",     desc: "Amber • Bottom • Docked" },
                                        { id: "cyberpunk",   name: "Cyberpunk",   desc: "Rose • Right • Instant" },
                                        { id: "minimalist",  name: "Zen Float",   desc: "Silver • Top • Minimal" }
                                    ]

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 46
                                        radius: 8
                                        color: themeBtnH.containsMouse ? Theme.controlActive : Theme.controlRest
                                        border.width: 0
                                        border.color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.12)

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 1
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: modelData.name
                                                color: Theme.moon
                                                font.pixelSize: 11
                                                font.bold: true
                                            }
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: modelData.desc
                                                color: Theme.accent
                                                font.pixelSize: 8
                                            }
                                        }

                                        MouseArea {
                                            id: themeBtnH
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Settings.applyDesktopPreset(modelData.id);
                                                root.showToast("Applied " + modelData.name + " theme profile");
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // PAGE 2: POSITION & EDGE
                // ==========================================
                Item {
                    anchors.fill: parent
                    visible: root.activeTab === "position"

                    RowLayout {
                        anchors.fill: parent
                        spacing: 16

                        // 4-Way Compass Edge Selector
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: "Bar position"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10; font.bold: true }

                            GridLayout {
                                columns: 2
                                rowSpacing: 8
                                columnSpacing: 8
                                Layout.fillWidth: true

                                Repeater {
                                    model: [
                                        { id: "top",    name: "↑ Top Screen Edge" },
                                        { id: "bottom", name: "↓ Bottom Screen Edge" },
                                        { id: "left",   name: "← Left Screen Edge" },
                                        { id: "right",  name: "→ Right Screen Edge" }
                                    ]

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 40; radius: 8
                                        color: Settings.barPosition === modelData.id
                                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24)
                                            : (edgeH.containsMouse ? Theme.controlActive : Theme.controlRest)
                                        border.width: 0
                                        border.color: Settings.barPosition === modelData.id ? Theme.accent : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.12)

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.name
                                            color: Settings.barPosition === modelData.id ? Theme.accent : Theme.moon
                                            font.pixelSize: 11
                                            font.bold: Settings.barPosition === modelData.id
                                        }

                                        MouseArea {
                                            id: edgeH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Settings.barPosition = modelData.id;
                                                root.showToast("Bar docked to " + modelData.id);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Presentation & Density Modes
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: "PRESENTATION & DENSITY"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10; font.bold: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 40; radius: 8
                                    color: Settings.barMode === "capsules" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24) : Theme.controlRest
                                    border.width: 0
                                    border.color: Settings.barMode === "capsules" ? Theme.accent : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.12)
                                    ColumnLayout {
                                        anchors.centerIn: parent; spacing: 1
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Capsules (Islands)"; color: Theme.moon; font.pixelSize: 11; font.bold: true }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Individual floating modules"; color: Theme.muted; font.pixelSize: 9 }
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: Settings.barMode = "capsules" }
                                }

                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 40; radius: 8
                                    color: Settings.barMode === "docked" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24) : Theme.controlRest
                                    border.width: 0
                                    border.color: Settings.barMode === "docked" ? Theme.accent : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.12)
                                    ColumnLayout {
                                        anchors.centerIn: parent; spacing: 1
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Docked Rail"; color: Theme.moon; font.pixelSize: 11; font.bold: true }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Continuous edge bar"; color: Theme.muted; font.pixelSize: 9 }
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: Settings.barMode = "docked" }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 40; radius: 8
                                    color: !Settings.compact ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24) : Theme.controlRest
                                    border.width: 0
                                    border.color: !Settings.compact ? Theme.accent : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.12)
                                    Text { anchors.centerIn: parent; text: "Cozy Height (48px)"; color: !Settings.compact ? Theme.accent : Theme.moon; font.pixelSize: 11; font.bold: true }
                                    MouseArea { anchors.fill: parent; onClicked: { Settings.compact = false; Settings.barHeightProfile = "nominal"; } }
                                }

                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 40; radius: 8
                                    color: Settings.compact ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24) : Theme.controlRest
                                    border.width: 0
                                    border.color: Settings.compact ? Theme.accent : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.12)
                                    Text { anchors.centerIn: parent; text: "Compact Height (36px)"; color: Settings.compact ? Theme.accent : Theme.moon; font.pixelSize: 11; font.bold: true }
                                    MouseArea { anchors.fill: parent; onClicked: { Settings.compact = true; Settings.barHeightProfile = "compact"; } }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // PAGE 3: PRESETS
                // ==========================================
                Item {
                    anchors.fill: parent
                    visible: root.activeTab === "presets"

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        Repeater {
                            model: [
                                {
                                    name: "Tonantzintla Signature",
                                    desc: "Apps, music, system stats, and the clock, evenly weighted.",
                                    start: ["launcher", "workspaces"],
                                    center: ["clock", "media"],
                                    end: ["system_stats", "status", "controls"]
                                },
                                {
                                    name: "Minimalist Zen",
                                    desc: "Clean, zero-distraction layout with clock, workspaces, and status.",
                                    start: ["launcher"],
                                    center: ["workspaces"],
                                    end: ["clock", "status"]
                                },
                                {
                                    name: "Media Focus",
                                    desc: "Audiophile setup keeping resonance playback front and center.",
                                    start: ["launcher", "workspaces"],
                                    center: ["media"],
                                    end: ["status", "clock"]
                                },
                                {
                                    name: "Everything",
                                    desc: "Every widget turned on at once.",
                                    start: ["launcher", "workspaces", "window_title"],
                                    center: ["media"],
                                    end: ["system_stats", "status", "clock", "tray", "controls"]
                                }
                            ]

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 10
                                color: presetH.containsMouse ? Theme.controlActive : Theme.controlRest
                                border.width: 0
                                border.color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.12)

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6

                                    Text {
                                        text: modelData.name
                                        color: Theme.moon
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    Text {
                                        text: modelData.desc
                                        color: Theme.muted
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }

                                    Item { Layout.fillHeight: true }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 28; radius: 6
                                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                                        border.width: 0
                                        Text { anchors.centerIn: parent; text: "Apply Layout"; color: Theme.accent; font.pixelSize: 10; font.bold: true }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.applyPresetLayout(modelData)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: presetH; anchors.fill: parent; hoverEnabled: true
                                    onClicked: root.applyPresetLayout(modelData)
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // PAGE 4: ISLAND SHELF
                // ==========================================
                Item {
                    anchors.fill: parent
                    visible: root.activeTab === "shelf"

                    GridLayout {
                        anchors.fill: parent
                        columns: 3
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: root.catalog

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 8
                                color: Theme.controlRest
                                border.width: 0
                                border.color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.1)

                                readonly property var loc: BarLayout.locate(root.currentLayout, modelData.id)
                                readonly property var placement: Settings.getIslandPlacement(root.outputName, modelData.id)
                                readonly property string effectiveZone: placement && placement.zone
                                    ? placement.zone : loc ? loc.zone : ""

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8

                                    Text { text: modelData.glyph; color: Theme.accent; font.pixelSize: 14; font.bold: true }

                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 1
                                        Text { text: modelData.name; color: Theme.moon; font.pixelSize: 11; font.bold: true }
                                        Text {
                                            text: placement
                                                ? ((placement.edge || Settings.barPosition).toUpperCase()
                                                    + " · " + (placement.zone || (loc ? loc.zone : "start")).toUpperCase())
                                                : loc ? (Settings.barPosition.toUpperCase() + " · " + loc.zone.toUpperCase())
                                                    : "Not in bar"
                                            color: loc ? Theme.accent : Theme.muted
                                            font.pixelSize: 9
                                        }
                                    }

                                    // Quick zone add / remove
                                    RowLayout {
                                        Layout.preferredWidth: 64
                                        Layout.minimumWidth: 64
                                        Layout.maximumWidth: 64
                                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                        spacing: 3
                                    // A widget is either spawned once or removed; placement happens by dragging.
                                    Rectangle {
                                        visible: loc === null
                                        implicitWidth: 64; implicitHeight: 22; radius: 5
                                        color: Theme.accent
                                        Text { anchors.centerIn: parent; text: "Spawn"; color: Theme.void_; font.pixelSize: 9; font.bold: true }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.addIsland("start", modelData.id)
                                        }
                                    }
                                        Rectangle {
                                            visible: false
                                            implicitWidth: 0; implicitHeight: 0; radius: 4
                                            color: effectiveZone === "start" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3) : Theme.controlRest
                                            border.width: 0
                                            Text { anchors.centerIn: parent; text: "S"; color: Theme.moon; font.pixelSize: 9; font.bold: true }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (loc) root.transferIsland(loc.zone, "start", modelData.id);
                                                    else root.addIsland("start", modelData.id);
                                                }
                                            }
                                        }
                                        Rectangle {
                                            visible: false
                                            implicitWidth: 0; implicitHeight: 0; radius: 4
                                            color: effectiveZone === "center" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3) : Theme.controlRest
                                            border.width: 0
                                            Text { anchors.centerIn: parent; text: "C"; color: Theme.moon; font.pixelSize: 9; font.bold: true }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (loc) root.transferIsland(loc.zone, "center", modelData.id);
                                                    else root.addIsland("center", modelData.id);
                                                }
                                            }
                                        }
                                        Rectangle {
                                            visible: false
                                            implicitWidth: 0; implicitHeight: 0; radius: 4
                                            color: effectiveZone === "end" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3) : Theme.controlRest
                                            border.width: 0
                                            Text { anchors.centerIn: parent; text: "E"; color: Theme.moon; font.pixelSize: 9; font.bold: true }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (loc) root.transferIsland(loc.zone, "end", modelData.id);
                                                    else root.addIsland("end", modelData.id);
                                                }
                                            }
                                        }
                                        Rectangle {
                                            visible: loc !== null
                                            Layout.alignment: Qt.AlignRight
                                            implicitWidth: 22; implicitHeight: 22; radius: 4
                                            color: Theme.controlDanger
                                            Text { anchors.centerIn: parent; text: "×"; color: Theme.danger; font.pixelSize: 11; font.bold: true }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: root.removeIsland(modelData.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // SIDE DRAWER ("Sett.") as drawn in user sketch
    // =========================================================================
    Item {
        id: sideDrawer
        anchors.right: parent.right
        anchors.rightMargin: root.sideDrawerOpen ? 0 : -width + 12
        anchors.verticalCenter: parent.verticalCenter
        width: 292
        height: 300

        EdgeFluidSurface {
            anchors.fill: parent
            edge: "right"
            reveal: root.sideDrawerOpen ? 1 : 0
            energy: ShellState.isDraggingIsland ? ShellState.dragVelocityX * 0.04 : 0
            cursorAlong: ShellState.isDraggingIsland && root.height > 0
                ? ShellState.dragScreenY / root.height : 0.44
            fillColor: Theme.mantle
        }

        Behavior on anchors.rightMargin {
            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
        }

        // Catch clicks so clicking side drawer does not close edit mode
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) { mouse.accepted = true; }
        }

        // Toggle Handle Tab on the left edge of drawer
        Rectangle {
            id: sideToggle
            anchors.right: parent.left
            anchors.rightMargin: -20
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 76
            radius: 8
            color: Theme.mantle
            border.width: 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.sideDrawerOpen ? "▶" : "◀"
                    color: Theme.accent
                    font.pixelSize: 10
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "S
E
T
T"
                    color: Theme.moon
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    font.bold: true
                    lineHeight: 0.85
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sideDrawerOpen = !root.sideDrawerOpen
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 42
            anchors.rightMargin: 16
            anchors.topMargin: 14
            anchors.bottomMargin: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Spacing & appearance"
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.bold: true
                    Layout.fillWidth: true
                }
                Rectangle {
                    implicitWidth: 22; implicitHeight: 22; radius: 5
                    color: Theme.controlRest
                    Text { anchors.centerIn: parent; text: "×"; color: Theme.muted; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; onClicked: root.sideDrawerOpen = false }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.08) }

            // Bar Margin
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Edge Margin"; color: Theme.moon; font.pixelSize: 11 }
                    Item { Layout.fillWidth: true }
                    Text { text: Settings.barMargin + "px"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10 }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    Repeater {
                        model: [0, 6, 12, 18, 24]
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: 24; radius: 4
                            color: Settings.barMargin === modelData ? Theme.accent : Theme.controlRest
                            Text { anchors.centerIn: parent; text: modelData; color: Settings.barMargin === modelData ? Theme.void_ : Theme.moon; font.pixelSize: 9; font.bold: true }
                            MouseArea { anchors.fill: parent; onClicked: Settings.barMargin = modelData }
                        }
                    }
                }
            }

            // Island Spacing
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Island Spacing"; color: Theme.moon; font.pixelSize: 11 }
                    Item { Layout.fillWidth: true }
                    Text { text: Settings.barIslandSpacing + "px"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10 }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    Repeater {
                        model: [2, 4, 8, 12, 16]
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: 24; radius: 4
                            color: Settings.barIslandSpacing === modelData ? Theme.accent : Theme.controlRest
                            Text { anchors.centerIn: parent; text: modelData; color: Settings.barIslandSpacing === modelData ? Theme.void_ : Theme.moon; font.pixelSize: 9; font.bold: true }
                            MouseArea { anchors.fill: parent; onClicked: Settings.barIslandSpacing = modelData }
                        }
                    }
                }
            }

            // Bar Opacity
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Bar Opacity"; color: Theme.moon; font.pixelSize: 11 }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(Settings.barOpacity * 100) + "%"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10 }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    Repeater {
                        model: [0.60, 0.75, 0.85, 0.95, 1.0]
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: 24; radius: 4
                            color: Math.abs(Settings.barOpacity - modelData) < 0.04 ? Theme.accent : Theme.controlRest
                            Text { anchors.centerIn: parent; text: Math.round(modelData * 100); color: Math.abs(Settings.barOpacity - modelData) < 0.04 ? Theme.void_ : Theme.moon; font.pixelSize: 9; font.bold: true }
                            MouseArea { anchors.fill: parent; onClicked: Settings.barOpacity = modelData }
                        }
                    }
                }
            }

            // Motion profile
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text { text: "Animation Easing Profile"; color: Theme.moon; font.pixelSize: 11 }
                RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    Repeater {
                        model: ["fluid", "snappy", "instant"]
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: 24; radius: 4
                            color: Settings.motionSpeedProfile === modelData ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : Theme.controlRest
                            border.width: 0
                            Text { anchors.centerIn: parent; text: modelData.toUpperCase(); color: Settings.motionSpeedProfile === modelData ? Theme.accent : Theme.muted; font.pixelSize: 9; font.bold: true }
                            MouseArea { anchors.fill: parent; onClicked: Settings.motionSpeedProfile = modelData }
                        }
                    }
                }
            }

            // Revert Layout
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 30; radius: 6
                color: Theme.controlRest; border.width: 0
                Text { anchors.centerIn: parent; text: "↺ Reset Bar to Default"; color: Theme.moon; font.pixelSize: 10 }
                MouseArea { anchors.fill: parent; onClicked: root.resetLayout() }
            }
        }
    }
}
