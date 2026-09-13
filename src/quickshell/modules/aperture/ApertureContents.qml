import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../.."
import "../../components"
import "../../services"
import "islands"

Item {
    id: window

    property string outputName: ""
    property bool previewMode: false
    property string edge: ""
    property real screenWidth: width
    property real screenHeight: height
    readonly property string effectivePosition: edge || (previewMode
        ? Settings.barPosition : Settings.getEffectiveBarPosition(window.outputName))
    readonly property bool isVertical: effectivePosition === "left" || effectivePosition === "right"
    readonly property bool isBottom: effectivePosition === "bottom"
    readonly property bool isRight: effectivePosition === "right"
    readonly property bool docked: Settings.barMode === "docked"
    readonly property bool capsules: Settings.barMode === "capsules"
    readonly property int bodyThickness: Settings.compact ? (isVertical ? 42 : 36) : (Settings.barHeightProfile === "tall" || Settings.barHeightProfile === "spacious" ? (isVertical ? 54 : 52) : (isVertical ? 48 : Theme.barHeight))
    readonly property int shellMargin: docked ? 0 : Settings.barMargin
    property real leftReveal: 0
    property real workspaceReveal: 0
    property real mediaReveal: 0
    property real centerReveal: 0
    property real systemReveal: 0
    property real rightReveal: 0
    opacity: ShellState.deepFocus ? 0.4 : 1
    Behavior on opacity { NumberAnimation { duration: Settings.motion ? 220 : 0 } }

    implicitWidth: isVertical ? (bodyThickness + shellMargin * 2) : 0
    implicitHeight: isVertical ? 0 : (bodyThickness + shellMargin * 2)

    readonly property var activeLayout: {
        Settings.layoutRevision;
        return previewMode
            ? (window.isVertical ? Settings.activeLayoutVertical : Settings.activeLayoutHorizontal)
            : Settings.getEdgeBarLayout(window.outputName, window.effectivePosition);
    }
    readonly property bool hasIslands: activeLayout.start.length + activeLayout.center.length
        + activeLayout.end.length > 0

    function barPointToScreen(px, py) {
        if (isVertical)
            return Qt.point(isRight ? screenWidth - width + px : px, py);
        return Qt.point(px, isBottom ? screenHeight - height + py : py);
    }

    function islandRects() {
        const rects = [];
        const groups = [startZone, centerZone, endZone];
        for (let groupIndex = 0; groupIndex < groups.length; ++groupIndex) {
            const children = groups[groupIndex].children;
            for (let childIndex = 0; childIndex < children.length; ++childIndex) {
                const child = children[childIndex];
                if (!child.islandId || !child.visible || child.width <= 0 || child.height <= 0)
                    continue;
                const point = child.mapToItem(window, 0, 0);
                rects.push({id: child.islandId, x: point.x, y: point.y,
                    width: child.width, height: child.height});
            }
        }
        rects.sort(function(a, b) { return isVertical ? a.y - b.y : a.x - b.x; });
        return rects;
    }

    function dropTarget(px, py, draggedId, screenX, screenY) {
        const sx = Math.max(0, Math.min(screenWidth, screenX));
        const sy = Math.max(0, Math.min(screenHeight, screenY));
        const distances = [
            {edge: "top", value: screenHeight > 0 ? sy / screenHeight : sy},
            {edge: "right", value: screenWidth > 0 ? (screenWidth - sx) / screenWidth : screenWidth - sx},
            {edge: "bottom", value: screenHeight > 0 ? (screenHeight - sy) / screenHeight : screenHeight - sy},
            {edge: "left", value: screenWidth > 0 ? sx / screenWidth : sx}
        ];
        distances.sort(function(a, b) { return a.value - b.value; });
        let targetEdge = distances[0].edge;
        // Keep the current edge while crossing a corner until the pointer is
        // clearly closer to the next edge; this prevents jitter between
        // neighboring widgets and makes the drop target feel intentional.
        if (ShellState.dragHoverEdge && ShellState.dragHoverEdge !== targetEdge) {
            const current = distances.filter(function(item) { return item.edge === ShellState.dragHoverEdge; })[0];
            if (current && distances[0].value + 0.10 >= current.value)
                targetEdge = ShellState.dragHoverEdge;
        }
        const verticalTarget = targetEdge === "left" || targetEdge === "right";
        const axis = verticalTarget ? sy : sx;
        const length = verticalTarget ? screenHeight : screenWidth;
        const fraction = length > 0 ? axis / length : 0.5;
        const zone = fraction < 1 / 3 ? "start" : fraction > 2 / 3 ? "end" : "center";
        const zoneStart = zone === "start" ? 0 : zone === "center" ? 1 / 3 : 2 / 3;
        const local = Math.max(0, Math.min(1, (fraction - zoneStart) * 3));
        const layout = Settings.getEdgeBarLayout(outputName, targetEdge);
        const remaining = layout[zone].filter(function(id) { return id !== draggedId; });
        return {
            edge: targetEdge,
            zone: zone,
            index: Math.max(0, Math.min(remaining.length, Math.round(local * remaining.length)))
        };
    }

    function commitDrop(id, targetEdge, zone, index) {
        const layout = Settings.getEdgeBarLayout(outputName, targetEdge);
        const ordered = layout[zone].filter(function(other) { return other !== id; });
        ordered.splice(Math.max(0, Math.min(ordered.length, index)), 0, id);
        Settings.placeIsland(outputName, id, targetEdge, zone, ordered);
    }

    Rectangle {
        visible: !window.capsules
        x: window.shellMargin
        y: window.shellMargin
        width: window.isVertical ? window.bodyThickness : (window.width - window.shellMargin * 2)
        height: window.isVertical ? (window.height - window.shellMargin * 2) : window.bodyThickness
        radius: window.docked ? 0 : 14
        color: ShellState.barEditMode ? "transparent" : Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b,
            Math.min(0.86, Settings.barOpacity * 0.82))
        border.width: 0
    }

    // Start Zone (Left in horizontal, Top in vertical)
    Grid {
        id: startZone
        columns: window.isVertical ? 1 : -1
        x: window.isVertical
            ? Math.round((parent.width - width) / 2)
            : (window.docked ? 10 : window.shellMargin)
        y: window.isVertical
            ? (window.docked ? 10 : window.shellMargin)
            : Math.round((parent.height - height) / 2)
        verticalItemAlignment: window.isVertical ? Grid.AlignTop : Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter
        spacing: window.capsules ? Settings.barIslandSpacing : 1

        Repeater {
            model: window.activeLayout.start
            IslandHost {
                islandId: modelData
                outputName: window.outputName
                barWindow: window
            }
        }

        // Serpantinum drop indicator slot
        Rectangle {
            id: startDropSlot
            visible: false // Insertion feedback must not resize the layout being dragged.
            readonly property bool isHovered: ShellState.dragHoverZone === "start"
            implicitWidth: window.isVertical ? (Settings.compact ? 38 : 42) : (isHovered ? 84 : 44)
            implicitHeight: window.isVertical ? (isHovered ? 84 : 44) : (Settings.compact ? 28 : 32)
            radius: 8
            color: isHovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.45)
            border.width: 1
            border.color: isHovered ? Theme.accent : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.18)

            Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: startDropSlot.isHovered ? "✦" : "⇣"
                    color: startDropSlot.isHovered ? Theme.accent : Theme.muted
                    font.pixelSize: 10
                    font.bold: true
                }
                Text {
                    visible: !window.isVertical && startDropSlot.isHovered
                    text: "START"
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }
    }

    // Center Zone (Center in horizontal, Center in vertical)
    Grid {
        id: centerZone
        columns: window.isVertical ? 1 : -1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        verticalItemAlignment: window.isVertical ? Grid.AlignTop : Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter
        spacing: window.capsules ? Settings.barIslandSpacing : 1

        Repeater {
            model: window.activeLayout.center
            IslandHost {
                islandId: modelData
                outputName: window.outputName
                barWindow: window
            }
        }

        // Serpantinum drop indicator slot
        Rectangle {
            id: centerDropSlot
            visible: false // Insertion feedback must not resize the layout being dragged.
            readonly property bool isHovered: ShellState.dragHoverZone === "center"
            implicitWidth: window.isVertical ? (Settings.compact ? 38 : 42) : (isHovered ? 88 : 44)
            implicitHeight: window.isVertical ? (isHovered ? 88 : 44) : (Settings.compact ? 28 : 32)
            radius: 8
            color: isHovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.45)
            border.width: 1
            border.color: isHovered ? Theme.accent : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.18)

            Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: centerDropSlot.isHovered ? "✦" : "⇣"
                    color: centerDropSlot.isHovered ? Theme.accent : Theme.muted
                    font.pixelSize: 10
                    font.bold: true
                }
                Text {
                    visible: !window.isVertical && centerDropSlot.isHovered
                    text: "CENTER"
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }
    }

    // End Zone (Right in horizontal, Bottom in vertical)
    Grid {
        id: endZone
        columns: window.isVertical ? 1 : -1
        x: window.isVertical
            ? Math.round((parent.width - width) / 2)
            : (parent.width - width - (window.docked ? 10 : window.shellMargin))
        y: window.isVertical
            ? (parent.height - height - (window.docked ? 10 : window.shellMargin))
            : Math.round((parent.height - height) / 2)
        verticalItemAlignment: window.isVertical ? Grid.AlignTop : Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter
        spacing: window.capsules ? Settings.barIslandSpacing : 1

        Repeater {
            model: window.activeLayout.end
            IslandHost {
                islandId: modelData
                outputName: window.outputName
                barWindow: window
            }
        }

        // Serpantinum drop indicator slot
        Rectangle {
            id: endDropSlot
            visible: false // Insertion feedback must not resize the layout being dragged.
            readonly property bool isHovered: ShellState.dragHoverZone === "end"
            implicitWidth: window.isVertical ? (Settings.compact ? 38 : 42) : (isHovered ? 84 : 44)
            implicitHeight: window.isVertical ? (isHovered ? 84 : 44) : (Settings.compact ? 28 : 32)
            radius: 8
            color: isHovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.45)
            border.width: 1
            border.color: isHovered ? Theme.accent : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.18)

            Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: endDropSlot.isHovered ? "✦" : "⇣"
                    color: endDropSlot.isHovered ? Theme.accent : Theme.muted
                    font.pixelSize: 10
                    font.bold: true
                }
                Text {
                    visible: !window.isVertical && endDropSlot.isHovered
                    text: "END"
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }
    }

    Component.onCompleted: startupDelay.restart()

    Timer {
        id: startupDelay
        interval: 40
        onTriggered: startupSequence.restart()
    }

    SequentialAnimation {
        id: startupSequence
        NumberAnimation { target: window; property: "leftReveal"; to: 1; duration: Settings.motion ? 180 : 0; easing.type: Easing.OutBack }
        NumberAnimation { target: window; property: "workspaceReveal"; to: 1; duration: Settings.motion ? 150 : 0; easing.type: Easing.OutBack }
        NumberAnimation { target: window; property: "mediaReveal"; to: 1; duration: Settings.motion ? 180 : 0; easing.type: Easing.OutBack }
        NumberAnimation { target: window; property: "centerReveal"; to: 1; duration: Settings.motion ? 170 : 0; easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: window; property: "systemReveal"; to: 1; duration: Settings.motion ? 210 : 0; easing.type: Easing.OutBack }
            NumberAnimation { target: window; property: "rightReveal"; to: 1; duration: Settings.motion ? 260 : 0; easing.type: Easing.OutBack }
        }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: Settings.motion ? Theme.motionNormal : 0; easing.type: Easing.OutCubic }
    }
    Behavior on implicitWidth {
        NumberAnimation { duration: Settings.motion ? Theme.motionNormal : 0; easing.type: Easing.OutCubic }
    }
}
