import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../services"
import "ThemeIdentity.js" as Identity

ColumnLayout {
    id: root
    spacing: 10
    readonly property var current: Theme.identity
    readonly property bool automatic: Settings.themeIdentity === "auto"

    SettingChoice {
        Layout.fillWidth: true
        label: "Logo selection"
        value: root.automatic ? "auto" : "manual"
        choices: [{label: "Choose a logo", value: "manual"}, {label: "Follow theme color", value: "auto"}]
        detail: "Every logo keeps its original colors."
        onSelected: value => Settings.themeIdentity = value === "auto" ? "auto" : root.current.id
    }
    Text {
        Layout.fillWidth: true
        text: root.automatic ? "Matched to " + Theme.identityColor.toUpperCase() + ": " + root.current.name
                             : root.current.name + " · " + root.current.color
        color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 12
        wrapMode: Text.Wrap
    }
    GridLayout {
        id: grid
        Layout.fillWidth: true
        columns: width >= 460 ? 4 : width >= 300 ? 3 : 2
        rowSpacing: 6; columnSpacing: 6
        Repeater {
            model: Identity.identities
            delegate: Rectangle {
                id: tile
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                Layout.minimumWidth: 80
                radius: 9
                readonly property bool chosen: root.current.id === modelData.id
                activeFocusOnTab: true
                color: chosen ? Theme.controlSelected : pointer.containsMouse || activeFocus ? Theme.controlHover : Theme.controlRest
                border.width: activeFocus ? 2 : chosen ? 1 : 0
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, .85)
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.name + ", " + modelData.color
                Accessible.checked: chosen
                Accessible.onPressAction: choose()
                function choose() { Settings.themeIdentity = modelData.id; }
                Keys.onSpacePressed: choose()
                Keys.onReturnPressed: choose()
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 7; width: 44; height: 44; radius: 8
                    // An explicit backing keeps both ink and snow readable in either UI mode.
                    color: tile.modelData.light ? "#f2f1ef" : "#1b1e26"
                    ThemeMark { anchors.centerIn: parent; width: 34; height: 34; identity: tile.modelData.id }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 57; width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.modelData.name
                    color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 11
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: pointer; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { tile.forceActiveFocus(); tile.choose(); }
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true; wrapMode: Text.Wrap
        text: "The logo also chooses your lock illustration. Automatic appearance follows the chosen logo; dark logos use light backgrounds. Light and Dark remain available in Colors."
        color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11
    }
    Flow {
        Layout.fillWidth: true; spacing: 6
        ActionButton {
            text: "Use " + root.current.name + " color"
            enabled: !AdaptivePalette.busy
            onClicked: {
                const color = root.current.color.toLowerCase();
                // A deliberate palette action, independent of choosing a logo.
                if (Settings.spectralColors.accent) {
                    const colors = Object.assign({}, Settings.spectralColors);
                    colors.accent = color;
                    Settings.spectralColors = colors;
                }
                AdaptivePalette.setSeed(color);
            }
        }
        ActionButton { text: "Preview lock"; onClicked: Umbra.preview() }
        ActionButton {
            text: "Preview login screen"
            enabled: !Settings.saveTimer.running && !Settings.preferencesLoading
            onClicked: Quickshell.execDetached([Environment.script("umbra-greeter"), "preview"])
        }
    }
    Text {
        Layout.fillWidth: true; visible: AdaptivePalette.busy || AdaptivePalette.error.length > 0
        text: AdaptivePalette.busy ? "Generating your palette…" : AdaptivePalette.error
        wrapMode: Text.Wrap; color: AdaptivePalette.error ? Theme.warning : Theme.muted
        font.family: Theme.fontText; font.pixelSize: 11
    }
}
