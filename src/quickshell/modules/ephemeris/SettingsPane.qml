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
        property var toggleRows: []
        columns: 2
        columnSpacing: 10
        rowSpacing: 10

        Repeater {
            model: toggleGrid.toggleRows
            SettingToggle {
                required property var modelData
                Layout.fillWidth: true
                enabled: !modelData.enabledKey || Settings[modelData.enabledKey] === true
                label: modelData.label
                detail: modelData.detail || ""
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
                            { "key": "bar-editor", "label": "Bar editor" },
                            { "key": "launcher", "label": "Panels" },
                            { "key": "umbra", "label": "Lock screen" },
                            { "key": "system", "label": "System" },
                            { "key": "niri", "label": "Niri settings" },
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
                                    if (sectionButton.modelData.key === "bar-editor") {
                                        ShellState.closeEphemeris();
                                        ShellState.enterBarEditMode();
                                    } else {
                                        ShellState.settingsSection = sectionButton.modelData.key;
                                    }
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
                        : ShellState.settingsSection === "launcher" ? launcherPage
                        : ShellState.settingsSection === "umbra" ? umbraPage
                        : ShellState.settingsSection === "extensions" ? extensionsPage
                        : ShellState.settingsSection === "niri" ? niriPage
                        : systemPage
                }
            }
        }
    }

    Component {
        id: niriPage
        ColumnLayout {
            width: pageLoader.width
            spacing: 28
            CursorSettings { Layout.fillWidth: true }
            OutputSettings { Layout.fillWidth: true }
        }
    }

    Component {
        id: appearancePage
        ColumnLayout {
            width: pageLoader.width
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { name: "serpantinum", label: "Serpantinum", accent: "#a78bfa", desc: "Capsules & Fluid" },
                        { name: "caelestia", label: "Caelestia", accent: "#38bdf8", desc: "Docked & Spotlight" },
                        { name: "solaris", label: "Solaris", accent: "#fbbf24", desc: "Gold & Crisp" },
                        { name: "cyberpunk", label: "Cyberpunk", accent: "#f43f5e", desc: "Left Bar & Vivid" },
                        { name: "minimalist", label: "Minimalist", accent: "#94a3b8", desc: "Docked Bottom" }
                    ]

                    Rectangle {
                        id: presetCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 10
                        color: presetPointer.containsMouse ? Theme.barNeutralHover : Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.6)
                        border.width: 1
                        border.color: presetPointer.containsMouse ? Theme.accent : Theme.barHairline

                        Rectangle {
                            width: 3
                            height: 16
                            radius: 1.5
                            color: presetCard.modelData.accent
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        ColumnLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            spacing: 1

                            Text {
                                text: presetCard.modelData.label
                                color: Theme.moon
                                font.family: Theme.fontDisplay
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            Text {
                                text: presetCard.modelData.desc
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: presetPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Settings.applyDesktopPreset(presetCard.modelData.name)
                        }
                    }
                }
            }

            Row {
                Layout.fillWidth: true
                spacing: 18
                Layout.preferredHeight: 64

                Repeater {
                    model: ["violet", "cyan", "rose", "amber", "emerald", "solar", "silver"]
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
                checked: Settings.adaptivePalette
                onToggled: Settings.adaptivePalette = !Settings.adaptivePalette
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Font preset"
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
                value: Settings.motionStyle
                choices: [
                    { "label": "RISE", "value": "rise" },
                    { "label": "ZOOM", "value": "zoom" }
                ]
                onSelected: function(value) { Settings.motionStyle = value; }
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Animation speed"
                value: Settings.motionSpeedProfile
                choices: [
                    { "label": "INSTANT", "value": "instant" },
                    { "label": "SNAPPY", "value": "snappy" },
                    { "label": "FLUID", "value": "fluid" },
                    { "label": "CINEMATIC", "value": "cinematic" }
                ]
                onSelected: function(value) { Settings.motionSpeedProfile = value; }
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Background detail"
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
                toggleRows: [
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

            // Bar Studio Launcher Card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 64
                radius: 14
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, studioBtnHover.containsMouse ? 0.20 : 0.10)
                border.width: 1.5
                border.color: Theme.accent

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "✦"
                        color: Theme.accent
                        font.pixelSize: 22
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Arrange the bar"
                            color: Theme.moon
                            font.family: Theme.fontDisplay
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Text {
                            text: "Move widgets, add or remove them, and set what shows on each display"
                            color: Theme.muted
                            font.family: Theme.fontText
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        implicitWidth: openStudioText.implicitWidth + 24
                        implicitHeight: 34
                        radius: 10
                        color: Theme.accent
                        border.width: 0

                        Text {
                            id: openStudioText
                            anchors.centerIn: parent
                            text: "Edit Mode ✦"
                            color: Theme.void_
                            font.family: Theme.fontText
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                }

                MouseArea {
                    id: studioBtnHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ShellState.closeEphemeris();
                        ShellState.enterBarEditMode();
                    }
                }
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Bar position"
                value: Settings.barPosition
                choices: [
                    { "label": "TOP", "value": "top" },
                    { "label": "BOTTOM", "value": "bottom" },
                    { "label": "LEFT", "value": "left" },
                    { "label": "RIGHT", "value": "right" }
                ]
                onSelected: function(value) { Settings.barPosition = value; }
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Bar size"
                value: Settings.barHeightProfile
                choices: [
                    { "label": "COMPACT", "value": "compact" },
                    { "label": "NOMINAL", "value": "nominal" },
                    { "label": "TALL", "value": "tall" }
                ]
                onSelected: function(value) { Settings.barHeightProfile = value; }
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Bar style"
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
                label: "Time notation"
                value: Settings.clock12h ? "12h" : "24h"
                choices: [
                    { "label": "24-HOUR", "value": "24h" },
                    { "label": "12-HOUR", "value": "12h" }
                ]
                onSelected: function(value) { Settings.clock12h = value === "12h"; }
            }

            SettingChoice {
                Layout.fillWidth: true
                visible: Settings.barMode !== "docked"
                label: "Edge spacing"
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
                value: ""
                choices: [
                    { "label": "MINIMAL", "value": "minimal" },
                    { "label": "BALANCED", "value": "balanced" },
                    { "label": "FULL", "value": "telemetry" }
                ]
                onSelected: function(value) { Settings.applyBarPreset(value); }
            }

            ToggleGrid {
                Layout.fillWidth: true
                toggleRows: [
                    { "key": "showLauncherButton", "label": "Launcher control" },
                    { "key": "barIconMotion", "label": "Icon opening animations", "detail": "A short response when a bar panel opens" },
                    { "key": "showSettingsButton", "label": "Settings control" },
                    { "key": "showWorkspaces", "label": "Workspaces" },
                    { "key": "showFocusedWindow", "label": "Focused window" },
                    { "key": "showMedia", "label": "Media" },
                    { "key": "showTray", "label": "System tray" },
                    { "key": "showMediaProgress", "label": "Playback progress" },
                    { "key": "showMediaTime", "label": "Playback time" },
                    { "key": "showSystemStats", "label": "System stats" },
                    { "key": "showAudio", "label": "Volume" },
                    { "key": "showNetworkLabel", "label": "Network label" },
                    { "key": "showBluetooth", "label": "Bluetooth" },
                    { "key": "showBrightness", "label": "Brightness" },
                    { "key": "showBattery", "label": "Battery" },
                    { "key": "showBatteryPercent", "label": "Battery percentage" },
                    { "key": "showMicrophone", "label": "Microphone" },
                    { "key": "showSeconds", "label": "Show seconds" },
                    { "key": "showDate", "label": "Date" }
                ]
            }

            IslandArrangementEditor {
                Layout.fillWidth: true
            }

            Item { Layout.preferredHeight: 8 }
        }
    }

    Component {
        id: launcherPage
        ColumnLayout {
            width: pageLoader.width
            spacing: 10

            SettingChoice {
                Layout.fillWidth: true
                label: "Default panel"
                value: Settings.defaultLaunchTab
                choices: [
                    { "label": "APPLICATIONS", "value": "apps" },
                    { "label": "OBSERVATORY", "value": "system" },
                    { "label": "RESONANCE", "value": "media" },
                    { "label": "WALLPAPERS", "value": "walls" },
                    { "label": "CALENDAR", "value": "calendar" }
                ]
                onSelected: function(value) { Settings.defaultLaunchTab = value; }
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Ephemeris presentation"
                value: Settings.ephemerisStyle
                choices: [
                    { "label": "SPOTLIGHT", "value": "spotlight" },
                    { "label": "DECK", "value": "deck" },
                    { "label": "COMPACT", "value": "compact" }
                ]
                onSelected: function(value) { Settings.ephemerisStyle = value; }
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Feedback duration"
                value: Settings.osdDuration
                choices: [
                    { "label": "1s", "value": 1000 },
                    { "label": "DEFAULT", "value": 1450 },
                    { "label": "1.5s", "value": 1500 },
                    { "label": "2.5s", "value": 2500 }
                ]
                onSelected: function(value) { Settings.osdDuration = value; }
            }
            ToggleGrid {
                Layout.fillWidth: true
                toggleRows: [
                    { "key": "osdVolume", "label": "Volume feedback" },
                    { "key": "osdMicrophone", "label": "Microphone feedback" },
                    { "key": "osdBrightness", "label": "Brightness feedback" }
                ]
            }
            SettingChoice {
                Layout.fillWidth: true
                label: "Max search results"
                value: Settings.launcherMaxResults
                choices: [
                    { "label": "40", "value": 40 },
                    { "label": "80", "value": 80 },
                    { "label": "120", "value": 120 }
                ]
                onSelected: function(value) { Settings.launcherMaxResults = value; }
            }

            ToggleGrid {
                Layout.fillWidth: true
                toggleRows: [
                    { "key": "enableCalculator", "label": "Inline calculator & math" },
                    { "key": "showAppDescriptions", "label": "App descriptions" },
                    { "key": "showTabApps", "label": "Apps panel" },
                    { "key": "showTabMedia", "label": "Media console" },
                    { "key": "showTabCalendar", "label": "Calendar panel" },
                    { "key": "showTabWalls", "label": "Wallpaper panel" },
                    { "key": "showTabClipboard", "label": "Clipboard panel" },
                    { "key": "showTabCapture", "label": "Screen optics panel" }
                ]
            }
            Item { Layout.preferredHeight: 8 }
        }
    }

    Component {
        id: umbraPage
        ColumnLayout {
            width: pageLoader.width
            spacing: 10

            SettingToggle {
                Layout.fillWidth: true
                label: "Lock when inactive"
                checked: Settings.idleLockEnabled
                onToggled: Settings.idleLockEnabled = !Settings.idleLockEnabled
            }
            SettingChoice {
                Layout.fillWidth: true
                label: "Idle timeout"
                enabled: Settings.idleLockEnabled
                value: Settings.idleLockMinutes
                choices: [{label: "1m", value: 1}, {label: "5m", value: 5}, {label: "10m", value: 10}, {label: "15m", value: 15}, {label: "30m", value: 30}]
                onSelected: function(value) { Settings.idleLockMinutes = value; }
            }

            ToggleGrid {
                Layout.fillWidth: true
                toggleRows: [
                    { "key": "umbraMotion", "label": "Animations" },
                    { "key": "umbraUseWallpaper", "label": "Active wallpaper" },
                    { "key": "umbraBlurWallpaper", "enabledKey": "umbraUseWallpaper", "label": "Blur wallpaper" },
                    { "key": "umbraShowMedia", "label": "Music controls" },
                    { "key": "umbraShowWeather", "label": "Weather" }
                ]
            }

            SettingTextField {
                Layout.fillWidth: true
                label: "PAM service"
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
                Layout.preferredHeight: 50
                radius: Theme.radiusMedium
                color: Theme.controlRest
                border.width: 0
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    Text {
                        Layout.fillWidth: true
                        text: "Preview lock screen"
                        color: Theme.moon
                        font.family: Theme.fontText
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 32
                        radius: Theme.radiusSmall
                        color: previewPointer.containsMouse ? Theme.accent : Theme.controlHover
                        Text {
                            anchors.centerIn: parent
                            text: "PREVIEW"
                            color: previewPointer.containsMouse ? Theme.void_ : Theme.moon
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
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                radius: Theme.radiusMedium
                color: Theme.controlRest
                border.width: 0
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    Text {
                        Layout.fillWidth: true
                        text: "Lock session now"
                        color: Theme.moon
                        font.family: Theme.fontText
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 32
                        radius: Theme.radiusSmall
                        color: lockPointer.containsMouse ? Theme.rose : Theme.controlDanger
                        Text {
                            anchors.centerIn: parent
                            text: "LOCK"
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

            SettingTextField {
                Layout.fillWidth: true
                label: "Terminal"
                value: Settings.terminal
                onCommitted: function(value) { Settings.terminal = value.trim(); }
            }
            SettingTextField {
                Layout.fillWidth: true
                label: "Browser"
                value: Settings.browser
                onCommitted: function(value) { Settings.browser = value.trim(); }
            }
            SettingTextField {
                Layout.fillWidth: true
                label: "File manager"
                value: Settings.fileManager
                onCommitted: function(value) { Settings.fileManager = value.trim(); }
            }

            SettingChoice {
                Layout.fillWidth: true
                label: "Notification placement"
                value: Settings.notificationPosition
                choices: [
                    { "label": "TOP RIGHT", "value": "top-right" },
                    { "label": "TOP LEFT", "value": "top-left" },
                    { "label": "BOTTOM RIGHT", "value": "bottom-right" },
                    { "label": "BOTTOM LEFT", "value": "bottom-left" }
                ]
                onSelected: function(value) { Settings.notificationPosition = value; }
            }

            SettingToggle {
                Layout.fillWidth: true
                label: "Weather forecast"
                checked: Settings.weatherEnabled
                onToggled: Settings.weatherEnabled = !Settings.weatherEnabled
            }

            SettingTextField {
                Layout.fillWidth: true
                enabled: Settings.weatherEnabled
                label: "Forecast location"
                value: Settings.weatherLocation
                onCommitted: function(value) {
                    Settings.weatherLocation = value.trim();
                }
            }

            SettingChoice {
                Layout.fillWidth: true
                enabled: Settings.weatherEnabled
                label: "Temperature scale"
                value: Settings.temperatureUnit
                choices: [
                    { "label": "CELSIUS", "value": "celsius" },
                    { "label": "FAHRENHEIT", "value": "fahrenheit" }
                ]
                onSelected: function(value) { Settings.temperatureUnit = value; }
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
