import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root
    property string barStatus: ""
    spacing: 10
    property string page: "identity"
    function preset(name) {
        if (name === "prism") {
            Settings.barMaterial = "liquid"; Settings.panelMaterial = "liquid";
            Settings.surfaceFrost = .45; Settings.surfaceRefraction = .65; Settings.surfaceTint = .12;
            Settings.panelGlassOpacity = .82; Settings.barOpacity = .66;
            Settings.barCornerRadius = 26; Settings.barEdgeStyle = "hairline";
        } else if (name === "porcelain") {
            Settings.barMaterial = "frosted"; Settings.panelMaterial = "classic";
            Settings.surfaceFrost = .8; Settings.surfaceTint = 0;
            Settings.barOpacity = .88; Settings.barCornerRadius = 10; Settings.barEdgeStyle = "hairline";
        } else {
            Settings.barMaterial = "classic"; Settings.panelMaterial = "classic";
            Settings.barOpacity = 1; Settings.barCornerRadius = 6; Settings.barEdgeStyle = "none";
        }
    }
    Text {
        text: "Appearance"; color: Theme.moon
        font.family: Theme.fontDisplay; font.pixelSize: 20; font.weight: Font.DemiBold
    }
    Item {
        Layout.fillWidth: true; Layout.preferredHeight: 132
        LiquidSurface {
            id: samplePanel
            x: 0; y: 48; width: parent.width; height: 84; radius: 16
            material: Settings.panelMaterial; fillOpacity: Settings.panelGlassOpacity
            viewportSize: Qt.size(parent.width, 132); viewportOrigin: Qt.point(0, 48)
            Loader {
                anchors.fill: parent; clip: true
                active: Settings.panelMaterial === "gravity"
                sourceComponent: GravityMaterial {
                    geometry: ({x: 0, y: 0, width: samplePanel.width, height: samplePanel.height, radius: 16})
                }
            }
            Text { x: 18; y: 14; text: "Ephemeris"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 16 }
            Text { x: 18; y: 42; text: Theme.isLight ? "Light mode preview" : "Dark mode preview"; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 12 }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; radius: 13; color: Theme.accent }
        }
        Row {
            width: parent.width; spacing: 8
            Repeater {
                model: ["Aperture", "18:42", "♫ Resonance"]
                LiquidSurface {
                    required property string modelData
                    width: (parent.width - 16) / 3; height: 38
                    radius: Math.min(19, Settings.barCornerRadius)
                    onStatusTextChanged: if (modelData === "Aperture") root.barStatus = statusText
                    Component.onCompleted: if (modelData === "Aperture") root.barStatus = statusText
                    material: Settings.barMaterial; fillOpacity: Settings.barSurfaceOpacity; edgeStyle: Settings.barEdgeStyle
                    viewportSize: Qt.size(root.width, 132); viewportOrigin: Qt.point(x, 0)
                    Text { anchors.centerIn: parent; width: parent.width - 16; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: parent.modelData; color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 11 }
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true; visible: samplePanel.statusText.length > 0 || root.barStatus.length > 0
        text: samplePanel.statusText || root.barStatus; wrapMode: Text.Wrap
        color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11
    }
    SettingChoice {
        objectName: "appearanceModeControl"
        Layout.fillWidth: true; label: "Color mode"; value: Settings.themeMode
        detail: "Light and Dark stay selected when you change your logo or style. Auto uses your theme color."
        choices: [{label: "Auto", value: "auto"}, {label: "Light", value: "light"}, {label: "Dark", value: "dark"}]
        onSelected: value => Settings.themeMode = value
    }
    Text { text: "Quick styles"; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 12 }
    Flow {
        Layout.fillWidth: true; spacing: 6
        ActionButton { text: "Glass"; onClicked: root.preset("prism") }
        ActionButton { text: "Soft"; onClicked: root.preset("porcelain") }
        ActionButton { text: "Solid"; onClicked: root.preset("ink") }
    }
    SettingChoice {
        Layout.fillWidth: true; label: "Customize"; value: root.page
        choices: [{label: "Logo", value: "identity"}, {label: "Colors", value: "colors"}, {label: "Style", value: "materials"}]
        onSelected: value => root.page = value
    }
    ActionButton {
        text: "Edit bar"
        onClicked: ShellState.enterBarEditMode()
    }
    ThemeIdentityPicker { Layout.fillWidth: true; visible: root.page === "identity" }
    ColumnLayout {
        visible: root.page === "colors"; Layout.fillWidth: true; spacing: 8
        SettingTextField {
            Layout.fillWidth: true; label: "Theme color"; value: Settings.paletteSeedColor
            detail: "Enter a hex color, such as #467B50, then press Enter."
            enabled: !AdaptivePalette.busy
            onCommitted: value => { if (value !== Settings.paletteSeedColor) AdaptivePalette.setSeed(value); }
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.Wrap
            text: AdaptivePalette.busy ? "Updating colors…" : AdaptivePalette.error || "Your chosen color stays the same. Other colors update to match it. Leave this empty to use the wallpaper colors."
            color: AdaptivePalette.error ? Theme.warning : Theme.muted; font.family: Theme.fontText; font.pixelSize: 11
        }
        SettingTextField {
            Layout.fillWidth: true; label: "Button color"; value: Settings.spectralColors.accent || ""
            detail: "Optional. Leave empty to use the theme color."
            onCommitted: value => {
                if (value && !/^#[0-9a-f]{6}$/i.test(value)) { exactStatus.text = "Use #RRGGBB, or leave the field empty."; return; }
                const colors = Object.assign({}, Settings.spectralColors);
                if (value) colors.accent = value.toLowerCase(); else delete colors.accent;
                Settings.spectralColors = colors;
                exactStatus.text = "";
            }
        }
        Text { id: exactStatus; Layout.fillWidth: true; visible: text.length > 0; wrapMode: Text.Wrap; color: Theme.warning; font.family: Theme.fontText; font.pixelSize: 11 }
        Text {
            Layout.fillWidth: true; visible: !!Settings.spectralColors.accent; wrapMode: Text.Wrap
            text: "This color replaces the theme color for buttons. Auto mode uses it too."
            color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11
        }
    }
    ColumnLayout {
        visible: root.page === "materials"; Layout.fillWidth: true; spacing: 8

        SettingChoice {
            Layout.fillWidth: true; label: "Panel style"; value: Settings.panelMaterial
            choices: [{label: "Solid", value: "classic"}, {label: "Gravity", value: "gravity"}, {label: "Frosted", value: "frosted"}, {label: "Liquid glass", value: "liquid"}]
            onSelected: value => Settings.panelMaterial = value
        }
        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "These glass settings apply to bars and panels. Use the bar editor for bar-specific options."; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11 }
        SettingChoice {
            Layout.fillWidth: true; label: "Glass blur"; value: Settings.surfaceFrost
            choices: [{label: "Clear", value: .15}, {label: "Soft", value: .45}, {label: "Strong", value: .8}]
            onSelected: value => Settings.surfaceFrost = value
        }
        SettingChoice {
            Layout.fillWidth: true; label: "Glass distortion"; value: Settings.surfaceRefraction
            choices: [{label: "Subtle", value: .25}, {label: "Balanced", value: .65}, {label: "Strong", value: 1}]
            onSelected: value => Settings.surfaceRefraction = value
        }
        SettingChoice {
            Layout.fillWidth: true; label: "Glass color strength"; value: Settings.surfaceTint
            choices: [{label: "Neutral", value: 0}, {label: "Soft", value: .12}, {label: "Strong", value: .45}]
            onSelected: value => Settings.surfaceTint = value
        }
        SettingChoice {
            Layout.fillWidth: true; label: "Panel opacity"; value: Settings.panelGlassOpacity
            choices: [{label: "More transparent", value: .6}, {label: "Balanced", value: .82}, {label: "More solid", value: .95}]
            onSelected: value => Settings.panelGlassOpacity = value
        }
    }

}
