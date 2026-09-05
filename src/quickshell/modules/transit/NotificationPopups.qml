import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../components"
import "../../services"

pragma ComponentBehavior: Bound

PanelWindow {

    anchors { top: true; right: true }
    // qmllint disable unqualified
    // qmllint disable unresolved-type
    margins {
        top: (Settings.compact ? 38 : Theme.barHeight)
            + (Settings.barMode === "docked" ? 8 : Settings.barMargin * 2 + 7)
        right: 14
    }
    // qmllint enable unresolved-type
    // qmllint enable unqualified
    implicitWidth: 390
    implicitHeight: Math.min(popupList.contentHeight, screen ? screen.height * 0.72 : 700)
    visible: Notifications.popups.count > 0 && !Settings.doNotDisturb
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tonantzintla-transit-popups"

    ListView {
        id: popupList
        anchors.fill: parent
        model: Notifications.popups
        spacing: 8
        interactive: false

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: 90; to: 0; duration: 340; easing.type: Easing.OutBack }
                NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: 300; easing.type: Easing.OutCubic }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 180; easing.type: Easing.InCubic }
                NumberAnimation { property: "x"; to: 80; duration: 220; easing.type: Easing.InCubic }
            }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 260; easing.type: Easing.OutCubic }
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
