import QtQuick
import QtQuick.Controls
import ".."

Rectangle {
    id: root

    readonly property bool isVertical: root.parent && typeof root.parent.isVertical !== "undefined" ? root.parent.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")

    implicitWidth: isVertical ? (Settings.compact ? 32 : 36) : (Settings.compact ? 36 : 40)
    implicitHeight: isVertical ? (Settings.compact ? 32 : 36) : (Settings.compact ? 36 : 40)
    radius: 11
    // A panel window can take pointer ownership before this button receives an
    // exit event. Suppress hover until the next genuine leave so the old button
    // cannot remain lit (or leave its tooltip behind) after dismissal.
    readonly property bool hovered: pointer.containsMouse && !pointer.hoverSuppressed
    color: panelOpen ? Theme.controlActive : hovered || activeFocus ? Theme.barAccentVeil : "transparent"
    border.width: activeFocus ? 1 : 0
    border.color: Theme.accentLine

    default property alias iconContents: iconBody.data
    property string glyph: "⌕"
    property string accessibleLabel: "Action"
    property string targetPanel: ""
    property string motionKind: "pulse"
    readonly property bool panelOpen: targetPanel.length > 0 && ShellState.ephemerisVisible && ShellState.ephemerisTab === targetPanel
    readonly property bool motionAllowed: Settings.motion && Settings.barIconMotion && Theme.motionScale > 0
    property real iconPulse: 0
    onPanelOpenChanged: if (panelOpen && visible && motionAllowed) opening.restart()
    onMotionAllowedChanged: if (!motionAllowed) { opening.stop(); iconPulse = 0; }
    onActivated: if (!targetPanel.length && motionAllowed) opening.restart()
    signal activated
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: accessibleLabel
    Accessible.onPressAction: activated()
    Keys.onReturnPressed: activated()
    Keys.onSpacePressed: activated()

    ToolTip {
        // Focus retains its visible border for keyboard navigation, but does
        // not own a tooltip. Otherwise a click can leave this popup behind
        // after the panel takes focus.
        visible: root.hovered
        delay: 500
        text: root.accessibleLabel
        background: Rectangle { color: Theme.mantle; radius: Theme.radiusSmall; border.color: Theme.accentLine }
        contentItem: Text { text: root.accessibleLabel; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 12 }
    }

    Item {
        id: iconBody
        anchors.fill: parent
        scale: 1 + root.iconPulse * (root.motionKind === "lens" ? 0.22 : root.motionKind === "orbit" ? -0.12 : 0.12)
        rotation: root.iconPulse * (root.motionKind === "gear" ? 55 : root.motionKind === "star" ? 35 : root.motionKind === "orbit" ? -18 : 0)
        transform: Translate { y: root.motionKind === "workspace" ? -4 * root.iconPulse : 0 }
        Text {
            anchors.centerIn: parent
            text: root.glyph
            color: root.panelOpen || root.hovered ? Theme.accent : Theme.moon
            font.family: Theme.fontIcon
            font.pixelSize: Settings.compact ? 19 : 21
            font.weight: Font.DemiBold
        }
    }

    SequentialAnimation {
        id: opening
        NumberAnimation { target: root; property: "iconPulse"; from: 0; to: 1; duration: Theme.motionFast; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "iconPulse"; to: 0; duration: Theme.motionNormal; easing.type: Easing.OutBack }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        property bool hoverSuppressed: false
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (ShellState.barEditMode || ShellState.isDraggingIsland) return;
            hoverSuppressed = true;
            root.activated();
        }
        onExited: hoverSuppressed = false
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
}
