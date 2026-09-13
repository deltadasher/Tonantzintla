import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../components"
import "../../services"

// Super+Alt on an open Ephemeris widget lands here: the settings that belong
// to that one widget, with the widget itself left lit and the rest of the
// screen dropped away.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    property bool settled: false
    Component.onCompleted: root.settled = true

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "tonantzintla-widget-popover"

    readonly property string widgetId: ShellState.activeWidgetSettingsId

    readonly property var widgetTitles: ({
        calendar: "Calendar",
        media: "Resonance",
        apps: "Launcher",
        walls: "Parallax",
        clipboard: "Clipboard",
        notifications: "Notifications",
        system: "System stats",
        quickstats: "System stats",
        network: "Network",
        audio: "Audio",
        battery: "Battery",
        focus: "Focus",
        capture: "Optics",
        workspaces: "Workspaces",
        guide: "Manual",
        settings: "Settings"
    })

    // Sits beside the widget when there is room, otherwise over its edge.
    readonly property real cardX: {
        const right = ShellState.activeWidgetGlobalX + ShellState.activeWidgetWidth + 14;
        if (right + card.width + 16 <= root.width)
            return right;
        const left = ShellState.activeWidgetGlobalX - card.width - 14;
        if (left >= 16)
            return left;
        return Math.max(16, Math.min(root.width - card.width - 16,
            ShellState.activeWidgetGlobalX + 16));
    }

    readonly property real cardY: {
        const centred = ShellState.activeWidgetGlobalY
            + (ShellState.activeWidgetHeight - card.height) / 2;
        return Math.max(16, Math.min(root.height - card.height - 16, centred));
    }

    FocusScrim {
        anchors.fill: parent
        focusX: ShellState.activeWidgetGlobalX
        focusY: ShellState.activeWidgetGlobalY
        focusWidth: ShellState.activeWidgetWidth
        focusHeight: ShellState.activeWidgetHeight
        focusRadius: Theme.radiusLarge
        halo: 4
        dim: 0.58
        opacity: root.settled ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Settings.motion ? Theme.motionNormal : 0 }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: ShellState.closeWidgetSettings()
    }

    Item {
        focus: true
        Keys.onEscapePressed: ShellState.closeWidgetSettings()
    }

    // A labelled on/off row, so each control states what it does. Both inline
    // components name their root: `parent` chains from a Repeater delegate do
    // not resolve back to the component itself.
    component ToggleRow: RowLayout {
        id: toggleRow
        property string label: ""
        property bool checked: false
        signal toggled

        Layout.fillWidth: true
        spacing: 10

        Text {
            Layout.fillWidth: true
            text: toggleRow.label
            color: Theme.moon
            font.family: Theme.fontText
            font.pixelSize: 12
            elide: Text.ElideRight
        }
        Rectangle {
            implicitWidth: 42
            implicitHeight: 22
            radius: 11
            color: toggleRow.checked ? Theme.accent : Theme.controlRest
            border.width: 1
            border.color: toggleRow.checked
                ? Theme.accent
                : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.12)
            Rectangle {
                x: toggleRow.checked ? 22 : 2
                y: 2
                width: 18
                height: 18
                radius: 9
                color: toggleRow.checked ? Theme.void_ : Theme.muted
                Behavior on x {
                    NumberAnimation { duration: Settings.motion ? Theme.motionFast : 0 }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggleRow.toggled()
            }
        }
    }

    // A row of mutually exclusive choices.
    component ChoiceRow: RowLayout {
        id: choiceRow
        property string label: ""
        property var options: []
        property string current: ""
        signal picked(string value)

        Layout.fillWidth: true
        spacing: 10

        Text {
            Layout.fillWidth: true
            text: choiceRow.label
            color: Theme.moon
            font.family: Theme.fontText
            font.pixelSize: 12
        }
        Row {
            spacing: 4
            Repeater {
                model: choiceRow.options
                Rectangle {
                    id: option
                    required property var modelData
                    readonly property bool active: modelData.value === choiceRow.current
                    implicitWidth: Math.max(44, optionLabel.implicitWidth + 16)
                    implicitHeight: 24
                    radius: 6
                    color: option.active ? Theme.controlActive : Theme.controlRest
                    border.width: 1
                    border.color: option.active
                        ? Theme.accent
                        : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.1)
                    Text {
                        id: optionLabel
                        anchors.centerIn: parent
                        text: option.modelData.label
                        color: option.active ? Theme.accent : Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: choiceRow.picked(option.modelData.value)
                    }
                }
            }
        }
    }

    Rectangle {
        id: card
        x: root.cardX
        y: root.cardY
        width: 312
        height: body.implicitHeight + 26
        radius: Theme.radiusMedium
        color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.97)
        border.width: 1
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)

        opacity: root.settled ? 1 : 0
        scale: root.settled ? 1 : 0.94
        Behavior on opacity {
            NumberAnimation { duration: Settings.motion ? Theme.motionFast : 0 }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Settings.motion ? Theme.motionNormal : 0
                easing.type: Easing.OutBack
                easing.overshoot: 1.08
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) { mouse.accepted = true; }
        }

        ColumnLayout {
            id: body
            anchors.top: parent.top
            anchors.topMargin: 13
            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.right: parent.right
            anchors.rightMargin: 15
            spacing: 11

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: root.widgetTitles[root.widgetId] || "Widget"
                        color: Theme.moon
                        font.family: Theme.fontDisplay
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                    Text {
                        text: "SETTINGS FOR THIS PANEL"
                        color: Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }
                }
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 6
                    color: closePointer.containsMouse ? Theme.controlDanger : Theme.controlRest
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: closePointer.containsMouse ? Theme.danger : Theme.muted
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        id: closePointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.closeWidgetSettings()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.08)
            }

            // Calendar
            ColumnLayout {
                visible: root.widgetId === "calendar"
                Layout.fillWidth: true
                spacing: 9
                ChoiceRow {
                    label: "Clock"
                    current: Settings.clock12h ? "12" : "24"
                    options: [{ "label": "24H", "value": "24" }, { "label": "12H", "value": "12" }]
                    onPicked: function(value) { Settings.clock12h = (value === "12"); }
                }
                ToggleRow {
                    label: "Show seconds"
                    checked: Settings.showSeconds
                    onToggled: Settings.showSeconds = !Settings.showSeconds
                }
                ToggleRow {
                    label: "Show date in bar"
                    checked: Settings.showDate
                    onToggled: Settings.showDate = !Settings.showDate
                }
                ToggleRow {
                    label: "Weather"
                    checked: Settings.weatherEnabled
                    onToggled: Settings.weatherEnabled = !Settings.weatherEnabled
                }
                ChoiceRow {
                    label: "Temperature"
                    current: Settings.temperatureUnit
                    options: [{ "label": "°C", "value": "celsius" }, { "label": "°F", "value": "fahrenheit" }]
                    onPicked: function(value) { Settings.temperatureUnit = value; }
                }
            }

            // Resonance
            ColumnLayout {
                visible: root.widgetId === "media"
                Layout.fillWidth: true
                spacing: 9
                ToggleRow {
                    label: "Show in bar"
                    checked: Settings.showMedia
                    onToggled: Settings.showMedia = !Settings.showMedia
                }
                ToggleRow {
                    label: "Progress bar"
                    checked: Settings.showMediaProgress
                    onToggled: Settings.showMediaProgress = !Settings.showMediaProgress
                }
                ToggleRow {
                    label: "Elapsed time"
                    checked: Settings.showMediaTime
                    onToggled: Settings.showMediaTime = !Settings.showMediaTime
                }
            }

            // Launcher
            ColumnLayout {
                visible: root.widgetId === "apps"
                Layout.fillWidth: true
                spacing: 9
                ToggleRow {
                    label: "App descriptions"
                    checked: Settings.showAppDescriptions
                    onToggled: Settings.showAppDescriptions = !Settings.showAppDescriptions
                }
                ToggleRow {
                    label: "Launcher button in bar"
                    checked: Settings.showLauncherButton
                    onToggled: Settings.showLauncherButton = !Settings.showLauncherButton
                }
            }

            // Parallax
            ColumnLayout {
                visible: root.widgetId === "walls"
                Layout.fillWidth: true
                spacing: 9
                ChoiceRow {
                    label: "Columns"
                    current: String(Settings.wallpaperColumns)
                    options: [{ "label": "3", "value": "3" }, { "label": "4", "value": "4" }, { "label": "5", "value": "5" }]
                    onPicked: function(value) { Settings.wallpaperColumns = parseInt(value, 10); }
                }
            }

            // Notifications
            ColumnLayout {
                visible: root.widgetId === "notifications"
                Layout.fillWidth: true
                spacing: 9
                ChoiceRow {
                    label: "Position"
                    current: Settings.notificationPosition
                    options: [{ "label": "LEFT", "value": "left" }, { "label": "RIGHT", "value": "right" }]
                    onPicked: function(value) { Settings.notificationPosition = value; }
                }
            }

            // System stats
            ColumnLayout {
                visible: root.widgetId === "system" || root.widgetId === "quickstats"
                Layout.fillWidth: true
                spacing: 9
                ToggleRow {
                    label: "Show stats in bar"
                    checked: Settings.showSystemStats
                    onToggled: Settings.showSystemStats = !Settings.showSystemStats
                }
            }

            // Anything without its own controls yet says so rather than
            // showing an empty card.
            Text {
                visible: ["calendar", "media", "apps", "walls", "notifications",
                    "system", "quickstats"].indexOf(root.widgetId) === -1
                Layout.fillWidth: true
                text: "This panel has no settings of its own yet. Open the settings panel for everything else."
                color: Theme.muted
                font.family: Theme.fontText
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.08)
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 7
                color: allPointer.containsMouse ? Theme.controlActive : Theme.controlRest
                border.width: 1
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
                Text {
                    anchors.centerIn: parent
                    text: "Open all settings"
                    color: Theme.accent
                    font.family: Theme.fontText
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
                MouseArea {
                    id: allPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ShellState.closeWidgetSettings();
                        ShellState.openEphemeris("settings");
                    }
                }
            }
        }
    }
}
