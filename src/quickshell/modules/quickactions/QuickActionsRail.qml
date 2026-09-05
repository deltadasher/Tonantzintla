import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../services"
import "../../components"
import "../ephemeris"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property bool targetScreen: Compositor.focusedOutput.length > 0
        ? Compositor.focusedOutput === modelData.name
        : Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]
    readonly property bool leftEdge: Settings.quickActionsEdge === "left"
    readonly property int tabWidth: 52
    readonly property string instrumentModule: ShellState.quickActionTab === "telemetry"
        ? "quickstats" : "timer"
    readonly property color instrumentTone: Theme.moduleAccent(instrumentModule)

    property bool surfaceVisible: false
    property real presentation: 0
    property real contentPresentation: 1

    anchors {
        left: root.leftEdge
        right: !root.leftEdge
    }
    margins.left: root.leftEdge ? 12 : 0
    margins.right: root.leftEdge ? 0 : 12
    implicitWidth: 590
    implicitHeight: 520
    visible: Settings.quickActionsEnabled && surfaceVisible && targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: visible
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "tonantzintla-quick-actions"

    function beginOpen() {
        closeAnimation.stop();
        surfaceVisible = true;
        presentation = 0;
        contentPresentation = 0;
        openDelay.restart();
    }

    function beginClose() {
        openDelay.stop();
        openAnimation.stop();
        closeAnimation.restart();
    }

    function selectAction(name) {
        if (ShellState.quickActionTab !== name)
            ShellState.openQuickActions(name);
    }

    Connections {
        target: ShellState
        function onQuickActionsVisibleChanged() {
            if (ShellState.quickActionsVisible && root.targetScreen)
                root.beginOpen();
            else if (root.surfaceVisible)
                root.beginClose();
        }
        function onQuickActionTabChanged() {
            if (!root.surfaceVisible)
                return;
            root.contentPresentation = 0;
            contentSwitch.restart();
        }
    }

    onTargetScreenChanged: {
        if (targetScreen && ShellState.quickActionsVisible)
            beginOpen();
        else if (!targetScreen && surfaceVisible)
            surfaceVisible = false;
    }

    Component.onCompleted: {
        if (ShellState.quickActionsVisible && targetScreen)
            beginOpen();
    }

    Timer {
        id: openDelay
        interval: 18
        onTriggered: openAnimation.restart()
    }

    ParallelAnimation {
        id: openAnimation
        NumberAnimation { target: root; property: "presentation"; to: 1; duration: Settings.motion ? 260 : 0; easing.type: Easing.OutExpo }
        SequentialAnimation {
            PauseAnimation { duration: Settings.motion ? 55 : 0 }
            NumberAnimation { target: root; property: "contentPresentation"; to: 1; duration: Settings.motion ? 190 : 0; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: closeAnimation
        ParallelAnimation {
            NumberAnimation { target: root; property: "contentPresentation"; to: 0; duration: Settings.motion ? 90 : 0; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "presentation"; to: 0; duration: Settings.motion ? 170 : 0; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.surfaceVisible = false }
    }

    SequentialAnimation {
        id: contentSwitch
        PauseAnimation { duration: Settings.motion ? 45 : 0 }
        NumberAnimation { target: root; property: "contentPresentation"; to: 1; duration: Settings.motion ? 170 : 0; easing.type: Easing.OutCubic }
    }

    Rectangle {
        width: parent.width
        height: parent.height
        x: root.leftEdge ? (root.presentation - 1) * (width + 20)
            : (1 - root.presentation) * (width + 20)
        opacity: root.presentation
        scale: 0.985 + root.presentation * 0.015
        radius: Theme.radiusLarge
        color: Theme.glass
        border.width: 0
        border.color: Theme.barHairlineHover
        clip: true

        MouseArea { anchors.fill: parent }

        EphemerisAtmosphere {
            anchors.fill: parent
            module: root.instrumentModule
            presentation: root.contentPresentation
        }

        InstrumentFrame {
            anchors.fill: parent
            anchors.margins: 6
            module: root.instrumentModule
            presentation: root.contentPresentation
        }

        Rectangle {
            x: root.leftEdge ? root.tabWidth : 0
            width: parent.width - root.tabWidth
            height: parent.height
            color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.34)

            Loader {
                anchors.fill: parent
                anchors.margins: 15
                active: root.surfaceVisible
                sourceComponent: ShellState.quickActionTab === "telemetry"
                    ? telemetryComponent : timerComponent
                opacity: root.contentPresentation
                transform: Translate {
                    x: (1 - root.contentPresentation) * (root.leftEdge ? -10 : 10)
                }
            }
        }

        Rectangle {
            x: root.leftEdge ? 0 : parent.width - root.tabWidth
            width: root.tabWidth
            height: parent.height
            color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.88)

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 8

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 11
                    color: Qt.rgba(root.instrumentTone.r, root.instrumentTone.g, root.instrumentTone.b, 0.12)
                    border.width: 0
                    border.color: Qt.rgba(root.instrumentTone.r, root.instrumentTone.g, root.instrumentTone.b, 0.38)
                    Text { anchors.centerIn: parent; text: "✦"; color: root.instrumentTone; font.family: Theme.fontDisplay; font.pixelSize: 15; font.weight: Font.Bold }
                }

                Item { Layout.preferredHeight: 12 }

                Repeater {
                    model: [
                        { "name": "timer", "glyph": "◷" },
                        { "name": "telemetry", "glyph": "⌁" }
                    ]
                    Rectangle {
                        id: actionButton
                        required property var modelData
                        readonly property bool active: ShellState.quickActionTab === modelData.name
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 36; Layout.preferredHeight: 46; radius: 11
                        color: active ? root.instrumentTone : actionPointer.containsMouse ? Theme.elevated : "transparent"
                        border.width: 0
                        border.color: active ? root.instrumentTone : actionPointer.containsMouse ? Theme.lineBright : "transparent"
                        Column { anchors.centerIn: parent; spacing: 1
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: actionButton.modelData.glyph; color: actionButton.active ? Theme.void_ : Theme.moon; font.family: Theme.fontIcon; font.pixelSize: 15; font.weight: Font.Bold }
                            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; visible: actionButton.modelData.name === "timer" && Timekeeper.anyRunning; width: 5; height: 5; radius: 3; color: actionButton.active ? Theme.void_ : Theme.success }
                        }
                        MouseArea { id: actionPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selectAction(actionButton.modelData.name) }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    visible: Timekeeper.anyRunning
                    Layout.alignment: Qt.AlignHCenter
                    text: Timekeeper.activeCode + "\n" + Timekeeper.activeDisplay
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.success
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 11
                    color: closePointer.containsMouse
                        ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.13) : "transparent"
                    border.width: 0
                    border.color: closePointer.containsMouse ? Theme.danger : Theme.line
                    Text { anchors.centerIn: parent; text: "×"; color: closePointer.containsMouse ? Theme.danger : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 15 }
                    MouseArea { id: closePointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ShellState.hideQuickActions() }
                }
            }
        }

        Item {
            anchors.fill: parent
            focus: root.visible
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    ShellState.hideQuickActions();
                    event.accepted = true;
                }
            }
        }
    }

    Component { id: timerComponent; TimerAction { railMode: true } }
    Component { id: telemetryComponent; TelemetryAction { railMode: true } }
}
