import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../.."
import "../../components"
import "EphemerisRegistry.js" as Registry

// The existing contextual surface and the native interaction fixture share this
// body. It acquires no service data and never loads another instrument preview.
FocusScope {
    id: root
    property string widgetId: ""
    property bool compactInstrument: false
    signal closeRequested()
    signal allSettingsRequested()
    implicitWidth: 360
    implicitHeight: Math.min(620, header.implicitHeight + controls.implicitHeight + footer.implicitHeight + 56)
    function focusPrimary() { closeButton.forceActiveFocus(); }
    function revealFocus() {
        const item = root.Window.window ? root.Window.window.activeFocusItem : null;
        if (!item) return;
        let ancestor = item;
        while (ancestor && ancestor !== controls) ancestor = ancestor.parent;
        if (!ancestor) return;
        const point = item.mapToItem(controls, 0, 0);
        if (point.y < viewport.contentY) viewport.contentY = point.y;
        else if (point.y + item.height > viewport.contentY + viewport.height)
            viewport.contentY = point.y + item.height - viewport.height;
        viewport.contentY = Math.max(0, Math.min(viewport.contentY, Math.max(0, viewport.contentHeight - viewport.height)));
    }
    onWidgetIdChanged: viewport.contentY = 0
    Keys.onEscapePressed: closeRequested()
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() { Qt.callLater(root.revealFocus); }
    }
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: Theme.mantle
        border.width: 1
        border.color: Theme.line
    }
    // Keep background presses in the popup rather than the dismissal scrim.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        RowLayout {
            id: header
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: Registry.entry(root.widgetId).title
                    color: Theme.moon
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.textBody
                    font.bold: true
                    wrapMode: Text.Wrap
                }
                Text {
                    text: "Customize this instrument"
                    color: Theme.muted
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textCaption
                }
            }
            ActionButton {
                id: closeButton
                text: "×"
                Accessible.name: "Close instrument settings"
                Layout.preferredWidth: 36
                onClicked: root.closeRequested()
            }
        }
        Flickable {
            id: viewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            contentWidth: width
            contentHeight: controls.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            ColumnLayout {
                id: controls
                width: viewport.width - 8
                spacing: 10
                SettingChoice {
                    Layout.fillWidth: true
                    visible: root.widgetId !== "walls"
                    label: "Material"
                    detail: "Changes the visible instrument. Global follows the appearance setting."
                    value: Settings.appearanceFor(root.widgetId)
                    choices: [{label: "Global", value: "inherit"}, {label: "Classic", value: "classic"}, {label: "Gravity", value: "gravity"}]
                    onSelected: function(value) { Settings.setModuleAppearance(root.widgetId, value); }
                }
                Loader {
                    Layout.fillWidth: true
                    Layout.preferredHeight: item ? item.implicitHeight : 0
                    sourceComponent: root.widgetId === "calendar" ? calendarControls
                        : root.widgetId === "media" ? mediaControls
                        : root.widgetId === "walls" ? wallpaperControls
                        : root.widgetId === "apps" ? launcherControls
                        : root.widgetId === "notifications" ? notificationControls
                        : root.widgetId === "system" || root.widgetId === "quickstats" ? systemControls : null
                }
            }
        }
        ActionButton {
            id: footer
            Layout.fillWidth: true
            text: "Open all settings"
            onClicked: root.allSettingsRequested()
        }
    }
    Component {
        id: calendarControls
        ColumnLayout {
            spacing: 10
            SettingChoice {
                Layout.fillWidth: true
                label: "Opening view"
                detail: "Also changes the open calendar. Date navigation stays available in every view."
                value: Settings.calendarDefaultMode
                choices: [{label: "Calendar", value: 0}, {label: "Heliocentric", value: 1}, {label: "Earth", value: 2}]
                onSelected: function(value) { Settings.calendarDefaultMode = value; }
            }
            SettingToggle {
                Layout.fillWidth: true
                label: "Weather"
                checked: Settings.weatherEnabled
                onToggled: Settings.weatherEnabled = !Settings.weatherEnabled
            }
            SettingChoice {
                Layout.fillWidth: true
                label: "Temperature"
                value: Settings.temperatureUnit
                choices: [{label: "°C", value: "celsius"}, {label: "°F", value: "fahrenheit"}]
                onSelected: function(value) { Settings.temperatureUnit = value; }
            }
        }
    }
    Component {
        id: mediaControls
        ColumnLayout {
            spacing: 10
            SettingChoice {
                Layout.fillWidth: true
                visible: !root.compactInstrument
                label: "Spectrum"
                value: Settings.resonanceVisualizer
                choices: [{label: "Orbit", value: "ring"}, {label: "Bars", value: "bars"}]
                onSelected: function(value) { Settings.resonanceVisualizer = value; }
            }
            Text { text: "In Aperture"; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: Theme.textCaption }
            SettingToggle { Layout.fillWidth: true; label: "Show media in bar"; checked: Settings.showMedia; onToggled: Settings.showMedia = !Settings.showMedia }
            SettingToggle { Layout.fillWidth: true; label: "Progress in bar"; checked: Settings.showMediaProgress; onToggled: Settings.showMediaProgress = !Settings.showMediaProgress }
            SettingToggle { Layout.fillWidth: true; label: "Elapsed time in bar"; checked: Settings.showMediaTime; onToggled: Settings.showMediaTime = !Settings.showMediaTime }
        }
    }
    Component {
        id: wallpaperControls
        SettingChoice {
            label: "Wallpaper transition"
            detail: "Used when applying a still image with awww or swww. Other backends keep their own transition behavior."
            value: Settings.wallpaperTransition
            choices: [{label: "Any", value: "any"}, {label: "Fade", value: "fade"}, {label: "Grow", value: "grow"}, {label: "Wave", value: "wave"}, {label: "Swipe", value: "swipe"}, {label: "Diagonal", value: "diagonal"}]
            onSelected: function(value) { Settings.wallpaperTransition = value; }
        }
    }
    Component {
        id: launcherControls
        ColumnLayout {
            spacing: 10
            SettingToggle { Layout.fillWidth: true; label: "App descriptions"; checked: Settings.showAppDescriptions; onToggled: Settings.showAppDescriptions = !Settings.showAppDescriptions }
            SettingToggle { Layout.fillWidth: true; label: "Launcher button in bar"; checked: Settings.showLauncherButton; onToggled: Settings.showLauncherButton = !Settings.showLauncherButton }
        }
    }
    Component {
        id: notificationControls
        SettingChoice {
            label: "Notification position"
            value: Settings.notificationPosition
            choices: [{label: "Left", value: "left"}, {label: "Right", value: "right"}]
            onSelected: function(value) { Settings.notificationPosition = value; }
        }
    }
    Component {
        id: systemControls
        SettingToggle { label: "Show stats in bar"; checked: Settings.showSystemStats; onToggled: Settings.showSystemStats = !Settings.showSystemStats }
    }
}
