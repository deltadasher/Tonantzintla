import QtQuick
import "../.."

Item {
    id: root

    readonly property var layout: parent.layout
    readonly property real reveal: parent.reveal
    readonly property color tone: parent.tone
    readonly property string tab: parent.tab

    readonly property real sourceWidth: tab === "media" ? 132
        : tab === "calendar" ? 154 : 48
    readonly property real sourceX: {
        if (tab === "calendar")
            return Math.round((width - sourceWidth) / 2);
        if (tab === "notifications" || tab === "network" || tab === "audio"
                || tab === "battery" || tab === "settings" || tab === "tools")
            return width - sourceWidth - Math.max(10, Settings.barMargin);
        if (tab === "media")
            return 248;
        if (tab === "workspaces")
            return 160;
        if (tab === "walls")
            return 72;
        if (tab === "apps")
            return 42;
        return Math.max(10, Settings.barMargin);
    }
    readonly property real sourceY: Settings.barMode === "docked"
        ? 2 : Math.max(4, Settings.barMargin)
    readonly property real sourceHeight: Settings.compact ? 34 : Theme.barHeight
    readonly property real eased: {
        const amount = Math.max(0, Math.min(1, reveal));
        return 1 - Math.pow(1 - amount, 4);
    }

    function mix(from, to) {
        return from + (to - from) * eased;
    }

    Rectangle {
        visible: root.tab !== "walls" && root.layout
        x: root.mix(root.sourceX, Number(root.layout.x || 0))
        y: root.mix(root.sourceY, Number(root.layout.y || 0))
        width: root.mix(root.sourceWidth, Number(root.layout.width || 0))
        height: root.mix(root.sourceHeight, Number(root.layout.height || 0))
        radius: root.mix(root.sourceHeight / 2, 26)
        color: Theme.mantle
    }
}
