import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../components"
import "../../services"

PanelWindow {
    id: window

    required property var modelData
    screen: modelData
    readonly property string outputName: modelData.name
    readonly property bool docked: Settings.barMode === "docked"
    readonly property bool capsules: Settings.barMode === "capsules"
    readonly property int bodyHeight: Settings.compact ? 36 : Theme.barHeight
    readonly property int shellMargin: docked ? 0 : Settings.barMargin
    property real leftReveal: 0
    property real workspaceReveal: 0
    property real mediaReveal: 0
    property real centerReveal: 0
    property real systemReveal: 0
    property real rightReveal: 0

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: bodyHeight + shellMargin * 2
    color: "transparent"
    exclusionMode: ExclusionMode.Auto

    Rectangle {
        visible: !window.capsules
        x: window.shellMargin
        y: window.shellMargin
        width: window.width - window.shellMargin * 2
        height: window.bodyHeight
        radius: window.docked ? 0 : 14
        color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b,
            Math.min(0.86, Settings.barOpacity * 0.82))
        border.width: 0
    }

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: window.docked ? 10 : window.shellMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: window.capsules ? 4 : 1

        BarIsland {
            reveal: window.leftReveal
            luminous: false

            BarButton {
                glyph: "?"
                accessibleLabel: "Open Tonantzintla manual"
                onActivated: ShellState.toggleEphemeris("guide")
            }

            BarButton {
                visible: Settings.showLauncherButton
                glyph: "⌕"
                accessibleLabel: "Open applications"
                onActivated: ShellState.toggleEphemeris("apps")
            }

            BarButton {
                glyph: "✦"
                accessibleLabel: "Open wallpaper observatory"
                onActivated: ShellState.toggleEphemeris("walls")
            }
        }

        BarIsland {
            visible: Settings.showWorkspaces
            reveal: window.workspaceReveal

            WorkspaceOrbit { output: window.outputName }

            BarButton {
                glyph: "⊞"
                accessibleLabel: "Open Compositor workspace navigator"
                onActivated: ShellState.toggleEphemeris("workspaces")
            }
        }

        BarIsland {
            visible: Settings.showMedia && Media.available && window.width >= 1380
            reveal: window.mediaReveal
            luminous: false

            MediaPill { embedded: true }
        }

        BarIsland {
            visible: Settings.showFocusedWindow && !window.capsules && window.width >= 1840
            reveal: window.mediaReveal

            FocusedSignal {}
        }
    }

    BarIsland {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        reveal: window.centerReveal
        luminous: false

        Rectangle {
            Layout.preferredWidth: 2
            Layout.preferredHeight: 18
            radius: 1
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.70)
        }

        ColumnLayout {
            spacing: -2

            Text {
                text: Qt.formatDateTime(clock.date, Settings.clockFormat)
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: Settings.compact ? 16 : 20
                font.weight: Font.Bold
                font.letterSpacing: 0.8
            }
            Text {
                visible: Settings.showDate
                text: Qt.formatDateTime(clock.date, Settings.dateFormat)
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.letterSpacing: 1.1
            }
            Rectangle {
                visible: !Settings.compact
                Layout.preferredWidth: 92
                Layout.preferredHeight: 1
                color: Theme.barHairlineHover
                Rectangle {
                    width: parent.width * clock.date.getSeconds() / 59
                    height: 1
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                }
            }
        }

        Rectangle {
            visible: Weather.available && window.width >= 1220
            Layout.preferredWidth: 1
            Layout.preferredHeight: 18
            color: Theme.barHairlineHover
        }

        RowLayout {
            visible: Weather.available && window.width >= 1220
            spacing: 5

            Text {
                text: Weather.current.icon || "☾"
                color: Theme.muted
                font.family: Theme.fontIcon
                font.pixelSize: 16
            }
            Text {
                text: Math.round(Number(Weather.current.temp || 0)) + Weather.unitSymbol
                color: Theme.moon
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        TapHandler {
            onTapped: ShellState.toggleEphemeris("calendar")
        }
    }

    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: window.docked ? 10 : window.shellMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: window.capsules ? 4 : 1

        BarIsland {
            visible: (Settings.showSystemStats || Settings.showAudio) && window.width >= 1480
            reveal: window.systemReveal

            SystemReadout {}
        }

        BarIsland {
            reveal: window.systemReveal

            StatusPill {
                visible: Environment.recording
                code: "REC"
                value: "LIVE"
                active: true
                warning: true
                accentColor: Theme.danger
                accessibleLabel: "Screen recording active"
                onActivated: ShellState.toggleEphemeris("capture")
            }

            StatusPill {
                visible: Timekeeper.anyRunning
                code: Timekeeper.activeCode
                value: Timekeeper.activeDisplay
                active: true
                accentColor: Theme.violet
                accessibleLabel: "Chronos array " + value
                onActivated: ShellState.openQuickActions("timer")
            }

            StatusPill {
                visible: Settings.showMicrophone && window.width >= 1180
                code: Audio.inputMuted ? "MIC×" : "MIC"
                value: Audio.inputPercent + "%"
                active: !Audio.inputMuted
                warning: Audio.inputMuted
                accentColor: Theme.rose
                accessibleLabel: "Microphone " + value
                onActivated: ShellState.toggleEphemeris("audio")
            }

            StatusPill {
                visible: Settings.showBrightness && DeviceState.brightnessAvailable
                    && window.width >= 1360
                code: "LUX"
                value: DeviceState.brightnessPercent + "%"
                accentColor: Theme.warning
                accessibleLabel: "Brightness " + value
                onScrolled: function(delta) {
                    DeviceState.changeBrightness(delta > 0 ? 5 : -5);
                }
                onActivated: ShellState.toggleEphemeris("settings")
            }

            StatusPill {
                visible: Settings.showBluetooth && DeviceState.bluetoothAvailable
                    && window.width >= 1260
                code: "BT"
                value: DeviceState.bluetoothLabel
                active: DeviceState.bluetoothEnabled
                accentColor: Theme.violet
                accessibleLabel: "Bluetooth " + value
                onActivated: ShellState.toggleEphemeris("network")
            }

            StatusPill {
                visible: Settings.showBattery && DeviceState.batteryAvailable
                code: DeviceState.batteryCharging ? "PWR" : "BAT"
                value: DeviceState.batteryPercent + "%"
                active: !DeviceState.batteryLow
                warning: DeviceState.batteryLow
                accentColor: DeviceState.batteryCharging ? Theme.success : Theme.cyan
                accessibleLabel: "Battery " + value
                onActivated: ShellState.toggleEphemeris("battery")
            }

            NetworkPill { visible: window.width >= 1080 }
        }

        BarIsland {
            reveal: window.rightReveal
            luminous: false

            TrayStrip { visible: Settings.showTray }

            NotificationIndicator {
                onActivated: ShellState.toggleEphemeris("notifications")
            }

            BarButton {
                visible: Settings.quickActionsEnabled
                glyph: "◈"
                accessibleLabel: "Open quick actions rail"
                onActivated: ShellState.toggleQuickActions(ShellState.quickActionTab)
            }

            BarButton {
                glyph: "⋯"
                accessibleLabel: "Open field tools"
                onActivated: ShellState.toggleEphemeris("tools")
            }

            BarButton {
                visible: Settings.showSettingsButton
                glyph: "⚙"
                accessibleLabel: "Open settings"
                onActivated: ShellState.toggleEphemeris("settings")
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Component.onCompleted: startupDelay.restart()

    Timer {
        id: startupDelay
        interval: 40
        onTriggered: startupSequence.restart()
    }

    SequentialAnimation {
        id: startupSequence
        NumberAnimation { target: window; property: "leftReveal"; to: 1; duration: Settings.motion ? 180 : 0; easing.type: Easing.OutBack }
        NumberAnimation { target: window; property: "workspaceReveal"; to: 1; duration: Settings.motion ? 150 : 0; easing.type: Easing.OutBack }
        NumberAnimation { target: window; property: "mediaReveal"; to: 1; duration: Settings.motion ? 180 : 0; easing.type: Easing.OutBack }
        NumberAnimation { target: window; property: "centerReveal"; to: 1; duration: Settings.motion ? 170 : 0; easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: window; property: "systemReveal"; to: 1; duration: Settings.motion ? 210 : 0; easing.type: Easing.OutBack }
            NumberAnimation { target: window; property: "rightReveal"; to: 1; duration: Settings.motion ? 260 : 0; easing.type: Easing.OutBack }
        }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: Settings.motion ? Theme.motionNormal : 0; easing.type: Easing.OutCubic }
    }
}
