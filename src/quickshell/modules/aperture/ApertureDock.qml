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
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "tonantzintla-dock"
    readonly property var placement: Settings.getDockPlacement(modelData.name)
    readonly property string edge: placement.edge
    readonly property real alignment: placement.zone === "start" ? 0 : placement.zone === "end" ? 1 : 0.5
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool reverseEdge: edge === "bottom" || edge === "right"
    readonly property real iconSize: Math.max(28, Math.min(64, Settings.dockIconSize))
    readonly property real cellSize: iconSize + 18
    readonly property real thickness: iconSize + 32
    readonly property bool motion: Settings.motion && Theme.motionScale > 0
    readonly property var entries: DockModel.entries(DesktopEntries.applications.values,
        Compositor.windows, DockModel.pins(Settings.dockPins), Settings.dockShowRunning)
    readonly property real length: Math.min((vertical ? modelData.height : modelData.width) - 24,
        (entries.length + (includeLauncher ? 1 : 0)) * cellSize + 64)
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
    property real reveal: expanded ? 1 : 0
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
        width: root.vertical ? root.thickness : root.length
        height: root.vertical ? root.length : root.thickness
        x: root.vertical ? 0 : (root.width - width) * root.alignment
        y: root.vertical ? (root.height - height) * root.alignment : 0
        DockFluidSurface {
            anchors.fill: parent
            edge: root.edge
            reveal: root.reveal
            cursorAlong: hover.hovered
                ? (root.vertical ? hover.point.position.y / hit.height : hover.point.position.x / hit.width) : 0.5
        }
        Flickable {
            id: appStrip
            x: root.vertical ? 10 : 32
            y: root.vertical ? 32 : 10
            width: root.vertical ? root.cellSize : parent.width - 64
            height: root.vertical ? parent.height - 64 : root.cellSize
            contentWidth: root.vertical ? width : icons.width
            contentHeight: root.vertical ? icons.height : height
            flickableDirection: root.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            opacity: root.reveal
            visible: root.reveal > 0.01
            enabled: root.expanded
            transform: Translate {
                x: root.vertical ? (1 - root.reveal) * root.thickness * (root.reverseEdge ? 1 : -1) : 0
                y: root.vertical ? 0 : (1 - root.reveal) * root.thickness * (root.reverseEdge ? 1 : -1)
            }
            Grid {
                id: icons
                columns: root.vertical ? 1 : root.entries.length + 1
                // Launcher remains available when no apps are pinned or running.
                DockAppButton {
                    visible: root.includeLauncher
                    iconSize: root.iconSize
                    width: root.cellSize; height: root.cellSize
                    name: "Applications"
                    glyph: "⊞"
                    motion: root.motion
                    lift: Settings.dockHoverLift
                    onActivated: {
                        root.expanded = false;
                        ShellState.openEphemeris("apps");
                    }
                }
                Repeater {
                    model: root.entries
                    DockAppButton {
                        required property var modelData
                        iconSize: root.iconSize
                        width: root.cellSize; height: root.cellSize
                        name: modelData.name
                        icon: DockModel.iconFor(modelData, Settings.dockIconOverrides)
                        running: modelData.windows.length > 0
                        active: modelData.windows.indexOf(Compositor.focusedWindowId) >= 0
                        motion: root.motion
                        lift: Settings.dockHoverLift
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
            onHoveredChanged: {
                if (hovered) { hideTimer.stop(); if (!root.expanded) showTimer.restart(); }
                else { showTimer.stop(); hideTimer.restart(); }
            }
        }
        ToolTip.visible: hover.hovered && root.feedback.length > 0
        ToolTip.text: root.feedback
    }
}
