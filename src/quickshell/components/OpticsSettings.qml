import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import ".."

ColumnLayout {
    id: root
    spacing: Theme.spaceSm
    property string scope: "global"
    readonly property string chosenMaterial: scope === "global" ? Settings.controlMaterial
        : Settings.controlMaterialScopes[scope] || "inherit"
    Text {
        Layout.fillWidth: true
        text: "Control optics"
        color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: Theme.textBody
    }
    Text {
        Layout.fillWidth: true
        text: "Etched uses light shading. Frosted and Lens refract a small shared wallpaper still inside controls. Instrument backings and text stay opaque."
        wrapMode: Text.Wrap; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: Theme.textCaption
    }
    SettingChoice {
        Layout.fillWidth: true
        label: "Control family"; value: root.scope
        choices: [{label:"Global",value:"global"},{label:"Aperture",value:"aperture"},
                  {label:"Instruments",value:"instruments"},{label:"Dock",value:"dock"},{label:"Umbra",value:"umbra"}]
        onSelected: function(value) { root.scope = value; }
    }
    SettingChoice {
        Layout.fillWidth: true
        label: "Finish"; value: root.chosenMaterial
        choices: (root.scope === "global" ? [] : [{label:"Inherit",value:"inherit"}]).concat([
            {label:"Etched",value:"etched"},{label:"Frosted",value:"frosted"},{label:"Lens",value:"lens"}])
        onSelected: function(value) {
            if (root.scope === "global") Settings.controlMaterial = value;
            else Settings.setControlFinishScope(root.scope, value);
        }
    }
    Repeater {
        model: [
            {label:"Control fill opacity",key:"controlOpacity",scale:100,max:100,step:5,unit:"%"},
            {label:"Control roundness",key:"controlRadius",scale:1,max:24,step:1,unit:" px"},
            {label:"Lens strength",key:"opticalStrength",scale:100,max:100,step:5,unit:"%"},
            {label:"Frost",key:"opticalFrost",scale:100,max:100,step:5,unit:"%"},
            {label:"Color dispersion",key:"opticalDispersion",scale:100,max:100,step:5,unit:"%"}
        ]
        ColumnLayout {
            id: option
            required property var modelData
            Layout.fillWidth: true; spacing: 2
            Text {
                Layout.fillWidth: true
                text: option.modelData.label + " · " + Math.round(Settings[option.modelData.key] * option.modelData.scale) + option.modelData.unit
                color: Theme.moon; font.family: Theme.fontText; font.pixelSize: Theme.textCaption
            }
            Controls.Slider {
                id: slider
                Layout.fillWidth: true; implicitHeight: 32
                from: 0; to: option.modelData.max; stepSize: option.modelData.step
                value: Settings[option.modelData.key] * option.modelData.scale
                onMoved: Settings[option.modelData.key] = value / option.modelData.scale
                Accessible.name: option.modelData.label
                background: Rectangle {
                    x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: slider.availableWidth; height: 4; radius: 2; color: Theme.line
                    Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 2; color: Theme.accent }
                }
                handle: Rectangle {
                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: 18; height: 18; radius: 9; color: Theme.moon
                    border.width: slider.activeFocus ? 2 : 0; border.color: Theme.accent
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        text: "These controls tune Tonantzintla’s interpretation. Video wallpapers use an existing cached still; missing stills and software rendering use Etched. No application windows are captured."
        wrapMode: Text.Wrap; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: Theme.textCaption
    }
}
