import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../services"
import "../../components"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property bool targetScreen: Compositor.focusedOutput.length > 0
        ? Compositor.focusedOutput === modelData.name
        : Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]
    property real presentation: 0

    anchors { bottom: true }
    margins.bottom: Settings.edgeHasIslands(modelData.name, "bottom")
        ? Theme.barHeight + Settings.barMargin * 2 + 12 : 24
    implicitWidth: Math.min(330, Math.max(160, modelData.width - 32))
    implicitHeight: 74
    visible: (Osd.visible || presentation > 0.01) && targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tonantzintla-orbit-osd"

    function pulse() {
        dismiss.stop();
        if (presentation < 1 && !reveal.running) reveal.restart();
    }

    Component.onCompleted: {
        if (Osd.visible && targetScreen)
            pulse();
    }

    Connections {
        target: Osd
        function onSerialChanged() {
            if (root.targetScreen && Osd.visible)
                root.pulse();
        }
        function onVisibleChanged() {
            if (Osd.visible && root.targetScreen) {
                root.pulse();
            } else if (!Osd.visible && root.presentation > 0.01) {
                reveal.stop();
                dismiss.restart();
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: root.visible
        sourceComponent: osdContent
    }

    Component {
        id: osdContent
        OsdBody { presentation: root.presentation }
    }
    NumberAnimation {
        id: reveal
        target: root
        property: "presentation"
        to: 1
        duration: Theme.motionScale > 0 ? Theme.motionNormal : 0
        easing.type: Easing.OutBack
    }

    NumberAnimation {
        id: dismiss
        target: root
        property: "presentation"
        to: 0
        duration: Theme.motionScale > 0 ? Theme.motionFast : 0
        easing.type: Easing.InCubic
    }
}
