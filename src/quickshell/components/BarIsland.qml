import QtQuick
import QtQuick.Layouts
import ".."
import "BarLayout.js" as BarLayout

Rectangle {
    id: root

    property string islandId: ""
    default property alias contents: contentGrid.data
    property real reveal: 1
    property bool luminous: false
    property bool reactive: true
    property var barWindow: null
    property bool islandVisible: true
    readonly property bool isVertical: barWindow ? barWindow.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")
    readonly property string effectivePosition: barWindow ? barWindow.effectivePosition : Settings.barPosition
    readonly property bool separate: Settings.barMode === "capsules"

    readonly property var currentLayout: barWindow ? barWindow.activeLayout
        : (isVertical ? Settings.activeLayoutVertical : Settings.activeLayoutHorizontal)
    function toggleEphemeris(tab) {
        ShellState.toggleEphemeris(tab, barWindow ? barWindow.outputName : "");
    }

    readonly property var myLocation: islandId ? BarLayout.locate(currentLayout, islandId) : null

    visible: islandVisible
    width: visible ? implicitWidth : 0
    height: visible ? implicitHeight : 0
    implicitWidth: !islandVisible ? 0 : (isVertical
        ? (Settings.compact ? 42 : 46)
        : contentGrid.implicitWidth + (Settings.compact ? 10 : 14))
    implicitHeight: !islandVisible ? 0 : (isVertical
        ? contentGrid.implicitHeight + (Settings.compact ? 10 : 14)
        : (Settings.compact ? 36 : Theme.barHeight))
    radius: Settings.compact ? 8 : 10
    color: separate && !(ShellState.barEditMode && barWindow)
        ? surfaceHover.hovered && reactive
            ? Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b,
                Math.min(0.88, Settings.barOpacity * 0.86))
            : Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b,
                Math.min(0.82, Settings.barOpacity * 0.78))
        : "transparent"
    border.width: 0
    // Keep the real bar's geometry in place while its live, full-size twin
    // follows the pointer in the studio overlay.
    opacity: ShellState.isDraggingIsland && ShellState.draggedIslandSourceItem === root
        ? 0 : reveal
    scale: (0.96 + reveal * 0.04) * (surfaceHover.hovered && reactive ? 1.01 : 1)

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

    HoverHandler {
        id: surfaceHover
    }

    // Direct on-bar drag. Niri owns Mod+button-1 before clients see it, so the
    // compositor binding opens edit mode. Once open, plain button-1 drags an
    // island; outside edit mode the small visible grip provides the same action.
    MouseArea {
        id: shortcutInterceptor
        anchors.fill: parent
        z: 9999
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        readonly property bool overGrip: root.isVertical
            ? mouseX < 8 && Math.abs(mouseY - height / 2) < 16
            : mouseY < 8 && Math.abs(mouseX - width / 2) < 16
        cursorShape: isDragging ? Qt.ClosedHandCursor
            : (ShellState.barEditMode || overGrip) ? Qt.OpenHandCursor : Qt.ArrowCursor

        property bool isModifierActive: false
        property bool isDragging: false
        property real pressStartX: 0
        property real pressStartY: 0

        onPressed: function(mouse) {
            const isTarget = mouse.button === Qt.LeftButton
                && (ShellState.barEditMode || overGrip);

            if (isTarget) {
                mouse.accepted = true;
                isModifierActive = true;
                isDragging = false;
                pressStartX = mouse.x;
                pressStartY = mouse.y;
            } else {
                isModifierActive = false;
                mouse.accepted = false;
            }
        }

        onPositionChanged: function(mouse) {
            if (isModifierActive && (mouse.buttons & Qt.LeftButton)) {
                const dx = mouse.x - pressStartX;
                const dy = mouse.y - pressStartY;
                const dist = Math.sqrt(dx * dx + dy * dy);

                if (!isDragging && dist > 7) {
                    isDragging = true;
                    const center = root.mapToItem(root.barWindow, root.width / 2, root.height / 2);
                    const screenCenter = root.barWindow.barPointToScreen(center.x, center.y);
                    ShellState.startIslandDrag(root.islandId, root, root.myLocation ? root.myLocation.zone : "start",
                        screenCenter.x, screenCenter.y, root.width, root.height,
                        root.barWindow ? root.barWindow.outputName : "",
                        root.barWindow ? root.barWindow.effectivePosition : Settings.barPosition);
                }

                if (isDragging) {
                    if (root.barWindow) {
                        const pt = root.mapToItem(root.barWindow, mouse.x, mouse.y);
                        const screenPoint = root.barWindow.barPointToScreen(pt.x, pt.y);
                        ShellState.updateIslandDrag(pt.x, pt.y, root.barWindow, screenPoint.x, screenPoint.y);
                    }
                }
            }
        }

        onReleased: function(mouse) {
            if (isModifierActive && mouse.button === Qt.LeftButton) {
                if (isDragging) {
                    isDragging = false;
                    ShellState.finishIslandDrag(root.isVertical);
                } else if (ShellState.barEditMode) {
                    const origin = root.mapToItem(null, 0, 0);
                    ShellState.openIslandSettings(root.islandId, root, origin.x, origin.y,
                        root.width, root.height);
                }
                mouse.accepted = true;
            }
            isModifierActive = false;
            isDragging = false;
        }

        onCanceled: function() {
            if (isDragging) {
                isDragging = false;
                ShellState.cancelIslandDrag();
            }
            isModifierActive = false;
        }
    }

    Grid {
        id: contentGrid
        property bool isVertical: root.isVertical
        anchors.centerIn: parent
        columns: root.isVertical ? 1 : -1
        verticalItemAlignment: root.isVertical ? Grid.AlignTop : Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter
        spacing: Settings.compact ? 2 : 4
        opacity: 1.0
    }

    // A small left-drag handle outside edit mode, leaving normal controls usable.
    Rectangle {
        z: 10000
        visible: ShellState.barEditMode || surfaceHover.hovered
        x: root.isVertical ? 2 : (root.width - width) / 2
        y: root.isVertical ? (root.height - height) / 2 : 2
        width: root.isVertical ? 3 : 18
        height: root.isVertical ? 18 : 3
        radius: 2
        color: Theme.accent
        opacity: shortcutInterceptor.overGrip ? 1 : 0.5
    }

    Rectangle {
        visible: root.separate && surfaceHover.hovered
        anchors.horizontalCenter: !root.isVertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: root.isVertical ? parent.verticalCenter : undefined
        anchors.bottom: !root.isVertical && root.effectivePosition !== "bottom" ? parent.bottom : undefined
        anchors.top: !root.isVertical && root.effectivePosition === "bottom" ? parent.top : undefined
        anchors.right: root.isVertical && root.effectivePosition === "left" ? parent.right : undefined
        anchors.left: root.isVertical && root.effectivePosition === "right" ? parent.left : undefined

        width: !root.isVertical ? Math.min(28, root.width * 0.28) : 1
        height: root.isVertical ? Math.min(28, root.height * 0.28) : 1
        color: Theme.accent
        opacity: 0.72
        Behavior on width { NumberAnimation { duration: Settings.motion ? 180 : 0; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Settings.motion ? 180 : 0; easing.type: Easing.OutCubic } }
    }

    transform: Translate {
        x: root.isVertical ? (1 - root.reveal) * (root.effectivePosition === "right" ? 12 : -12) : 0
        y: !root.isVertical ? (1 - root.reveal) * (root.effectivePosition === "bottom" ? 12 : -12) : 0
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on scale { NumberAnimation { duration: Settings.motion ? 180 : 0; easing.type: Easing.OutCubic } }
}
