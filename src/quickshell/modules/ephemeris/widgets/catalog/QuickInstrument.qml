import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../../.."
import "../../../../services"
import "../../../../components"
import "../shared" as Shared

Item {
    id: root
    property string instrument: "media"
    readonly property real preferredSurfaceHeight: instrument === "audio" ? 350 : 280
    readonly property real preferredSurfaceWidth: 480
    function focusPrimary() { primaryButton.forceActiveFocus(); }
    ColumnLayout {
        anchors.fill: parent; spacing: 14
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: root.instrument === "audio" ? "Audio" : "Now playing"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 22; font.bold: true }
            ActionButton { text: "Expand ↗"; onClicked: ShellState.quickInstrument = false }
        }
        RowLayout {
            visible: root.instrument === "media"
            Layout.fillWidth: true; spacing: 14
            ClippingRectangle {
                Layout.preferredWidth: 80; Layout.preferredHeight: 80
                radius: 18; color: Theme.controlRest
                Image { anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: Media.title; elide: Text.ElideRight; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 16; font.bold: true }
                Text { Layout.fillWidth: true; text: Media.artist; elide: Text.ElideRight; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 12 }
                Text { text: Media.identity; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10 }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            ActionButton { visible: root.instrument === "media"; text: "Previous"; enabled: Media.available; onClicked: Media.previous() }
            ActionButton {
                id: primaryButton
                Layout.fillWidth: true
                text: root.instrument === "media" ? (Media.playing ? "Pause" : "Play") : (Audio.muted ? "Unmute" : "Mute")
                enabled: root.instrument === "media" ? Media.available : Audio.sinkNode !== null
                selected: true
                onClicked: root.instrument === "media" ? Media.toggle() : Audio.toggleMute()
            }
            ActionButton { visible: root.instrument === "media"; text: "Next"; enabled: Media.available; onClicked: Media.next() }
        }
        RowLayout {
            Layout.fillWidth: true
            Shared.AudioSlider { Layout.fillWidth: true; value: Audio.percent; maximumValue: 100; muted: Audio.muted; onValueRequested: function(value) { Audio.setVolume(value); } }
            Text { text: Audio.percent + "%"; color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 12 }
        }
        ListView {
            visible: root.instrument === "audio"
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 5
            model: Audio.outputs
            delegate: ActionButton {
                required property var modelData
                width: ListView.view.width
                text: Audio.nodeTitle(modelData)
                selected: modelData === Audio.sinkNode
                onClicked: Audio.setDefaultNode(modelData)
            }
        }
    }
}
