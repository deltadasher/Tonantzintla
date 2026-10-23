import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../components"
import "../../components/BarLayout.js" as BarLayout
import "../../services"
import "."

PanelWindow {
    id: root

    required property var modelData
    readonly property var targetBar: ShellState.activeIslandTarget
        ? ShellState.activeIslandTarget.barWindow : null
    readonly property string outputName: targetBar && targetBar.outputName
        ? targetBar.outputName : (modelData ? modelData.name : "")
    screen: Quickshell.screens.find(function(output) { return output.name === root.outputName; }) || modelData
    readonly property bool isDock: ShellState.activeIslandSettingsId === "dock"
    focusable: true
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Flipped once the window exists so the scrim and card animate in from the
    // island rather than snapping into place fully formed.
    property bool settled: false
    Component.onCompleted: root.settled = true

    readonly property string effectivePosition: targetBar ? targetBar.effectivePosition
        : Settings.getEffectiveBarPosition(outputName)
    readonly property bool isVertical: effectivePosition === "left" || effectivePosition === "right"
    readonly property bool isBottom: effectivePosition === "bottom"
    readonly property bool isRight: effectivePosition === "right"
    readonly property rect targetRect: {
        const target = ShellState.activeIslandTarget;
        if (target && targetBar && typeof targetBar.barPointToScreen === "function") {
            // The original gesture coordinates are local to the bar's window.
            // Right/bottom strips need their offset within the output added.
            const local = target.mapToItem(targetBar, 0, 0);
            const point = targetBar.barPointToScreen(local.x, local.y);
            return Qt.rect(point.x, point.y, target.width, target.height);
        }
        return Qt.rect(ShellState.activeIslandGlobalX, ShellState.activeIslandGlobalY,
            ShellState.activeIslandWidth, ShellState.activeIslandHeight);
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tonantzintla-island-popover"

    readonly property var currentLayout: {
        Settings.layoutRevision;
        return Settings.getEdgeBarLayout(outputName, effectivePosition);
    }
    readonly property var myLocation: ShellState.activeIslandSettingsId ? BarLayout.locate(currentLayout, ShellState.activeIslandSettingsId) : null

    function moveToZone(zone) {
        if (!myLocation || myLocation.zone === zone || BarLayout.zones.indexOf(zone) < 0) return;
        const id = ShellState.activeIslandSettingsId;
        const ordered = currentLayout[zone].filter(function(other) { return other !== id; });
        ordered.push(id);
        // Keep the shared arrangement policy in Settings (mirrored outputs).
        Settings.placeIsland(outputName, id, effectivePosition, zone, ordered);
        ShellState.closeIslandSettings();
    }

    function removeFromBar() {
        const id = ShellState.activeIslandSettingsId;
        if (!id) return;
        const primary = Settings.getEffectiveBarPosition(outputName);
        const vertical = primary === "left" || primary === "right";
        const key = vertical ? "barLayoutVertical" : "barLayoutHorizontal";
        // An island on a secondary edge still belongs to the primary layout.
        // Respect an explicit output layout rather than rewriting its global fallback.
        let overrides = {};
        try { overrides = JSON.parse(Settings.barOutputOverrides || "{}"); } catch (_) {}
        if (overrides[outputName] && overrides[outputName][key]) {
            Settings.setOutputOverride(outputName, key,
                BarLayout.removeIsland(Settings.getEffectiveBarLayout(outputName, vertical), id));
        } else {
            Settings.removeIslandFromLayout(vertical, id);
        }
        Settings.clearIslandPlacement(outputName, id);
        ShellState.closeIslandSettings();
    }

    readonly property var islandGlyphs: ({
        launcher: "⌕",
        workspaces: "⊞",
        media: "♫",
        window_title: "▭",
        clock: "◷",
        system_stats: "▤",
        status: "◉",
        tray: "⋯",
        controls: "⚙", dock: "⊞"
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
        controls: "Quick controls", dock: "Dock"
    })

    function clampPosition(value, extent, size) { return Math.max(8, Math.min(Math.max(8, extent-size-8), value)); }
    readonly property real popoverX: clampPosition(effectivePosition === "left" ? targetRect.x+targetRect.width+12
        : effectivePosition === "right" ? targetRect.x-card.width-12
        : targetRect.x+(targetRect.width-card.width)/2, width, card.width)
    readonly property real popoverY: clampPosition(effectivePosition === "bottom" ? targetRect.y-card.height-12
        : isVertical ? targetRect.y+(targetRect.height-card.height)/2
        : targetRect.y+targetRect.height+12, height, card.height)

    // This popup is a separate native host; both its ordinary controls and
    // dock editor share one bounded field in full-output coordinates.
    OpticalBackdrop {
        id: popupField
        anchors.fill: parent
        active: root.visible
        scope: root.isDock ? "dock" : "aperture"
        viewportSize: Qt.size(root.width, root.height)
    }

    // Everything except the island being configured drops away, so the thing
    // under the cursor is the only thing still lit.
    FocusScrim {
        anchors.fill: parent
        focusX: root.targetRect.x
        focusY: root.targetRect.y
        focusWidth: root.targetRect.width
        focusHeight: root.targetRect.height
        focusRadius: Settings.compact ? 8 : 10
        dim: 0.62
        opacity: root.settled ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.motionNormal }
        }
    }

    // Dismiss popover on outside click or right-click
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: ShellState.closeIslandSettings()
    }

    ApertureShortcuts {
        enabled: root.visible
        onCloseRequested: ShellState.closeIslandSettings()
    }

    // Main Popover Card
    Rectangle {
        id: card
        property var opticalBackdrop: popupField
        x: root.isDock ? (root.width - width) / 2 : root.popoverX
        y: root.isDock ? (root.height - height) / 2 : root.popoverY
        width: Math.max(1, Math.min(root.isDock ? 860 : 348, root.width - 16))
        height: Math.max(1, Math.min(root.height - 16, root.isDock ? 710 : contentCol.implicitHeight + 24))
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
            NumberAnimation { duration: Theme.motionFast }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.motionNormal
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

        Loader {
            anchors.fill: parent
            anchors.margins: 24
            active: root.isDock
            sourceComponent: DockSettings {
                outputName: root.outputName
                onCloseRequested: ShellState.closeIslandSettings()
            }
        }

        ScrollView {
            id: scroll
            objectName: "island-scroll"
            visible: !root.isDock
            anchors.fill:parent;anchors.margins:12
            contentWidth:availableWidth
            clip:true
            ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
            ColumnLayout {
                id:contentCol
                width:scroll.availableWidth
                spacing:10
                RowLayout {
                    Layout.fillWidth:true
                    Text {Layout.fillWidth:true;text:root.islandTitles[ShellState.activeIslandSettingsId]||"Island settings";wrapMode:Text.Wrap;color:Theme.moon;font.family:Theme.fontText;font.pixelSize:Theme.textBody;font.bold:true}
                    ActionButton {id:closeButton;focus:true;text:"Close";onClicked:ShellState.closeIslandSettings()}
                }
                IslandCustomizationBody {
                    id:body
                    Layout.fillWidth:true
                    islandId:ShellState.activeIslandSettingsId
                    currentZone:root.myLocation?root.myLocation.zone:""
                    placementControls:true
                    onOpenRequested: panel => {const output=root.outputName;ShellState.closeIslandSettings();ShellState.openEphemeris(panel,output);}
                    onMoveRequested:zone=>root.moveToZone(zone)
                    onArrangeRequested:ShellState.enterBarEditMode()
                    onRemoveRequested:root.removeFromBar()
                }
            }
        }
        Connections {
            target:scroll.Window.window
            function onActiveFocusItemChanged() {
                const item=scroll.Window.window ? scroll.Window.window.activeFocusItem : null;
                if(!item || !scroll.visible)return;
                let ancestor=item;
                while(ancestor && ancestor!==contentCol)ancestor=ancestor.parent;
                if(!ancestor)return;
                const point=item.mapToItem(contentCol,0,0);
                const viewport=scroll.contentItem;
                if(point.y<viewport.contentY)viewport.contentY=point.y;
                else if(point.y+item.height>viewport.contentY+viewport.height)viewport.contentY=point.y+item.height-viewport.height;
                viewport.contentY=Math.max(0,Math.min(viewport.contentY,Math.max(0,viewport.contentHeight-viewport.height)));
            }
        }
    }
}
