import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../services"
import "../../components"
import "widgets"
import "../quickactions"
import "EphemerisRegistry.js" as Registry

PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property string outputName: modelData.name
    readonly property bool targetScreen: Compositor.focusedOutput.length > 0
        ? Compositor.focusedOutput === outputName
        : Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]
    readonly property int topClearance: (Settings.compact ? 38 : Theme.barHeight)
        + (Settings.barMode === "docked" ? 10 : Settings.barMargin * 2 + 8)
    readonly property var widgetLayout: Registry.getLayout(
        ShellState.ephemerisTab, width, height, topClearance)
    readonly property color moduleTone: Theme.moduleAccent(ShellState.ephemerisTab)
    readonly property bool immersiveWidget: ShellState.ephemerisTab === "walls"

    property bool surfaceVisible: false
    property real presentation: 0
    property real deckScale: 0.94
    property real widgetPresentation: 1
    property bool opening: false
    property bool widgetDeploymentPending: false

    visible: surfaceVisible && targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "tonantzintla-ephemeris-host"
    anchors { top: true; right: true; bottom: true; left: true }

    function close() {
        ShellState.closeEphemeris();
    }

    function focusWidget() {
        if (widgetLoader.item && widgetLoader.item.focusPrimary)
            widgetLoader.item.focusPrimary();
        else
            keyCatcher.forceActiveFocus();
    }

    function deployWidget() {
        if (!widgetDeploymentPending || !widgetLoader.item)
            return;
        if (widgetLoader.item.beginDeployment)
            widgetLoader.item.beginDeployment();
        widgetDeploymentPending = false;
    }

    function beginOpen() {
        closeAnimation.stop();
        widgetSwitch.stop();
        opening = true;
        widgetDeploymentPending = true;
        surfaceVisible = true;
        presentation = 0;
        deckScale = 0.92;
        widgetPresentation = 0;
        openDelay.restart();
    }

    function beginClose() {
        opening = false;
        openDelay.stop();
        openAnimation.stop();
        closeAnimation.restart();
    }

    Connections {
        target: ShellState
        function onEphemerisVisibleChanged() {
            if (ShellState.ephemerisVisible && root.targetScreen)
                root.beginOpen();
            else if (root.surfaceVisible)
                root.beginClose();
        }
        function onEphemerisTabChanged() {
            if (!ShellState.ephemerisVisible || !root.surfaceVisible || root.opening)
                return;
            root.widgetDeploymentPending = true;
            root.widgetPresentation = 0;
            widgetSwitch.restart();
        }
    }

    onTargetScreenChanged: {
        if (targetScreen && ShellState.ephemerisVisible)
            beginOpen();
        else if (!targetScreen && surfaceVisible)
            surfaceVisible = false;
    }

    Component.onCompleted: {
        if (ShellState.ephemerisVisible && targetScreen)
            beginOpen();
    }

    Timer {
        id: openDelay
        interval: 24
        onTriggered: {
            // The popup and its widget choreography share one launch pulse.
            root.deployWidget();
            openAnimation.restart();
        }
    }

    ParallelAnimation {
        id: openAnimation
        NumberAnimation { target: root; property: "presentation"; to: 1; duration: Settings.motion ? 260 : 0; easing.type: Easing.OutQuint }
        NumberAnimation { target: root; property: "deckScale"; to: 1; duration: Settings.motion ? 430 : 0; easing.type: Easing.OutBack }
        SequentialAnimation {
            PauseAnimation { duration: Settings.motion ? 90 : 0 }
            NumberAnimation { target: root; property: "widgetPresentation"; to: 1; duration: Settings.motion ? 250 : 0; easing.type: Easing.OutCubic }
            ScriptAction {
                script: {
                    root.opening = false;
                    root.deployWidget();
                    root.focusWidget();
                }
            }
        }
    }

    SequentialAnimation {
        id: closeAnimation
        ParallelAnimation {
            NumberAnimation { target: root; property: "widgetPresentation"; to: 0; duration: Settings.motion ? 100 : 0; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "presentation"; to: 0; duration: Settings.motion ? 180 : 0; easing.type: Easing.InQuint }
            NumberAnimation { target: root; property: "deckScale"; to: 0.96; duration: Settings.motion ? 180 : 0; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.surfaceVisible = false }
    }

    SequentialAnimation {
        id: widgetSwitch
        PauseAnimation { duration: Settings.motion ? 55 : 0 }
        NumberAnimation { target: root; property: "widgetPresentation"; to: 1; duration: Settings.motion ? 220 : 0; easing.type: Easing.OutCubic }
        ScriptAction {
            script: {
                root.deployWidget();
                root.focusWidget();
            }
        }
    }

    Rectangle {
        id: veil
        anchors.fill: parent
        color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b,
            root.immersiveWidget ? 0.24 : 0.16)
        opacity: root.presentation

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Loader {
            anchors.fill: parent
            active: root.surfaceVisible
            source: active ? "TonantzintlaMorphBackdrop.qml" : ""

            property var layout: root.widgetLayout
            property real reveal: root.presentation
            property color tone: root.moduleTone
            property string tab: ShellState.ephemerisTab
            property int clearance: root.topClearance
        }

        Rectangle {
            x: root.widgetLayout.x
            y: root.widgetLayout.y
            width: root.widgetLayout.width
            height: root.widgetLayout.height
            radius: 0
            color: "transparent"
            border.width: 0
            opacity: root.presentation
            scale: 1
            transformOrigin: Item.Center
            // The veil is deliberately inert. Every decorative signal belongs
            // to the popup and is clipped at this boundary.
            clip: true

            // Hidden surfaces snap to their next layout. Geometry only morphs
            // while an already-open Ephemeris changes modules; otherwise the
            // previous widget's boundary can flash for a frame during launch.
            Behavior on x {
                enabled: ShellState.ephemerisVisible && root.surfaceVisible
                    && !root.opening && root.presentation > 0.99
                NumberAnimation { duration: Settings.motion ? 270 : 0; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: ShellState.ephemerisVisible && root.surfaceVisible
                    && !root.opening && root.presentation > 0.99
                NumberAnimation { duration: Settings.motion ? 270 : 0; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                enabled: ShellState.ephemerisVisible && root.surfaceVisible
                    && !root.opening && root.presentation > 0.99
                NumberAnimation { duration: Settings.motion ? 300 : 0; easing.type: Easing.OutCubic }
            }
            Behavior on height {
                enabled: ShellState.ephemerisVisible && root.surfaceVisible
                    && !root.opening && root.presentation > 0.99
                NumberAnimation { duration: Settings.motion ? 300 : 0; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                // Parallax deliberately has no enclosing card, so its empty
                // field is the natural dismissal target. Interactive bodies
                // and controls sit above this catcher and retain their clicks.
                onClicked: if (root.immersiveWidget) root.close()
            }

            EccentricPlate {
                anchors.fill: parent
                visible: false
                fillColor: Theme.glass
                lineColor: "transparent"
                tone: root.moduleTone
                cut: Settings.atmosphereStyle === "cinematic" ? 28 : 20
                energy: root.widgetPresentation
            }

            EphemerisAtmosphere {
                anchors.fill: parent
                anchors.topMargin: 0
                visible: !root.immersiveWidget
                module: ShellState.ephemerisTab
                presentation: root.widgetPresentation
            }

            Item {
                id: keyCatcher
                anchors.fill: parent
                anchors.topMargin: 0
                focus: true
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        root.close();
                        event.accepted = true;
                    }
                }

                Loader {
                    id: widgetLoader
                    anchors.fill: parent
                    anchors.margins: root.immersiveWidget ? 8 : 20
                    active: root.surfaceVisible
                    opacity: root.widgetPresentation
                    transform: Translate { y: (1 - root.widgetPresentation) * 14 }
                    sourceComponent: ShellState.ephemerisTab === "tools" ? toolsComponent
                        : ShellState.ephemerisTab === "walls" ? wallpaperComponent
                        : ShellState.ephemerisTab === "clipboard" ? clipboardComponent
                        : ShellState.ephemerisTab === "notifications" ? notificationsComponent
                        : ShellState.ephemerisTab === "settings" ? settingsComponent
                        : ShellState.ephemerisTab === "calendar" ? calendarComponent
                        : ShellState.ephemerisTab === "capture" ? captureComponent
                        : ShellState.ephemerisTab === "media" ? mediaComponent
                        : ShellState.ephemerisTab === "network" ? networkComponent
                        : ShellState.ephemerisTab === "audio" ? audioComponent
                        : ShellState.ephemerisTab === "workspaces" ? workspacesComponent
                        : ShellState.ephemerisTab === "battery" ? batteryComponent
                        : ShellState.ephemerisTab === "focus" ? focusComponent
                        : ShellState.ephemerisTab === "system" ? systemComponent
                        : ShellState.ephemerisTab === "guide" ? guideComponent
                        : ShellState.ephemerisTab === "timer" ? timerComponent
                        : ShellState.ephemerisTab === "quickstats" ? quickStatsComponent
                        : launcherComponent
                    onLoaded: {
                        Qt.callLater(root.deployWidget);
                        Qt.callLater(root.focusWidget);
                    }
                }
            }

        }
    }

    Component { id: launcherComponent; LauncherWidget {} }
    Component { id: toolsComponent; ToolsWidget {} }
    Component { id: wallpaperComponent; WallpaperWidget {} }
    Component { id: clipboardComponent; ClipboardWidget {} }
    Component { id: notificationsComponent; NotificationsWidget {} }
    Component { id: settingsComponent; SettingsWidget {} }
    Component { id: calendarComponent; CalendarWidget {} }
    Component { id: captureComponent; CaptureWidget {} }
    Component { id: mediaComponent; MediaWidget {} }
    Component { id: networkComponent; NetworkWidget {} }
    Component { id: audioComponent; AudioWidget {} }
    Component { id: workspacesComponent; WorkspaceWidget {} }
    Component { id: batteryComponent; BatteryWidget {} }
    // Dedicated behavioral widgets remain independently loadable and morph in place.
    Component { id: focusComponent; FocusWidget {} }
    // Observatory telemetry and the full mixer share the same morphing host.
    Component { id: systemComponent; SystemWidget {} }
    Component { id: guideComponent; GuideWidget {} }
    Component { id: timerComponent; TimerAction {} }
    Component { id: quickStatsComponent; TelemetryAction {} }
}
