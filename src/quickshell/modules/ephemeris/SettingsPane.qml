import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services"

pragma ComponentBehavior: Bound

Item {
    id: root

    property real sectionReveal: 1
    property int selectedExtension: -1

    function extensionAlwaysOn(id) {
        return id === "parallax" || id === "transit" || id === "clipboard" || id === "optics";
    }

    // Uniform toggle sections are driven by data rows: {key, label, detail}
    // plus an optional enabledKey gating the row on another setting.
    component ToggleGrid: GridLayout {
        id: toggleGrid
        property var rows: []
        columns: 2
        columnSpacing: 10
        rowSpacing: 10

        Repeater {
            model: toggleGrid.rows
            SettingToggle {
                required property var modelData
                Layout.fillWidth: true
                enabled: !modelData.enabledKey || Settings[modelData.enabledKey] === true
                label: modelData.label
                detail: modelData.detail
                checked: Settings[modelData.key] === true
                onToggled: Settings[modelData.key] = !Settings[modelData.key]
            }
        }
    }

    Connections {
        target: ShellState
        function onSettingsSectionChanged() {
            root.sectionReveal = 0;
            sectionDelay.restart();
        }
    }

    Timer {
        id: sectionDelay
        interval: 24
        onTriggered: sectionIntro.restart()
    }

    NumberAnimation {
        id: sectionIntro
        target: root
        property: "sectionReveal"
        to: 1
        duration: Settings.motion ? 240 : 0
        easing.type: Easing.OutCubic
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "SETTINGS"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 22
                font.weight: Font.Black
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Environment.version
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.letterSpacing: 1
            }
        }

        LiveBarPreview {
            Layout.fillWidth: true
            Layout.preferredHeight: 92
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 18

            Rectangle {
                Layout.preferredWidth: 168
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: Theme.controlRest
                border.width: 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    Repeater {
                        model: [
                            { "key": "appearance", "label": "Appearance" },
                            { "key": "bar", "label": "Bar" },
                            { "key": "launcher", "label": "Panels" },
                            { "key": "umbra", "label": "Lock screen" },
                            { "key": "system", "label": "System" },
                            { "key": "extensions", "label": "Extensions" }
                        ]

                        Rectangle {
                            id: sectionButton
                            required property var modelData
                            readonly property bool active: ShellState.settingsSection === modelData.key
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: 12
                            color: active ? Theme.accent
                                : sectionPointer.containsMouse ? Theme.controlHover : "transparent"
                            border.width: 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: 6
                                    Layout.preferredHeight: sectionButton.active ? 16 : 6
                                    radius: 3
                                    color: sectionButton.active ? Theme.void_ : Theme.lineBright
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: sectionButton.modelData.label
                                    color: sectionButton.active ? Theme.void_ : Theme.moon
                                    font.family: Theme.fontText
                                    font.pixelSize: 13
                                    font.weight: sectionButton.active ? Font.DemiBold : Font.Normal
                                }
                            }

                            MouseArea {
                                id: sectionPointer
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ShellState.settingsSection = sectionButton.modelData.key;
                                    settingsFlick.contentY = 0;
                                }
                            }
                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            Flickable {
                id: settingsFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: pageLoader.height

                Loader {
                    id: pageLoader
                    readonly property Item loadedPage: item as Item
                    width: settingsFlick.width
                    height: loadedPage ? loadedPage.implicitHeight : 0
                    opacity: root.sectionReveal
                    transform: Translate { y: (1 - root.sectionReveal) * 16 }
                    sourceComponent: ShellState.settingsSection === "appearance" ? appearancePage
                        : ShellState.settingsSection === "bar" ? barPage
                        : ShellState.settingsSection === "launcher" ? launcherPage
                        : ShellState.settingsSection === "umbra" ? umbraPage
                        : ShellState.settingsSection === "extensions" ? extensionsPage
                        : systemPage
                }
            }
        }
    }

    Component {
        id: appearancePage
        ColumnLayout {
            width: pageLoader.width
            spacing: 10

            Text {
                text: "COLOR"
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.letterSpacing: 1.1
            }

            Row {
                Layout.fillWidth: true
                spacing: 18
                height: 64

                Repeater {
                    model: ["violet", "cyan", "rose", "amber"]
                    Item {
                        id: accentChoice
                        required property string modelData
                        readonly property bool chosen: Theme.accentName === modelData
                        width: chosen ? 86 : 52
                        height: 64

                        Rectangle {
                            anchors.centerIn: parent
                            width: accentChoice.chosen ? 64 : accentPointer.containsMouse ? 44 : 36
                            height: width * 0.78
                            radius: height / 2
                            color: Theme.accents[accentChoice.modelData]
                            opacity: accentChoice.chosen ? 1 : 0.55
                            rotation: accentChoice.chosen ? -8 : 6
                            Behavior on width {
                                NumberAnimation {
                                    duration: Settings.motion ? Theme.motionNormal : 0
                                    easing.type: Easing.OutBack
                                }
                            }
                            Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: accentChoice.chosen ? accentChoice.modelData.toUpperCase() : ""
                            color: Theme.moon
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: accentPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Settings.accentName = accentChoice.modelData
                        }
                    }
                }
            }

            SettingToggle {
                Layout.fillWidth: true
                label: "Wallpaper colors"
                detail: "Pick theme colors from your wallpaper using Matugen"
                checked: Settings.adaptivePalette
                onToggled: Settings.adaptivePalette = !Settings.adaptivePalette
            }

            Text {
                text: "TYPE"
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.letterSpacing: 1.1
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Font preset"
                detail: "Monospace-first, a softer reading mix, or system fonts"
                value: Settings.typographyProfile
                choices: [
                    { "label": "SERP", "value": "serpantinum" },
                    { "label": "READABLE", "value": "readable" },
                    { "label": "SYSTEM", "value": "system" }
                ]
                onSelected: function(value) { Settings.applyTypographyPreset(value); }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 10

                SettingTextField {
                    Layout.fillWidth: true
                    label: "Display font"
                    detail: "Headings, clock, and large readouts"
                    value: Settings.fontDisplay
                    status: FontState.displayStatus
                    statusOk: FontState.displayOk
                    onCommitted: function(value) {
                        Settings.typographyProfile = "custom";
                        Settings.fontDisplay = value.length ? value : "JetBrains Mono";
                    }
                }
                SettingTextField {
                    Layout.fillWidth: true
                    label: "Interface font"
                    detail: "Labels and longer text"
                    value: Settings.fontText
                    status: FontState.textStatus
                    statusOk: FontState.textOk
                    onCommitted: function(value) {
                        Settings.typographyProfile = "custom";
                        Settings.fontText = value.length ? value : "JetBrains Mono";
                    }
                }
                SettingTextField {
                    Layout.fillWidth: true
                    label: "Monospace font"
                    detail: "Numbers, codes, and small labels"
                    value: Settings.fontMono
                    status: FontState.monoStatus
                    statusOk: FontState.monoOk
                    onCommitted: function(value) {
                        Settings.typographyProfile = "custom";
                        Settings.fontMono = value.length ? value : "JetBrains Mono";
                    }
                }
                SettingTextField {
                    Layout.fillWidth: true
                    label: "Icon font"
                    detail: "Nerd Font icons used by the shell"
                    value: Settings.fontIcon
                    status: FontState.iconStatus
                    statusOk: FontState.iconOk
                    onCommitted: function(value) {
                        Settings.typographyProfile = "custom";
                        Settings.fontIcon = value.length ? value : "Iosevka Nerd Font";
                    }
                }
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Panel animation"
                detail: "How panels appear when opened"
                value: Settings.motionStyle
                choices: [
                    { "label": "RISE", "value": "rise" },
                    { "label": "ZOOM", "value": "zoom" }
                ]
                onSelected: function(value) { Settings.motionStyle = value; }
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Background detail"
                detail: "Amount of background detail in panels"
                value: Settings.atmosphereStyle
                choices: [
                    { "label": "QUIET", "value": "quiet" },
                    { "label": "NOMINAL", "value": "nominal" },
                    { "label": "CINEMATIC", "value": "cinematic" }
                ]
                onSelected: function(value) { Settings.atmosphereStyle = value; }
            }

            ToggleGrid {
                Layout.fillWidth: true
                rows: [
                    { "key": "motion", "label": "Animations", "detail": "Enable transitions and animations" },
                    { "key": "animateStars", "label": "Animated stars", "detail": "Animate stars behind panels" },
                    { "key": "compact", "label": "Compact mode", "detail": "Make the bar shorter" }
                ]
            }
            Item { Layout.preferredHeight: 8 }
        }
    }

    Component {
        id: barPage
        ColumnLayout {
            width: pageLoader.width
            spacing: 10

            Text {
                text: "BAR ITEMS"
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.letterSpacing: 1.1
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Bar style"
                detail: "Docked, floating, or separate capsules"
                value: Settings.barMode
                choices: [
                    { "label": "DOCKED", "value": "docked" },
                    { "label": "FLOATING", "value": "floating" },
                    { "label": "CAPSULES", "value": "capsules" }
                ]
                onSelected: function(value) { Settings.barMode = value; }
            }

            SettingChoice {
                Layout.fillWidth: true
                visible: Settings.barMode !== "docked"
                label: "Edge spacing"
                detail: "Space between the bar and the screen edge"
                value: Settings.barMargin
                choices: [
                    { "label": "TIGHT", "value": 8 },
                    { "label": "NOMINAL", "value": 12 },
                    { "label": "WIDE", "value": 18 }
                ]
                onSelected: function(value) { Settings.barMargin = value; }
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Glass density"
                detail: "How see-through the bar is"
                value: Settings.barOpacity
                choices: [
                    { "label": "LIGHT", "value": 0.82 },
                    { "label": "GLASS", "value": 0.94 },
                    { "label": "SOLID", "value": 1.0 }
                ]
                onSelected: function(value) { Settings.barOpacity = value; }
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Widget preset"
                detail: "Apply a quick visibility preset, then tune individual channels"
                value: ""
                choices: [
                    { "label": "MINIMAL", "value": "minimal" },
                    { "label": "BALANCED", "value": "balanced" },
                    { "label": "FULL", "value": "telemetry" }
                ]
                onSelected: function(value) { Settings.applyBarPreset(value); }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 10

                SettingToggle {
                    Layout.fillWidth: true
                    label: "Quick actions"
                    detail: "Timers and system stats on demand"
                    checked: Settings.quickActionsEnabled
                    onToggled: {
                        Settings.quickActionsEnabled = !Settings.quickActionsEnabled;
                        if (!Settings.quickActionsEnabled)
                            ShellState.hideQuickActions();
                    }
                }
                SettingChoice {
                    Layout.fillWidth: true
                    enabled: Settings.quickActionsEnabled
                    label: "Quick actions side"
                    detail: "Which screen edge quick actions sit on"
                    value: Settings.quickActionsEdge
                    choices: [
                        { "label": "LEFT", "value": "left" },
                        { "label": "RIGHT", "value": "right" }
                    ]
                    onSelected: function(value) { Settings.quickActionsEdge = value; }
                }
            }

            ToggleGrid {
                Layout.fillWidth: true
                rows: [
                    { "key": "showLauncherButton", "label": "Launcher control", "detail": "Show the app launcher button" },
                    { "key": "showSettingsButton", "label": "Settings control", "detail": "Show the settings button" },
                    { "key": "showWorkspaces", "label": "Workspaces", "detail": "Show Compositor workspaces on this screen" },
                    { "key": "showFocusedWindow", "label": "Focused window", "detail": "Show the active app and window title" },
                    { "key": "showMedia", "label": "Media", "detail": "Album art, title, and playback controls" },
                    { "key": "showTray", "label": "System tray", "detail": "Show tray icons from apps" },
                    { "key": "showMediaProgress", "label": "Playback progress", "detail": "Show the playback progress bar" },
                    { "key": "showMediaTime", "label": "Playback time", "detail": "Show elapsed and total time" },
                    { "key": "showSystemStats", "label": "System stats", "detail": "CPU and memory readings" },
                    { "key": "showAudio", "label": "Volume", "detail": "Volume, click or scroll to change" },
                    { "key": "showNetworkLabel", "label": "Network label", "detail": "Show active connection name" },
                    { "key": "showBluetooth", "label": "Bluetooth", "detail": "Bluetooth state and connected devices" },
                    { "key": "showBrightness", "label": "Brightness", "detail": "Screen brightness, scroll to change" },
                    { "key": "showBattery", "label": "Battery", "detail": "Charge level and low-battery warning" },
                    { "key": "showMicrophone", "label": "Microphone", "detail": "Mic level and mute button" },
                    { "key": "showSeconds", "label": "Show seconds", "detail": "Show seconds on the clock" },
                    { "key": "showDate", "label": "Date", "detail": "Show the date under the clock" }
                ]
            }
            Item { Layout.preferredHeight: 8 }
        }
    }

    Component {
        id: launcherPage
        ColumnLayout {
            width: pageLoader.width
            spacing: 10

            Text {
                text: "CATALOG"
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.letterSpacing: 1.1
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Max search results"
                detail: "Most apps to show in results"
                value: Settings.launcherMaxResults
                choices: [
                    { "label": "40", "value": 40 },
                    { "label": "80", "value": 80 },
                    { "label": "120", "value": 120 }
                ]
                onSelected: function(value) { Settings.launcherMaxResults = value; }
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Wallpaper columns"
                detail: "How many wallpaper columns to show"
                value: Settings.wallpaperColumns
                choices: [
                    { "label": "2", "value": 2 },
                    { "label": "3", "value": 3 },
                    { "label": "4", "value": 4 }
                ]
                onSelected: function(value) { Settings.wallpaperColumns = value; }
            }

            ToggleGrid {
                Layout.fillWidth: true
                rows: [
                    { "key": "showAppDescriptions", "label": "App descriptions", "detail": "Show descriptions below application names" }
                ]
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                radius: Theme.radiusMedium
                color: Theme.accentVeil
                border.width: 0
                border.color: Theme.accentLine
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 4
                    Text {
                        text: "INDEX"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        font.letterSpacing: 1
                    }
                    Text {
                        text: "Apps are indexed live. Both exact and fuzzy search work."
                        color: Theme.moon
                        font.family: Theme.fontText
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
            Item { Layout.preferredHeight: 8 }
        }
    }

    Component {
        id: umbraPage
        ColumnLayout {
            width: pageLoader.width
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "LOCK SCREEN"
                        color: Theme.moon
                        font.family: Theme.fontDisplay
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: "SCREEN LOCK  //  PASSWORD REQUIRED"
                        color: Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        font.letterSpacing: 1
                    }
                }
                Rectangle {
                    Layout.preferredWidth: umbraStatus.implicitWidth + 22
                    Layout.preferredHeight: 32
                    radius: height / 2
                    color: Theme.accentVeil
                    border.width: 0
                    border.color: Theme.accentLine
                    Text {
                        id: umbraStatus
                        anchors.centerIn: parent
                        text: Umbra.stateCode
                        color: Umbra.failed ? Theme.danger : Theme.success
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.letterSpacing: 0.9
                    }
                }
            }

            ToggleGrid {
                Layout.fillWidth: true
                rows: [
                    { "key": "umbraMotion", "label": "Animations", "detail": "Animate the background and login effects" },
                    { "key": "umbraUseWallpaper", "label": "Active wallpaper", "detail": "Use your current wallpaper behind the lock screen" },
                    { "key": "umbraBlurWallpaper", "enabledKey": "umbraUseWallpaper", "label": "Blur wallpaper", "detail": "Blur and dim the wallpaper behind the lock screen" },
                    { "key": "umbraShowMedia", "label": "Music controls", "detail": "Show album art and playback controls" },
                    { "key": "umbraShowWeather", "label": "Weather", "detail": "Show the temperature next to the clock" }
                ]
            }

            SettingTextField {
                Layout.fillWidth: true
                label: "PAM service"
                detail: "PAM profile in /etc/pam.d; login is the safe default"
                value: Settings.umbraPamService
                status: Umbra.pamAvailable ? "AVAILABLE" : "CHECK PROFILE"
                statusOk: Umbra.pamAvailable
                onCommitted: function(value) {
                    if (value.trim().length > 0)
                        Settings.umbraPamService = value.trim();
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 82
                radius: Theme.radiusMedium
                color: Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.07)
                border.width: 0
                border.color: Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.28)
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            text: "PREVIEW"
                            color: Theme.cyan
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "See the full lock screen without actually locking. Press Escape to return."
                            color: Theme.moon
                            font.family: Theme.fontText
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 136
                        Layout.preferredHeight: 40
                        radius: Theme.radiusSmall
                        color: previewPointer.containsMouse ? Theme.accent : Theme.accentVeil
                        border.width: 0
                        border.color: Theme.accentLine
                        Text {
                            anchors.centerIn: parent
                            text: "PREVIEW LOCK SCREEN"
                            color: previewPointer.containsMouse ? Theme.void_ : Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                        MouseArea {
                            id: previewPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ShellState.closeEphemeris();
                                Umbra.preview();
                            }
                        }
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: Theme.radiusMedium
                color: Theme.mantle
                border.width: 0
                border.color: Theme.line
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    Text {
                        Layout.fillWidth: true
                        text: "SECURE SESSION"
                        color: Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        font.letterSpacing: 0.8
                    }
                    Rectangle {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 36
                        radius: Theme.radiusSmall
                        color: lockPointer.containsMouse ? Theme.rose : Theme.elevated
                        border.width: 0
                        border.color: Qt.rgba(Theme.rose.r, Theme.rose.g, Theme.rose.b, 0.42)
                        Text {
                            anchors.centerIn: parent
                            text: "LOCK SESSION"
                            color: lockPointer.containsMouse ? Theme.void_ : Theme.rose
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                        MouseArea {
                            id: lockPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ShellState.closeEphemeris();
                                Umbra.launchLock();
                            }
                        }
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    }
                }
            }
            Item { Layout.preferredHeight: 8 }
        }
    }

    Component {
        id: systemPage
        ColumnLayout {
            width: pageLoader.width
            spacing: 10

            Text {
                text: "APPS"
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.letterSpacing: 1.1
            }

            SettingTextField {
                Layout.fillWidth: true
                label: "Terminal"
                detail: "Leave blank to use the system terminal"
                value: Settings.terminal
                onCommitted: function(value) { Settings.terminal = value.trim(); }
            }
            SettingTextField {
                Layout.fillWidth: true
                label: "Browser"
                detail: "Leave blank to use the system browser"
                value: Settings.browser
                onCommitted: function(value) { Settings.browser = value.trim(); }
            }
            SettingTextField {
                Layout.fillWidth: true
                label: "File manager"
                detail: "Leave blank to use the system file manager"
                value: Settings.fileManager
                onCommitted: function(value) { Settings.fileManager = value.trim(); }
            }

            Text {
                text: "WEATHER"
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.letterSpacing: 1.1
                Layout.topMargin: 4
            }

            SettingToggle {
                Layout.fillWidth: true
                label: "Weather forecast"
                detail: "Current, hourly, and five-day forecast in the calendar"
                checked: Settings.weatherEnabled
                onToggled: Settings.weatherEnabled = !Settings.weatherEnabled
            }

            SettingTextField {
                Layout.fillWidth: true
                enabled: Settings.weatherEnabled
                label: "Forecast location"
                detail: "Set once; Tonantzintla never guesses your location"
                value: Settings.weatherLocation
                onCommitted: function(value) {
                    Settings.weatherLocation = value.trim();
                }
            }

            SettingChoice {
                Layout.fillWidth: true
                enabled: Settings.weatherEnabled
                label: "Temperature scale"
                detail: "Units used for weather"
                value: Settings.temperatureUnit
                choices: [
                    { "label": "CELSIUS", "value": "celsius" },
                    { "label": "FAHRENHEIT", "value": "fahrenheit" }
                ]
                onSelected: function(value) { Settings.temperatureUnit = value; }
            }

            Text {
                text: "STATUS"
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.letterSpacing: 1.1
                Layout.topMargin: 4
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 10

                Repeater {
                    model: [
                        { "code": "NIR", "label": "Compositor IPC", "value": Compositor.available ? "ONLINE" : "OFFLINE", "ok": Compositor.available },
                        { "code": "OPT", "label": "Clipboard snipping", "value": Environment.canCaptureRegion ? "ONLINE" : "MISSING", "ok": Environment.canCaptureRegion },
                        { "code": "WAL", "label": "Wallpaper backend", "value": Environment.wallpaperStatus, "ok": Environment.canSetWallpaper },
                        { "code": "MPR", "label": "MPRIS players", "value": Media.available ? "ONLINE" : "IDLE", "ok": Media.available },
                        { "code": "NET", "label": "Network link", "value": NetState.connected ? NetState.label : "OFFLINE", "ok": NetState.connected },
                        { "code": "SKY", "label": "Weather forecast", "value": Weather.status, "ok": Weather.available },
                        { "code": "AUD", "label": "PipeWire volume", "value": Audio.percent + "%", "ok": true }
                    ]

                    Rectangle {
                        id: diagnostic
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        radius: Theme.radiusMedium
                        color: Theme.mantle
                        border.width: 0
                        border.color: Theme.line

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 13
                            anchors.rightMargin: 13
                            spacing: 10
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 8
                                color: diagnostic.modelData.ok ? Theme.accentVeil : Theme.elevated
                                Text {
                                    anchors.centerIn: parent
                                    text: diagnostic.modelData.code
                                    color: diagnostic.modelData.ok ? Theme.accent : Theme.warning
                                    font.family: Theme.fontMono
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: diagnostic.modelData.label
                                color: Theme.moon
                                font.family: Theme.fontText
                                font.pixelSize: 11
                            }
                            Text {
                                text: diagnostic.modelData.value
                                color: diagnostic.modelData.ok ? Theme.success : Theme.warning
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.maximumWidth: 120
                            }
                        }
                    }
                }
            }
            Item { Layout.preferredHeight: 8 }
        }
    }

    Component {
        id: extensionsPage
        ColumnLayout {
            width: pageLoader.width
            spacing: 16

            Text {
                text: "On the bar"
                color: Theme.muted
                font.family: Theme.fontText
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: PluginRegistry.entries.filter(function(entry) {
                        return !root.extensionAlwaysOn(entry.id);
                    })

                    Rectangle {
                        id: toggleRow
                        required property var modelData
                        required property int index
                        readonly property bool chosen: root.selectedExtension === index
                        Layout.fillWidth: true
                        Layout.preferredHeight: chosen ? 72 : 48
                        radius: 12
                        color: chosen || shelfPointer.containsMouse ? Theme.controlHover : Theme.controlRest
                        border.width: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 14
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 16
                                radius: 8
                                color: toggleRow.modelData.enabled ? Theme.accent : Theme.elevated
                                border.width: 0

                                Rectangle {
                                    y: 2
                                    x: toggleRow.modelData.enabled ? 14 : 2
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: toggleRow.modelData.enabled ? Theme.void_ : Theme.muted
                                    Behavior on x {
                                        NumberAnimation {
                                            duration: Settings.motion ? Theme.motionNormal : 0
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: toggleRow.modelData.name
                                    color: Theme.moon
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    visible: toggleRow.chosen || shelfPointer.containsMouse
                                    Layout.fillWidth: true
                                    text: toggleRow.modelData.detail
                                    color: Theme.muted
                                    font.family: Theme.fontText
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Text {
                                text: toggleRow.modelData.available ? toggleRow.modelData.status : "OFFLINE"
                                color: toggleRow.modelData.available ? Theme.success : Theme.warning
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                            }
                        }

                        MouseArea {
                            id: shelfPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedExtension = toggleRow.index;
                                PluginRegistry.toggle(toggleRow.modelData.id);
                            }
                        }

                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: Settings.motion ? Theme.motionFast : 0
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            Text {
                text: "Always on"
                color: Theme.muted
                font.family: Theme.fontText
                font.pixelSize: 12
                font.weight: Font.DemiBold
                Layout.topMargin: 4
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: PluginRegistry.entries.filter(function(entry) {
                        return root.extensionAlwaysOn(entry.id);
                    })

                    Rectangle {
                        id: alwaysOnRow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 12
                        color: aboardPointer.containsMouse ? Theme.controlHover : Theme.controlRest
                        border.width: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 14
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 4
                                color: alwaysOnRow.modelData.available ? Theme.success : Theme.warning
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: alwaysOnRow.modelData.name
                                    color: Theme.moon
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    visible: aboardPointer.containsMouse
                                    Layout.fillWidth: true
                                    text: alwaysOnRow.modelData.detail
                                    color: Theme.muted
                                    font.family: Theme.fontText
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                text: alwaysOnRow.modelData.available ? alwaysOnRow.modelData.status : "OFFLINE"
                                color: alwaysOnRow.modelData.available ? Theme.success : Theme.warning
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                            }
                        }

                        MouseArea {
                            id: aboardPointer
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    }
                }
            }
            Item { Layout.preferredHeight: 8 }
        }
    }
}
