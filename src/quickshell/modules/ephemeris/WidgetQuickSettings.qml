import QtQuick
import "../.."
import "../../components"

// This contextual overlay shares its instrument's native window. It retains
// keyboard ownership without a second fullscreen compositor buffer or preview.
FocusScope {
    id: root
    required property var modelData
    property bool settled: false
    Component.onCompleted: { root.settled = true; Qt.callLater(card.focusPrimary); }
    anchors.fill: parent
    property point viewportOrigin: Qt.point(0, 0)
    readonly property rect instrumentRect: Qt.rect(
        ShellState.activeWidgetGlobalX - viewportOrigin.x,
        ShellState.activeWidgetGlobalY - viewportOrigin.y,
        ShellState.activeWidgetWidth, ShellState.activeWidgetHeight)
    focus: true
    readonly property real inset: Math.min(16, width / 8, height / 8)
    readonly property point cardPosition: {
        const panel = root.instrumentRect;
        const maxX = Math.max(root.inset, root.width - card.width - root.inset);
        const maxY = Math.max(root.inset, root.height - card.height - root.inset);
        const middleX = panel.x + (panel.width - card.width) / 2;
        const middleY = panel.y + (panel.height - card.height) / 2;
        // Prefer a free side. When none fits, use the surrounding viewport
        // margin and choose the least overlap, instead of starting inside the
        // instrument. Clamp every candidate, including stale output geometry.
        const candidates = [
            {x: panel.x + panel.width + 14, y: middleY},
            {x: panel.x - card.width - 14, y: middleY},
            {x: middleX, y: panel.y - card.height - 14},
            {x: middleX, y: panel.y + panel.height + 14}
        ];
        let best = Qt.point(root.inset, root.inset);
        let leastOverlap = Infinity;
        for (const candidate of candidates) {
            const x = Math.max(root.inset, Math.min(maxX, candidate.x));
            const y = Math.max(root.inset, Math.min(maxY, candidate.y));
            const overlapWidth = Math.max(0, Math.min(x + card.width, panel.x + panel.width) - Math.max(x, panel.x));
            const overlapHeight = Math.max(0, Math.min(y + card.height, panel.y + panel.height) - Math.max(y, panel.y));
            const overlap = overlapWidth * overlapHeight;
            if (overlap < leastOverlap) {
                leastOverlap = overlap;
                best = Qt.point(x, y);
            }
        }
        return best;
    }
    readonly property real cardX: cardPosition.x
    readonly property real cardY: cardPosition.y
    FocusScrim {
        anchors.fill: parent
        focusX: root.instrumentRect.x
        focusY: root.instrumentRect.y
        focusWidth: root.instrumentRect.width
        focusHeight: root.instrumentRect.height
        focusRadius: Theme.radiusLarge
        halo: 4
        dim: 0.58
        opacity: root.settled ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motionNormal } }
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: ShellState.closeWidgetSettings()
    }
    WidgetSettingsBody {
        id: card
        x: root.cardX; y: root.cardY
        width: Math.min(implicitWidth, Math.max(0, root.width - root.inset * 2))
        height: Math.min(implicitHeight, Math.max(0, root.height - root.inset * 2))
        widgetId: ShellState.activeWidgetSettingsId
        compactInstrument: ShellState.quickInstrument
        focus: true
        opacity: root.settled ? 1 : 0
        scale: root.settled ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
        Behavior on scale { NumberAnimation { duration: Theme.motionNormal; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
        onCloseRequested: ShellState.closeWidgetSettings()
        onAllSettingsRequested: { ShellState.closeWidgetSettings(); ShellState.openEphemeris("settings", root.modelData.name); }
    }
}
