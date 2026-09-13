import QtQuick
import Quickshell
import Quickshell.Widgets
import "components"

// Isolated visual harness; no PanelWindow, lock, compositor edits or IPC.
Window {
    width: 1100; height: 780
    visible: true
    title: "Tonantzintla instrument geometry preview · Space pauses"
    color: "#151219"
    InstrumentGeometry {
        id: previewGeometry
        origin: Qt.rect(48, 16, 48, 40)
        destination: Qt.rect(32, 100, 1000, 620)
    }
    InstrumentBridge { anchors.fill: parent; geometry: previewGeometry }
    ClippingRectangle {
        x: previewGeometry.x; y: previewGeometry.y
        width: previewGeometry.width; height: previewGeometry.height; radius: previewGeometry.radius
        color: "#24202b"
        Rectangle { x: 0; y: 0; width: 1000; height: 40; color: "#cbb8ff" }
        Text { x: 24; y: 70; text: "Shared body, contents and clipping"; color: "white" }
    }
    SequentialAnimation {
        id: animation
        running: true; loops: Animation.Infinite
        NumberAnimation { target: previewGeometry; property: "progress"; to: 1; duration: 650; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 700 }
        NumberAnimation { target: previewGeometry; property: "progress"; to: 0; duration: 450; easing.type: Easing.InCubic }
        PauseAnimation { duration: 400 }
    }
    Item {
        anchors.fill: parent; focus: true
        Keys.onSpacePressed: animation.paused = !animation.paused
    }
}
