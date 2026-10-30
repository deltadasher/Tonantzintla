import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root
    spacing: Theme.spaceSm
    property string selectedRole: "accent"
    property string statusMessage: ""
    property bool statusOk: true
    property string hoveredPreset: ""
    readonly property var channels: [
        {label: "Selection / action", value: "accent"},
        {label: "Cool telemetry", value: "cyan"},
        {label: "Media / signals", value: "rose"},
        {label: "Success", value: "success"},
        {label: "Warning", value: "warning"},
        {label: "Error", value: "danger"}
    ]
    readonly property var presets: [
        {name: "Violet", key: "violet"}, {name: "Cyan", key: "cyan"},
        {name: "Rose", key: "rose"}, {name: "Amber", key: "amber"},
        {name: "Emerald", key: "emerald"}, {name: "Ember", key: "solar"},
        {name: "Silver", key: "silver"}
    ]
    readonly property string channelLabel: (channels.find(function(channel) { return channel.value === root.selectedRole; }) || channels[0]).label
    readonly property string currentColor: String(Theme[selectedRole])
    onSelectedRoleChanged: { statusMessage = ""; statusOk = true; Qt.callLater(root.syncEditor); }

    function syncEditor() {
        // A rejected draft may differ from an unchanged effective color. Force
        // the shared editor to reload, then restore its live value binding.
        hexField.value = "";
        hexField.value = Qt.binding(function() { return root.currentColor; });
    }

    function applyColor(value) {
        const result = Settings.setSpectralColor(selectedRole, value, String(Theme.void_));
        statusOk = result.ok;
        statusMessage = result.message;
        if (result.ok) syncEditor();
    }
    function resetAll() {
        for (const channel of channels)
            Settings.setSpectralColor(channel.value, "", String(Theme.void_));
        statusOk = true;
        statusMessage = "All channels follow the theme again.";
        syncEditor();
    }

    Text {
        Layout.fillWidth: true
        text: "Spectral colors"
        color: Theme.moon
        font.family: Theme.fontDisplay
        font.pixelSize: Theme.textBody
    }
    Text {
        Layout.fillWidth: true
        text: "Tune the colors used by actions and measurements. The open interface is the preview. Automatic appearance follows your action color."
        wrapMode: Text.Wrap
        color: Theme.muted
        font.family: Theme.fontText
        font.pixelSize: Theme.textCaption
    }
    SettingChoice {
        Layout.fillWidth: true
        label: "Channel"
        value: root.selectedRole
        choices: root.channels
        onSelected: function(value) { root.selectedRole = value; }
    }
    Text {
        Layout.fillWidth: true
        text: root.hoveredPreset.length ? "Preset · " + root.hoveredPreset : "Theme swatches"
        color: Theme.muted
        font.family: Theme.fontText
        font.pixelSize: Theme.textCaption
    }
    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: root.presets
            Rectangle {
                id: swatch
                required property var modelData
                readonly property string swatchColor: Theme.accents[modelData.key]
                readonly property bool selected: root.currentColor.toLowerCase() === swatchColor.toLowerCase()
                width: 32; height: 32
                radius: Theme.radiusSmall
                color: pointer.pressed ? Theme.controlPressed : pointer.containsMouse || activeFocus ? Theme.controlHover : Theme.controlRest
                border.width: activeFocus || selected ? 1 : 0
                border.color: activeFocus ? Theme.moon : Theme.lineBright
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Use " + modelData.name + " for " + root.channelLabel
                Accessible.checked: selected
                Accessible.onPressAction: root.applyColor(swatchColor)
                Keys.onSpacePressed: root.applyColor(swatchColor)
                Keys.onReturnPressed: root.applyColor(swatchColor)
                onActiveFocusChanged: if (activeFocus) root.hoveredPreset = modelData.name
                Rectangle { anchors.fill: parent; anchors.margins: 6; radius: width / 2; color: swatch.swatchColor }
                MouseArea {
                    id: pointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoveredPreset = swatch.modelData.name
                    onExited: root.hoveredPreset = ""
                    onClicked: { swatch.forceActiveFocus(); root.applyColor(swatch.swatchColor); }
                }
            }
        }
    }
    SettingTextField {
        id: hexField
        Layout.fillWidth: true
        label: "Hex color"
        detail: "Opaque six-digit color, for example #a99cff. Press Enter to apply."
        value: root.currentColor
        onCommitted: function(value) { root.applyColor(value); }
    }
    Text {
        Layout.fillWidth: true
        text: root.statusMessage.length ? root.statusMessage : "Enter any #RRGGBB color, then press Enter. Your exact choice is preserved."
        wrapMode: Text.Wrap
        color: root.statusOk ? Theme.muted : Theme.warning
        font.family: Theme.fontText
        font.pixelSize: Theme.textCaption
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
    Flow {
        Layout.fillWidth: true
        spacing: Theme.spaceXs
        ActionButton { text: "Reset this channel"; onClicked: root.applyColor("") }
        ActionButton { text: "Reset all channels"; onClicked: root.resetAll() }
    }
}
