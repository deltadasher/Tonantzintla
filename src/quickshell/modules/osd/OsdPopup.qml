import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../services"
import "../../components"
import "../../components/FeedbackPlacement.js" as Placement
import "../../components/ApertureMetrics.js" as ApertureMetrics

PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property bool targetScreen: Compositor.focusedOutput.length > 0
        ? Compositor.focusedOutput === modelData.name
        : Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]
    property real presentation: 0

    readonly property string position: ["top","bottom","left","right","center"].indexOf(Settings.osdPosition)>=0 ? Settings.osdPosition : "bottom"
    readonly property bool vertical: Settings.osdOrientation === "vertical"
    function edgeClearance(edge) {
        return Settings.edgeHasIslands(modelData.name,edge)
            ? ApertureMetrics.clearance(edge,true,Settings.compact,Settings.barHeightProfile,Theme.barHeight,Settings.barMode,Settings.barMargin)+4
            : 24;
    }
    readonly property var clearances: ({top:edgeClearance("top"),bottom:edgeClearance("bottom"),left:edgeClearance("left"),right:edgeClearance("right")})
    readonly property var selectedPosition: Settings.osdCustomPosition
        ? ({x:Settings.osdX,y:Settings.osdY}) : Placement.preset(position)
    readonly property var placement: Placement.place(modelData.width,modelData.height,
        vertical ? 120 : 330,vertical ? 260 : 74,clearances,selectedPosition.x,selectedPosition.y)
    anchors { top: true; left: true }
    margins.top: Math.round(placement.y)
    margins.left: Math.round(placement.x)
    implicitWidth: Math.floor(placement.width)
    implicitHeight: Math.floor(placement.height)
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
