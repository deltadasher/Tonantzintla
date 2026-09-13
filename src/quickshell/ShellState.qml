pragma Singleton

import QtQuick
import "modules/ephemeris/EphemerisRegistry.js" as Registry

QtObject {
    property bool ephemerisVisible: false
    property string ephemerisTab: "apps"
    // Output that launched the current Ephemeris widget. Empty means use the
    // compositor focus for commands that did not originate from a bar.
    property string ephemerisOutput: ""
    property string settingsSection: "appearance"
    property bool quickActionsVisible: false
    property string quickActionTab: "telemetry"
    property int umbraRevealSerial: 0
    // Session-only: leaving focus restores the user's original preferences.
    property bool deepFocus: false
    function toggleDeepFocus() { deepFocus = !deepFocus; }

    function normalizeWidget(widget) {
        if (!widget || widget.length === 0)
            return "apps";
        if (widget === "launcher" || widget === "applauncher")
            return "apps";
        if (widget === "wallpaper" || widget === "wallpapers")
            return "walls";
        if (widget === "notifications" || widget === "transit")
            return "notifications";
        if (widget === "screenshot" || widget === "screenshots" || widget === "recording")
            return "capture";
        return Registry.normalize(widget);
    }

    function openEphemeris(tab, outputName) {
        ephemerisTab = normalizeWidget(tab);
        if (outputName && String(outputName).length > 0)
            ephemerisOutput = String(outputName);
        else if (!ephemerisVisible)
            ephemerisOutput = "";
        ephemerisVisible = true;
    }

    function closeEphemeris() {
        ephemerisVisible = false;
        // Keep the source output through the closing animation; the next
        // output-less open resets it before mounting a fresh widget.
        // The widget popover belongs to a surface that is no longer open.
        closeWidgetSettings();
    }

    function toggleEphemeris(tab, outputName) {
        const target = normalizeWidget(tab);
        const requestedOutput = outputName && String(outputName).length > 0
            ? String(outputName) : "";
        if (ephemerisVisible && ephemerisTab === target
                && (!requestedOutput || requestedOutput === ephemerisOutput))
            closeEphemeris();
        else
            openEphemeris(target, requestedOutput);
    }

    function openQuickActions(tab) {
        openEphemeris("system");
    }

    function toggleQuickActions(tab) {
        toggleEphemeris("system");
    }

    function hideQuickActions() {
        quickActionsVisible = false;
    }

    function startUmbraReveal() {
        umbraRevealSerial++;
    }

    property bool barEditMode: false
    property string activeIslandSettingsId: ""
    property var activeIslandTarget: null
    property real activeIslandGlobalX: 0
    property real activeIslandGlobalY: 0
    property real activeIslandWidth: 0
    property real activeIslandHeight: 0
    readonly property bool islandSettingsVisible: activeIslandSettingsId !== ""

    function openIslandSettings(islandId, targetItem, gx, gy, gw, gh) {
        // A click without a drag in Bar Studio is the widget's editor gesture.
        // Keep the studio state alive so closing this panel returns to it.
        closeEphemeris();
        hideQuickActions();
        activeIslandSettingsId = islandId;
        activeIslandTarget = targetItem;
        activeIslandGlobalX = gx || 0;
        activeIslandGlobalY = gy || 0;
        activeIslandWidth = gw || 0;
        activeIslandHeight = gh || 0;
    }

    function closeIslandSettings() {
        activeIslandSettingsId = "";
        activeIslandTarget = null;
    }

    function toggleIslandSettings(islandId, targetItem, gx, gy, gw, gh) {
        if (activeIslandSettingsId === islandId) {
            closeIslandSettings();
        } else {
            openIslandSettings(islandId, targetItem, gx, gy, gw, gh);
        }
    }

    // The same Super+Alt gesture aimed at an open Ephemeris widget rather than
    // a bar island. Kept separate from the island popover so both can never be
    // on screen at once.
    property string activeWidgetSettingsId: ""
    property real activeWidgetGlobalX: 0
    property real activeWidgetGlobalY: 0
    property real activeWidgetWidth: 0
    property real activeWidgetHeight: 0
    readonly property bool widgetSettingsVisible: activeWidgetSettingsId !== ""

    function openWidgetSettings(widgetId, gx, gy, gw, gh) {
        if (barEditMode || !widgetId)
            return;
        closeIslandSettings();
        activeWidgetSettingsId = widgetId;
        activeWidgetGlobalX = gx || 0;
        activeWidgetGlobalY = gy || 0;
        activeWidgetWidth = gw || 0;
        activeWidgetHeight = gh || 0;
    }

    function closeWidgetSettings() {
        activeWidgetSettingsId = "";
    }

    function enterBarEditMode() {
        closeEphemeris();
        hideQuickActions();
        closeIslandSettings();
        barEditMode = true;
    }
    function exitBarEditMode() {
        barEditMode = false;
        closeIslandSettings();
    }
    function toggleBarEditMode() {
        if (barEditMode) exitBarEditMode();
        else enterBarEditMode();
    }

    // Direct on-bar drag-and-drop in the shell
    property bool isDraggingIsland: false
    property string draggedIslandId: ""
    property var draggedIslandSourceItem: null
    property string dragSourceZone: "start"
    property string dragHoverEdge: "top"
    property string dragHoverZone: "start"
    property int dragTargetIndex: -1
    property var dragBar: null
    property real dragGlobalX: 0
    property real dragGlobalY: 0
    property real dragScreenX: 0
    property real dragScreenY: 0
    property real dragVelocityX: 0
    property real dragVelocityY: 0
    property real dragSourceWidth: 0
    property real dragSourceHeight: 0
    property string dragSourceOutput: ""
    property string dragSourceEdge: "top"
    property bool dropAnimating: false
    property string dropFlightIslandId: ""
    property real dropFlightX: 0
    property real dropFlightY: 0
    property double dragSampleTime: 0
    property Timer dragDecay: Timer {
        interval: 16
        repeat: true
        running: ShellState.isDraggingIsland
        onTriggered: {
            ShellState.dragVelocityX *= 0.82;
            ShellState.dragVelocityY *= 0.82;
            if (Math.abs(ShellState.dragVelocityX) < 0.02) ShellState.dragVelocityX = 0;
            if (Math.abs(ShellState.dragVelocityY) < 0.02) ShellState.dragVelocityY = 0;
        }
    }

    function startIslandDrag(islandId, sourceItem, sourceZone, screenX, screenY, sourceWidth, sourceHeight, sourceOutput, sourceEdge) {
        closeIslandSettings();
        dropAnimating = false;
        isDraggingIsland = true;
        draggedIslandId = islandId;
        draggedIslandSourceItem = sourceItem;
        dragSourceZone = sourceZone || "start";
        dragHoverZone = sourceZone || "start";
        dragHoverEdge = sourceEdge || "top";
        dragTargetIndex = -1;
        dragScreenX = screenX || 0;
        dragScreenY = screenY || 0;
        dragVelocityX = 0;
        dragVelocityY = 0;
        dragSourceWidth = sourceWidth || 0;
        dragSourceHeight = sourceHeight || 0;
        dragSourceOutput = sourceOutput || "";
        dragSourceEdge = sourceEdge || "top";
        dragSampleTime = Date.now();
    }

    function updateIslandDrag(gx, gy, bar, screenX, screenY) {
        // Retain the old IPC probe as a harmless pointer update. Live dragging
        // passes an ApertureContents object with dropTarget/commitDrop methods.
        if (!bar || typeof bar.dropTarget !== "function") {
            dragGlobalX = gx;
            dragGlobalY = gy;
            dragScreenX = gx;
            dragScreenY = gy;
            return;
        }
        const now = Date.now();
        const elapsed = Math.max(1, now - dragSampleTime);
        const frameScale = 16.667 / elapsed;
        const sampleX = ((screenX || 0) - dragScreenX) * frameScale;
        const sampleY = ((screenY || 0) - dragScreenY) * frameScale;
        dragVelocityX = dragVelocityX * 0.58 + sampleX * 0.42;
        dragVelocityY = dragVelocityY * 0.58 + sampleY * 0.42;
        dragScreenX = screenX || 0;
        dragScreenY = screenY || 0;
        dragSampleTime = now;
        dragGlobalX = gx;
        dragGlobalY = gy;
        dragBar = bar;
        const target = bar.dropTarget(gx, gy, draggedIslandId, screenX, screenY);
        dragHoverEdge = target ? target.edge : "";
        dragHoverZone = target ? target.zone : "";
        dragTargetIndex = target ? target.index : -1;
    }

    function finishIslandDrag(isVertical) {
        if (!isDraggingIsland) return;
        const island = draggedIslandId;
        const bar = dragBar;
        const zone = dragHoverZone;
        const edge = dragHoverEdge;
        const index = dragTargetIndex;
        if (bar && edge) {
            dropFlightIslandId = island;
            const sw = Number(bar.screenWidth || 0);
            const sh = Number(bar.screenHeight || 0);
            dropFlightX = edge === "left" ? 24 : edge === "right" ? Math.max(24, sw - 24) : dragScreenX;
            dropFlightY = edge === "top" ? 24 : edge === "bottom" ? Math.max(24, sh - 24) : dragScreenY;
            dropAnimating = true;
        }
        cancelIslandDrag();
        if (bar && edge && zone && index >= 0)
            bar.commitDrop(island, edge, zone, index);
    }

    function cancelIslandDrag() {
        dragBar = null;
        dragTargetIndex = -1;
        dragHoverEdge = "";
        isDraggingIsland = false;
        draggedIslandId = "";
        draggedIslandSourceItem = null;
        dragVelocityX = 0;
        dragVelocityY = 0;
        dragSourceWidth = 0;
        dragSourceHeight = 0;
        dragSourceOutput = "";
        dragSourceEdge = "top";
    }

}
