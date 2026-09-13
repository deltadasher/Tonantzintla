import QtQuick
import "../../../components"
import "../../.."

Loader {
    id: root
    property string islandId: ""
    property string outputName: ""
    property var barWindow: null

    active: islandId !== ""
    asynchronous: false

    source: {
        switch (islandId) {
            case "launcher": return Qt.resolvedUrl("LauncherIsland.qml");
            case "workspaces": return Qt.resolvedUrl("WorkspacesIsland.qml");
            case "media": return Qt.resolvedUrl("MediaIsland.qml");
            case "window_title": return Qt.resolvedUrl("WindowTitleIsland.qml");
            case "clock": return Qt.resolvedUrl("ClockIsland.qml");
            case "system_stats": return Qt.resolvedUrl("SystemStatsIsland.qml");
            case "status": return Qt.resolvedUrl("StatusIsland.qml");
            case "tray": return Qt.resolvedUrl("TrayIsland.qml");
            case "controls": return Qt.resolvedUrl("ControlsIsland.qml");
            default: return "";
        }
    }

    onLoaded: {
        if (item) {
            if (islandId === "workspaces") {
                item.outputName = Qt.binding(function() { return root.outputName; });
            }
            if (root.barWindow) {
                item.barWindow = Qt.binding(function() { return root.barWindow; });
            }
        }
    }

    visible: status === Loader.Ready && item !== null && item.islandVisible
    width: visible && item ? item.implicitWidth : 0
    height: visible && item ? item.implicitHeight : 0

    // Grid reflow is still deterministic, but the island should travel to its
    // new slot instead of teleporting when a preset or drop changes the order.
    Behavior on x { NumberAnimation { duration: Settings.motion ? 260 : 0; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: Settings.motion ? 260 : 0; easing.type: Easing.OutCubic } }
    Behavior on width { NumberAnimation { duration: Settings.motion ? 180 : 0; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: Settings.motion ? 180 : 0; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Settings.motion ? 180 : 0; easing.type: Easing.OutCubic } }
}
