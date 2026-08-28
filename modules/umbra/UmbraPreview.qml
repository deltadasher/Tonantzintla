import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../services"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property bool targetScreen: Niri.focusedOutput.length > 0
        ? Niri.focusedOutput === modelData.name
        : Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]

    anchors { top: true; right: true; bottom: true; left: true }
    visible: Umbra.previewActive && targetScreen
    color: Theme.void_
    exclusionMode: ExclusionMode.Ignore
    focusable: visible
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "astralith-umbra-preview"

    Loader {
        anchors.fill: parent
        active: root.visible
        sourceComponent: umbraSurfaceComponent
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
