import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.."

PanelWindow {
    id: root
    required property var modelData
    required property string edge
    screen: modelData
    readonly property bool isVertical: edge === "left" || edge === "right"
    readonly property bool isBottom: edge === "bottom"
    readonly property bool isRight: edge === "right"

    anchors {
        top: !isBottom
        bottom: isVertical || isBottom
        left: !isRight
        right: isVertical ? isRight : true
    }
    implicitWidth: isVertical ? contents.implicitWidth : 0
    implicitHeight: isVertical ? 0 : contents.implicitHeight
    color: "transparent"
    visible: contents.hasIslands
    exclusionMode: visible ? ExclusionMode.Auto : ExclusionMode.Ignore
    WlrLayershell.layer: ShellState.barEditMode ? WlrLayer.Overlay : WlrLayer.Top
    ApertureContents {
        id: contents
        anchors.fill: parent
        outputName: root.modelData.name
        edge: root.edge
        screenWidth: root.modelData.width
        screenHeight: root.modelData.height
    }
}
