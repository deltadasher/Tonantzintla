import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../services"
import "../../components"
import "../../components/DockModel.js" as DockModel

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    color: "transparent"
    exclusionMode: Settings.dockExclusive && !Settings.dockAutoHide ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: Settings.dockExclusive && !Settings.dockAutoHide ? thickness : 0
    WlrLayershell.layer: Settings.dockAboveWindows ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "tonantzintla-dock"
    readonly property var placement: Settings.getDockPlacement(modelData.name)
    readonly property string edge: placement.edge
    readonly property real alignment: placement.zone === "start" ? 0 : placement.zone === "end" ? 1 : 0.5
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool reverseEdge: edge === "bottom" || edge === "right"
    readonly property real iconSize: Math.max(28, Math.min(72, Settings.dockIconSize))
    readonly property real cellSize: iconSize + 18
    readonly property real hoverScale: Settings.dockHoverLift ? Math.max(1, Math.min(1.6, Settings.dockHoverScale)) : 1
    // The first/last magnified icons need room inside the clipped scroll strip,
    // including when a short output requires scrolling to its opposite end.
    readonly property real endPadding: Math.ceil(Math.max(0, (iconSize * hoverScale - cellSize) / 2))
    readonly property real thickness: Math.ceil(Math.max(iconSize + 32, iconSize * hoverScale + 24))
    readonly property bool motion: Settings.motion && Theme.motionScale > 0
    readonly property var entries: DockModel.entries(DesktopEntries.applications.values,
        DockModel.scopedWindows(Compositor.windows, Compositor.workspaces, Settings.dockWindowScope, modelData.name), DockModel.pins(Settings.dockPins), Settings.dockShowRunning)
    readonly property real length: Math.max(1, Math.min((vertical ? modelData.height : modelData.width) - 24,
        (entries.length + (includeLauncher ? 1 : 0)) * cellSize + 96 + endPadding * 2))
    readonly property bool includeLauncher: Settings.dockShowLauncher || entries.length === 0
    readonly property bool outputSelected: Settings.dockOnOutput(modelData.name)
    // Studio owns its two drawers. Show an in-editor preview instead of placing
    // another interactive surface over those controls.
    visible: Settings.dockEnabled && outputSelected && !ShellState.barEditMode
        && !ShellState.islandSettingsVisible
    anchors {
        top: root.vertical || root.edge === "top"
        bottom: root.vertical || root.edge === "bottom"
        left: !root.vertical || root.edge === "left"
        right: !root.vertical || root.edge === "right"
    }
    implicitWidth: vertical ? thickness : 0
    implicitHeight: vertical ? 0 : thickness
    mask: Region { item: hit }

    property bool expanded: false
    readonly property bool revealed: !Settings.dockAutoHide || expanded
    property real reveal: revealed ? 1 : 0
    property int hoveredEntry: -2
    readonly property real inputDepth: 3 + (thickness - 3) * reveal
    property string feedback: ""
    property double lastLaunch: 0
    Behavior on reveal { NumberAnimation { duration: root.motion ? 280 : 0; easing.type: Easing.OutCubic } }
    onVisibleChanged: if (!visible) { expanded = false; showTimer.stop(); hideTimer.stop(); }
    onEdgeChanged: expanded = false
    function activate(entry, newInstance) {
        feedback = "";
        if (!newInstance && entry.windows.length) {
            Compositor.focusWindow(DockModel.nextWindow(entry.windows, Compositor.focusedWindowId));
        } else if (entry.app) {
            if (Date.now() - lastLaunch < 700) return;
            lastLaunch = Date.now();
            try { entry.app.execute(); LaunchHistory.record(entry.appId); }
            catch (_) { feedback = "Could not launch " + entry.name; }
        } else feedback = "Application is no longer installed";
    }

    Timer {
        id: showTimer
        interval: Math.max(0, Math.min(1000, Settings.dockShowDelay))
        onTriggered: if (hover.hovered && root.visible) root.expanded = true
    }
    Timer {
        id: hideTimer
        interval: Math.max(150, Math.min(2000, Settings.dockHideDelay))
        onTriggered: if (!hover.hovered) root.expanded = false
    }

    Item {
        id: field
        property var opticalBackdrop: opticalField
        OpticalBackdrop {
            id: opticalField
            anchors.fill: parent
            scope: "dock"
            geometryRevision: root.reveal
            active: root.visible && root.reveal > 0.001
            viewportSize: Qt.size(root.modelData.width, root.modelData.height)
            viewportOffset: Qt.point(field.x + (root.edge === "right" ? root.modelData.width - root.width : 0),
                field.y + (root.edge === "bottom" ? root.modelData.height - root.height : 0))
        }
        width: root.vertical ? root.thickness : root.length
        height: root.vertical ? root.length : root.thickness
        x: root.vertical ? 0 : (root.width - width) * root.alignment
        y: root.vertical ? (root.height - height) * root.alignment : 0
        DockFluidSurface {
            anchors.fill: parent
            edge: root.edge
            visible: Settings.dockBackground
            reveal: root.reveal
            cursorAlong: hover.hovered
                ? (root.vertical ? hover.point.position.y / hit.height : hover.point.position.x / hit.width) : 0.5
        }
        Flickable {
            id: appStrip
            x: root.vertical ? 12 : Math.min(48, parent.width / 4)
            y: root.vertical ? Math.min(48, parent.height / 4) : 12
            width: root.vertical ? root.thickness - 24 : Math.max(1, parent.width - x * 2)
            height: root.vertical ? Math.max(1, parent.height - y * 2) : root.thickness - 24
            contentWidth: root.vertical ? width : icons.width + root.endPadding * 2
            contentHeight: root.vertical ? icons.height + root.endPadding * 2 : height
            flickableDirection: root.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            opacity: root.reveal
            visible: root.reveal > 0.01
            enabled: root.revealed
            transform: Translate {
                x: root.vertical ? (1 - root.reveal) * root.thickness * (root.reverseEdge ? 1 : -1) : 0
                y: root.vertical ? 0 : (1 - root.reveal) * root.thickness * (root.reverseEdge ? 1 : -1)
            }
            Grid {
                id: icons
                x: root.vertical ? (appStrip.width - root.cellSize) / 2 : root.endPadding
                y: root.vertical ? root.endPadding : (appStrip.height - root.cellSize) / 2
                columns: root.vertical ? 1 : root.entries.length + 1
                // Launcher remains available when no apps are pinned or running.
                DockAppButton {
                    visible: root.includeLauncher
                    iconSize: root.iconSize
                    width: root.cellSize; height: root.cellSize
                    name: "Applications"
                    glyph: "⊞"
                    edge: root.edge
                    motion: root.motion
                    lift: Settings.dockHoverLift
                    hoverAmount: Settings.dockHoverScale
                    neighborAmount: Settings.dockHoverNeighbors && root.hoveredEntry === 0 ? 0.5 : 0
                    onHoveredChanged: { if (hovered) root.hoveredEntry = -1; else if (root.hoveredEntry === -1) root.hoveredEntry = -2; }
                    onActivated: {
                        root.expanded = false;
                        ShellState.openEphemeris("apps");
                    }
                }
                Repeater {
                    model: root.entries
                    DockAppButton {
                        required property var modelData
                        required property int index
                        iconSize: root.iconSize
                        width: root.cellSize; height: root.cellSize
                        name: modelData.name
                        icon: DockModel.iconFor(modelData, Settings.dockIconOverrides)
                        running: modelData.windows.length > 0
                        active: modelData.windows.indexOf(Compositor.focusedWindowId) >= 0
                        edge: root.edge
                        motion: root.motion
                        lift: Settings.dockHoverLift
                        hoverAmount: Settings.dockHoverScale
                        showIndicator: Settings.dockShowIndicators
                        neighborAmount: Settings.dockHoverNeighbors && Math.abs(root.hoveredEntry - index) === 1 ? 0.5 : 0
                        onHoveredChanged: { if (hovered) root.hoveredEntry = index; else if (root.hoveredEntry === index) root.hoveredEntry = -2; }
                        onActivated: root.activate(modelData, false)
                        onNewInstance: root.activate(modelData, true)
                    }
                }
            }
        }
    }
    Item {
        id: hit
        readonly property real depth: root.inputDepth
        x: root.vertical ? (root.reverseEdge ? root.width - depth : 0) : field.x
        y: root.vertical ? field.y : (root.reverseEdge ? root.height - depth : 0)
        width: root.vertical ? depth : root.length
        height: root.vertical ? root.length : depth
        HoverHandler {
            id: hover
            parent: field
            // The reveal region sits over the buttons. Observe entry without
            // swallowing their hover events (including magnification/tooltips).
            blocking: false
            onHoveredChanged: {
                if (hovered) { hideTimer.stop(); if (!root.expanded) showTimer.restart(); }
                else { showTimer.stop(); hideTimer.restart(); }
            }
        }
        ToolTip.visible: hover.hovered && root.feedback.length > 0
        ToolTip.text: root.feedback
    }
}
