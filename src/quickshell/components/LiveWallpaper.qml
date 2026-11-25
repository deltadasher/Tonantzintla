import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "LiveScenes.js" as LiveScenes

// One live scene on an output's background layer. Unlike NativeWallpaper this
// surface takes pointer input, so scenes can react to the cursor wherever no
// application window covers them. Scenes are loaded by URL: a missing optional
// QML module fails that one scene and reports it, without touching the shell.
PanelWindow {
    id: root
    required property var modelData
    property string sceneId: ""
    readonly property var definition: LiveScenes.find(sceneId)
    readonly property var values: LiveScenes.values(definition, Settings.liveWallpaperProps)
    readonly property bool ready: scene.status === Loader.Ready
    signal sceneFailed(string outputName, string message)

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#000000"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "tonantzintla-live-wallpaper"

    Loader {
        id: scene
        anchors.fill: parent
        source: root.definition ? Qt.resolvedUrl("live/" + root.definition.component) : ""
        onStatusChanged: if (status === Loader.Error)
            root.sceneFailed(root.modelData.name, (root.definition ? root.definition.name : "Live wallpaper") + " could not start on this system.")
    }
    Binding { target: scene.item; property: "values"; value: root.values; when: root.ready }
    // Reduced or instant motion holds the scene on a still frame.
    Binding { target: scene.item; property: "running"; value: Theme.motionEnabled; when: root.ready }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        function track(active) {
            if (!scene.item) return;
            scene.item.pointerActive = active;
            if (active) scene.item.pointer = Qt.point(mouseX, mouseY);
        }
        onPositionChanged: track(true)
        onEntered: track(true)
        onExited: track(false)
        onPressed: mouse => { if (scene.item) scene.item.pulse(mouse.x, mouse.y); }
    }
}
