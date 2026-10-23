import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../components"
import "../../components/FeedbackPlacement.js" as Placement
import "../../components/ApertureMetrics.js" as ApertureMetrics
import "../../services"

pragma ComponentBehavior: Bound

PanelWindow {

    id: root
    readonly property string outputName: screen ? screen.name : ""
    readonly property real outputWidth: screen ? screen.width : 1920
    readonly property real outputHeight: screen ? screen.height : 1080
    function edgeClearance(edge) {
        return Settings.edgeHasIslands(outputName,edge)
            ? ApertureMetrics.clearance(edge,true,Settings.compact,Settings.barHeightProfile,Theme.barHeight,Settings.barMode,Settings.barMargin)+0
            : 14;
    }
    readonly property var clearances: ({top:edgeClearance("top"),bottom:edgeClearance("bottom"),left:edgeClearance("left"),right:edgeClearance("right")})
    readonly property var selectedPosition: Settings.notificationCustomPosition
        ? ({x:Settings.notificationX,y:Settings.notificationY}) : Placement.preset(["top-left","top","top-center","top-right","left","center","right","bottom-left","bottom","bottom-center","bottom-right"].indexOf(Settings.notificationPosition)>=0 ? Settings.notificationPosition : "top-right")
    readonly property var placement: Placement.place(outputWidth,outputHeight,
        Placement.notificationWidth(Settings.notificationWidth),Math.max(1,Math.min(popupList.contentHeight,outputHeight*.72)),
        clearances,selectedPosition.x,selectedPosition.y)
    anchors { top: true; left: true }
    margins.top: Math.round(placement.y)
    margins.left: Math.round(placement.x)
    implicitWidth: Math.floor(placement.width)
    implicitHeight: Math.floor(placement.height)
    visible: Notifications.popups.count > 0 && !Settings.doNotDisturb
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tonantzintla-transit-popups"

    Item {
        anchors.fill: parent
        property var opticalBackdrop: opticalField
        OpticalBackdrop {
            id: opticalField
            anchors.fill: parent
            active: root.visible
            scope: "instruments"
            viewportSize: Qt.size(root.outputWidth,root.outputHeight)
            viewportOffset: Qt.point(root.margins.left,root.margins.top)
        }
    ListView {
        id: popupList
        anchors.fill: parent
        model: Notifications.popups
        spacing: 8
        clip: true
        interactive: contentHeight > height

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Settings.motion && Theme.motionScale > 0 ? 260 : 0; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: 90; to: 0; duration: Settings.motion && Theme.motionScale > 0 ? 340 : 0; easing.type: Easing.OutBack }
                NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: Settings.motion && Theme.motionScale > 0 ? 300 : 0; easing.type: Easing.OutCubic }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: Settings.motion && Theme.motionScale > 0 ? 180 : 0; easing.type: Easing.InCubic }
                NumberAnimation { property: "x"; to: 80; duration: Settings.motion && Theme.motionScale > 0 ? 220 : 0; easing.type: Easing.InCubic }
            }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: Settings.motion && Theme.motionScale > 0 ? 260 : 0; easing.type: Easing.OutCubic }
        }

        delegate: NotificationCard {
            required property var model
            uid: model.uid
            appName: model.appName
            summary: model.summary
            body: model.body
            icon: model.icon
            time: model.time
            critical: model.critical
            receivedAt: model.receivedAt
            urgency: model.urgency
            count: model.count
            actions: model.actions || []
            width: popupList.width
            popup: true
            onActivated: Notifications.invokeDefault(uid)
            onActionInvoked: function(identifier) { Notifications.invokeAction(uid, identifier); }
            onDismissed: Notifications.removeHistory(uid)
            onExpired: Notifications.removePopup(uid)
        }
    }
    }
}
