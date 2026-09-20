pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../.."
import ".."

PanelWindow {
    id: root
    required property var modelData
    property bool transitionActive: false
    property real aperture: 0
    readonly property bool motionEnabled: Settings.motion && Settings.umbraMotion
    screen: modelData
    anchors { top: true; right: true; bottom: true; left: true }
    visible: transitionActive
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tonantzintla-umbra-reveal"

    function beginReveal() {
        revealSequence.stop();
        aperture = 0;
        transitionActive = true;
        revealSequence.restart();
    }
    Connections {
        target: ShellState
        function onUmbraRevealSerialChanged() { root.beginReveal(); }
    }
    Component.onCompleted: if (ShellState.umbraRevealSerial > 0) beginReveal()
    onMotionEnabledChanged: {
        if (!motionEnabled && transitionActive) {
            revealSequence.stop();
            transitionActive = false;
        }
    }
    SequentialAnimation {
        id: revealSequence
        // Preserve the existing authenticated release handoff deadline.
        PauseAnimation { duration: root.motionEnabled ? 1510 : 45 }
        NumberAnimation {
            target: root; property: "aperture"; from: 0; to: 1
            duration: root.motionEnabled ? 880 : 0
            easing.type: Easing.Linear
        }
        ScriptAction { script: root.transitionActive = false }
    }
    Loader {
        anchors.fill: parent
        active: root.transitionActive
        sourceComponent: UmbraAperture { progress: root.aperture }
    }
}
