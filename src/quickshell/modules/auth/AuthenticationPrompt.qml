import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import "../.."
import "../../services"
import "../../components"
import "."

Scope {
    id: root
    property var requestScreen: null
    // Registration never displaces another agent. Existing external ownership wins.
    PolkitAgent {
        id: agent
        onIsRegisteredChanged: {
            Authentication.registered = isRegistered;
            Authentication.status = isRegistered ? "Native authentication ready"
                : "Native agent unavailable; check external agent ownership";
        }
        onAuthenticationRequestStarted: {
            root.requestScreen = Quickshell.screens.find(function(s) { return s.name === Compositor.focusedOutput; }) || Quickshell.screens[0];
            ShellState.closeEphemeris();
        }
    }
    Timer {
        interval: 1500; running: true
        onTriggered: if (!agent.isRegistered) Authentication.status = "Native agent unavailable; check external agent ownership"
    }
    Connections {
        target: Authentication
        function onCancelRequested() { if (agent.flow) agent.flow.cancelAuthenticationRequest(); }
    }
    Component.onDestruction: Authentication.registered = false
    PanelWindow {
        id: window
        screen: root.requestScreen && Quickshell.screens.indexOf(root.requestScreen) >= 0 ? root.requestScreen : Quickshell.screens[0]
        visible: agent.isActive
        anchors { top: true; right: true; bottom: true; left: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "tonantzintla-authentication"
        color: "transparent"
        onVisibleChanged: { card.clearResponse(); if (visible) Qt.callLater(function() { card.focusPrimary(); }); }
        Rectangle { anchors.fill: parent; color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.72) }
        AuthenticationCard {
            id: card
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 32)
            height: implicitHeight
            flow: agent.flow
        }
    }
}
