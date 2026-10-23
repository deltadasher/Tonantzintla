import QtQuick
import QtQuick.Layouts
import Quickshell
import "."
import "components"
import "modules/aperture"

Window {
    id: window
    width: 960; height: 720; visible: true
    color: Theme.void_
    Rectangle { anchors.fill: parent; color: Theme.void_ }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 28; spacing: 14
        Text { text: "Observatory · control study"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 24 }
        Text { text: "Rest, selected, keyboard focus and disabled"; color: Theme.muted; font.family: Theme.fontText }
        SettingChoice {
            Layout.fillWidth: true; label: "Instrument material"
            detail: "Live appearance choices share the same fixed input targets."
            choices: [{label: "Use global", value: "inherit"}, {label: "Classic", value: "classic"}, {label: "Gravity", value: "gravity"}]
            value: "gravity"
        }
        SettingToggle { Layout.fillWidth: true; label: "Optical controls"; detail: "Translucent highlights over a solid instrument backing"; checked: true }
        SettingToggle { id: focused; Layout.fillWidth: true; label: "Keyboard focus"; checked: false }
        SettingToggle { Layout.fillWidth: true; label: "Unavailable control"; detail: "A disabled control remains legible"; checked: true; enabled: false }
        SettingTextField { Layout.fillWidth: true; label: "Observatory name"; value: "Night watch" }
        Row {
            spacing: 12
            DockAppButton { width: 70; height: 70; name: "Left edge"; glyph: "L"; edge: "left"; running: true; active: true }
            DockAppButton { width: 70; height: 70; name: "Top edge"; glyph: "T"; edge: "top"; running: true; active: true }
            DockAppButton { width: 70; height: 70; name: "Right edge"; glyph: "R"; edge: "right"; running: true; active: true }
            DockAppButton { width: 70; height: 70; name: "Bottom edge"; glyph: "B"; edge: "bottom"; running: true; active: true }
        }
        Item { Layout.fillHeight: true }
    }
    Timer {
        interval: 400; running: true
        onTriggered: {
            focused.forceActiveFocus();
            window.contentItem.grabToImage(function(result) {
                if (!result.saveToFile(Quickshell.env("CONTROL_CAPTURE"))) console.error("CONTROL_CAPTURE_FAILED");
                else console.log("CONTROL_CAPTURE_OK");
                Qt.quit();
            });
        }
    }
}
