import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../components/BarLayout.js" as BarLayout

Rectangle {
    id: root
    radius: Theme.radiusLarge
    color: Theme.controlRest
    implicitHeight: content.implicitHeight + 32

    readonly property bool isVertical: Settings.barPosition === "left" || Settings.barPosition === "right"
    readonly property var currentLayout: isVertical ? Settings.activeLayoutVertical : Settings.activeLayoutHorizontal
    readonly property string rawLayout: isVertical ? Settings.barLayoutVertical : Settings.barLayoutHorizontal
    property string selection: "clock"
    property string undoLayout: ""
    property string undoExpected: ""
    property bool hasUndo: false
    readonly property var selectedLocation: BarLayout.locate(currentLayout, selection)
    readonly property bool canUndo: hasUndo && rawLayout === undoExpected
    readonly property int longestZone: Math.max(currentLayout.start.length, currentLayout.center.length, currentLayout.end.length, 1)
    readonly property var names: ({launcher: "Launcher", workspaces: "Workspaces", media: "Media", window_title: "Window title",
        clock: "Clock", system_stats: "System stats", status: "Status", tray: "System tray", controls: "Controls"})
    readonly property var glyphs: ({launcher: "⌕", workspaces: "⊞", media: "♫", window_title: "▭",
        clock: "◷", system_stats: "▤", status: "◉", tray: "⋯", controls: "⚙"})

    function zoneName(zone) {
        return zone === "center" ? "Center" : zone === "start" ? (isVertical ? "Top" : "Left") : (isVertical ? "Bottom" : "Right");
    }
    function remember() { undoLayout = rawLayout; }
    function changed() { undoExpected = rawLayout; hasUndo = true; }
    function move(delta) {
        if (!selectedLocation) return;
        const next = selectedLocation.index + delta;
        if (next < 0 || next >= currentLayout[selectedLocation.zone].length) return;
        remember();
        Settings.moveIsland(isVertical, selectedLocation.zone, selectedLocation.index, next);
        changed();
    }
    function place(zone) {
        if (!selectedLocation || selectedLocation.zone === zone) return;
        remember();
        Settings.transferIsland(isVertical, selectedLocation.zone, zone, selection);
        changed();
    }
    function undo() {
        if (!canUndo) return;
        if (isVertical) Settings.barLayoutVertical = undoLayout;
        else Settings.barLayoutHorizontal = undoLayout;
        hasUndo = false;
    }
    onIsVerticalChanged: hasUndo = false

    component Action: Rectangle {
        id: action
        property string text: ""
        property bool chosen: false
        signal triggered()
        implicitWidth: caption.implicitWidth + 24
        implicitHeight: 34
        radius: 10
        opacity: enabled ? 1 : 0.35
        color: chosen ? Theme.controlActive : mouse.containsMouse || activeFocus ? Theme.controlHover : Theme.controlRest
        border.width: activeFocus ? 1 : 0
        border.color: Theme.accent
        activeFocusOnTab: enabled
        Accessible.role: Accessible.Button
        Accessible.name: text
        Accessible.onPressAction: if (enabled) triggered()
        Keys.onReturnPressed: if (enabled) triggered()
        Keys.onSpacePressed: if (enabled) triggered()
        Text {
            id: caption
            anchors.centerIn: parent
            text: action.text
            color: action.chosen ? Theme.accent : Theme.moon
            font.family: Theme.fontText
            font.pixelSize: 11
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: action.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { action.forceActiveFocus(); action.triggered(); }
        }
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text { text: "Arrange the bar"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 17; font.bold: true }
                Text {
                    Layout.fillWidth: true
                    text: root.isVertical ? "Vertical layout · select an island to move it" : "Horizontal layout · select an island to move it"
                    color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11; wrapMode: Text.Wrap
                }
            }
            Action { text: "Arrange"; chosen: true; onTriggered: { ShellState.closeEphemeris(); ShellState.enterBarEditMode(); } }
            Action { text: "Undo"; enabled: root.canUndo; onTriggered: root.undo() }
            Action {
                text: "Reset"
                onTriggered: { root.remember(); Settings.resetBarLayout(root.isVertical); root.changed(); }
            }
        }

        GridLayout {
            id: zonesGrid
            Layout.fillWidth: true
            columns: width < 600 ? 1 : 3
            columnSpacing: 10
            rowSpacing: 10
            Repeater {
                model: BarLayout.zones
                Rectangle {
                    id: zoneCard
                    required property string modelData
                    readonly property var entries: root.currentLayout[modelData]
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: 58 + (zonesGrid.columns === 1 ? Math.max(1, entries.length) : root.longestZone) * 48
                    radius: Theme.radiusMedium
                    color: Theme.fieldRest

                    Column {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 6
                        Item {
                            width: parent.width; height: 28
                            Text {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                text: root.zoneName(zoneCard.modelData)
                                color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 11
                            }
                            Text {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: zoneCard.entries.length
                                color: Theme.lineBright; font.family: Theme.fontMono; font.pixelSize: 11
                            }
                        }
                        Repeater {
                            model: zoneCard.entries
                            Rectangle {
                                id: tile
                                required property string modelData
                                readonly property bool chosen: root.selection === modelData
                                width: parent.width; height: 42
                                radius: 12
                                color: chosen ? Theme.controlActive : tileMouse.containsMouse || activeFocus ? Theme.controlHover : Theme.controlRest
                                border.width: activeFocus ? 1 : 0
                                border.color: Theme.accent
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: root.names[modelData] + ", " + root.zoneName(zoneCard.modelData)
                                Accessible.onPressAction: root.selection = modelData
                                Keys.onReturnPressed: root.selection = modelData
                                Keys.onSpacePressed: root.selection = modelData
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                    spacing: 10
                                    Text {
                                        text: root.glyphs[tile.modelData]; color: tile.chosen ? Theme.accent : Theme.muted
                                        font.family: Theme.fontIcon; font.pixelSize: 17
                                        Layout.preferredWidth: 20
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.names[tile.modelData]; elide: Text.ElideRight
                                        color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 12
                                    }
                                    Rectangle { width: 5; height: 5; radius: 2.5; color: Theme.accent; opacity: tile.chosen ? 1 : 0 }
                                }
                                MouseArea {
                                    id: tileMouse
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { tile.forceActiveFocus(); root.selection = tile.modelData; }
                                }
                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            }
                        }
                        Text {
                            visible: zoneCard.entries.length === 0
                            width: parent.width; height: 42
                            text: "Open space"; color: Theme.lineBright; font.family: Theme.fontText; font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8
            Text {
                width: Math.min(130, root.width - 32); height: 34
                text: root.selectedLocation ? root.names[root.selection] : "Select an island"
                elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                color: Theme.accent; font.family: Theme.fontText; font.pixelSize: 12
            }
            Action { text: "Earlier"; enabled: root.selectedLocation !== null && root.selectedLocation.index > 0; onTriggered: root.move(-1) }
            Action { text: "Later"; enabled: root.selectedLocation !== null && root.selectedLocation.index < root.currentLayout[root.selectedLocation.zone].length - 1; onTriggered: root.move(1) }
            Row {
                spacing: 8
                Repeater {
                    model: BarLayout.zones
                    Action {
                        required property string modelData
                        text: root.zoneName(modelData)
                        chosen: root.selectedLocation !== null && root.selectedLocation.zone === modelData
                        enabled: root.selectedLocation !== null
                        onTriggered: root.place(modelData)
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Changes appear immediately. Media and other optional islands appear when available."
            color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11; wrapMode: Text.Wrap
        }
    }
}
