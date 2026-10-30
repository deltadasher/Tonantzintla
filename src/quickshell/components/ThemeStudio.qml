import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root
    property string barStatus: ""
    spacing: 10
    property string page: "materials"
    function preset(name) {
        if (name === "prism") {
            Settings.themeMode = "auto"; Settings.barMaterial = "liquid"; Settings.panelMaterial = "liquid";
            Settings.surfaceFrost = .45; Settings.surfaceRefraction = .65; Settings.surfaceTint = .12;
            Settings.panelGlassOpacity = .82; Settings.barOpacity = .66;
            Settings.barCornerRadius = 26; Settings.barEdgeStyle = "hairline";
        } else if (name === "porcelain") {
            Settings.themeMode = "light"; Settings.barMaterial = "frosted"; Settings.panelMaterial = "classic";
            Settings.surfaceFrost = .8; Settings.surfaceTint = 0;
            Settings.barOpacity = .88; Settings.barCornerRadius = 10; Settings.barEdgeStyle = "hairline";
        } else {
            Settings.themeMode = "dark"; Settings.barMaterial = "classic"; Settings.panelMaterial = "classic";
            Settings.barOpacity = 1; Settings.barCornerRadius = 6; Settings.barEdgeStyle = "none";
        }
    }
    Text {
        text: "Theme studio"; color: Theme.moon
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
            Text { x: 18; y: 42; text: Theme.isLight ? "Daylight, with your colors." : "An observatory after dark."; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 12 }
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
    Flow {
        Layout.fillWidth: true; spacing: 6
        ActionButton { text: "Prism"; onClicked: root.preset("prism") }
        ActionButton { text: "Porcelain"; onClicked: root.preset("porcelain") }
        ActionButton { text: "Ink"; onClicked: root.preset("ink") }
    }
    SettingChoice {
        Layout.fillWidth: true; label: "Customize"; value: root.page
        choices: [{label: "Colors", value: "colors"}, {label: "Materials", value: "materials"}]
        onSelected: value => root.page = value
    }
    ActionButton {
        text: "Open Bar Studio"
        onClicked: ShellState.enterBarEditMode()
    }
    ColumnLayout {
        visible: root.page === "colors"; Layout.fillWidth: true; spacing: 8
        SettingChoice {
            Layout.fillWidth: true; label: "Appearance"; value: Settings.themeMode
            detail: "Automatic follows your chosen color: dark colors use dark surfaces, bright colors use light surfaces."
            choices: [{label: "Automatic", value: "auto"}, {label: "Light", value: "light"}, {label: "Dark", value: "dark"}]
            onSelected: value => Settings.themeMode = value
        }
        SettingTextField {
            Layout.fillWidth: true; label: "Theme color · #RRGGBB"; value: Settings.paletteSeedColor
            detail: "Press Enter to use this exact accent and generate matching colors."
            enabled: !AdaptivePalette.busy
            onCommitted: value => { if (value !== Settings.paletteSeedColor) AdaptivePalette.setSeed(value); }
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.Wrap
            text: AdaptivePalette.busy ? "Generating your palette…" : AdaptivePalette.error || "Your chosen accent stays exact. Matugen generates the supporting colors. Leave it empty to follow the wallpaper."
            color: AdaptivePalette.error ? Theme.warning : Theme.muted; font.family: Theme.fontText; font.pixelSize: 11
        }
        SettingTextField {
            Layout.fillWidth: true; label: "Exact action color"; value: Settings.spectralColors.accent || ""
            detail: "Optional separate accent. Blank uses your theme color or the automatic palette."
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
            text: "This override takes priority over your theme color and determines Automatic appearance."
            color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11
        }
    }
    ColumnLayout {
        visible: root.page === "materials"; Layout.fillWidth: true; spacing: 8

        SettingChoice {
            Layout.fillWidth: true; label: "Ephemeris finish"; value: Settings.panelMaterial
            choices: [{label: "Classic", value: "classic"}, {label: "Gravity", value: "gravity"}, {label: "Frosted", value: "frosted"}, {label: "Liquid glass", value: "liquid"}]
            onSelected: value => Settings.panelMaterial = value
        }
        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Frost, refraction and tint apply to both bars and instruments. Set the bar finish and faces in Bar Studio."; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11 }
        SettingChoice {
            Layout.fillWidth: true; label: "Shared glass frost"; value: Settings.surfaceFrost
            choices: [{label: "Clear", value: .15}, {label: "Soft", value: .45}, {label: "Diffuse", value: .8}]
            onSelected: value => Settings.surfaceFrost = value
        }
        SettingChoice {
            Layout.fillWidth: true; label: "Shared glass refraction"; value: Settings.surfaceRefraction
            choices: [{label: "Subtle", value: .25}, {label: "Balanced", value: .65}, {label: "Deep", value: 1}]
            onSelected: value => Settings.surfaceRefraction = value
        }
        SettingChoice {
            Layout.fillWidth: true; label: "Shared glass tint"; value: Settings.surfaceTint
            choices: [{label: "Neutral", value: 0}, {label: "Soft", value: .12}, {label: "Rich", value: .45}]
            onSelected: value => Settings.surfaceTint = value
        }
        SettingChoice {
            Layout.fillWidth: true; label: "Instrument density"; value: Settings.panelGlassOpacity
            choices: [{label: "Airy", value: .6}, {label: "Balanced", value: .82}, {label: "Reading", value: .95}]
            onSelected: value => Settings.panelGlassOpacity = value
        }
    }

}
