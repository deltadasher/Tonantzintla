pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../services"

PanelWindow {
    id: root

    property bool outroActive: false
    property real aperture: 0
    readonly property bool motionEnabled: Settings.motion && Settings.umbraMotion
    required property var modelData
    screen: modelData
    readonly property bool targetScreen: Compositor.focusedOutput.length > 0
        ? Compositor.focusedOutput === modelData.name
        : Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]

    anchors { top: true; right: true; bottom: true; left: true }
    visible: (Umbra.previewActive || outroActive) && targetScreen
    // Request an alpha-capable surface from creation; changing an opaque
    // window to transparent only at unlock can produce a black aperture.
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: visible && Umbra.previewActive
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible && Umbra.previewActive
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "tonantzintla-umbra-preview"

    Rectangle {
        anchors.fill: parent
        color: Theme.void_
        visible: Umbra.previewActive
    }
    Loader {
        anchors.fill: parent
        active: Umbra.previewActive && root.targetScreen
        sourceComponent: umbraSurfaceComponent
    }

    Connections {
        target: Umbra
        function onPreviewUnlocked() {
            if (!root.targetScreen || !root.motionEnabled) return;
            root.aperture = 0;
            root.outroActive = true;
            outro.restart();
        }
        function onPreviewActiveChanged() {
            if (Umbra.previewActive) {
                outro.stop();
                root.outroActive = false;
            }
        }
    }
    onMotionEnabledChanged: {
        if (!motionEnabled) { outro.stop(); outroActive = false; }
    }
    SequentialAnimation {
        id: outro
        NumberAnimation {
            target: root; property: "aperture"; from: 0; to: 1
            duration: 880; easing.type: Easing.Linear
        }
        ScriptAction { script: root.outroActive = false }
    }
    Loader {
        anchors.fill: parent
        active: root.outroActive
        sourceComponent: UmbraAperture { progress: root.aperture }
    }

    Component {
        id: umbraSurfaceComponent

        UmbraSurface {
            previewMode: true
            screenInfo: root.modelData
            onDismissPreview: Umbra.closePreview()
        }
    }
}
