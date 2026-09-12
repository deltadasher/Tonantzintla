import "../.."
import "../../services"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property real presentation: 1
    readonly property string instrumentModule: Osd.kind === "brightness" ? "battery" : Osd.kind === "microphone" ? "media" : "audio"
    readonly property color instrumentTone: Theme.moduleAccent(instrumentModule)

    radius: Theme.radiusLarge
    color: Theme.mantle
    border.width: 0
    border.color: Theme.barHairlineHover
    opacity: root.presentation
    scale: Theme.motionScale > 0 ? 0.9 + root.presentation * 0.1 : 1
    clip: true

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        spacing: 13

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 13
            color: Qt.rgba(root.instrumentTone.r, root.instrumentTone.g, root.instrumentTone.b, 0.12)
            border.width: 0
            border.color: Qt.rgba(root.instrumentTone.r, root.instrumentTone.g, root.instrumentTone.b, 0.38)

            Text {
                anchors.centerIn: parent
                text: Osd.kind === "brightness" ? "☀" : Osd.kind === "microphone" ? (Osd.muted ? "×" : "●") : Osd.muted ? "×" : "♪"
                color: root.instrumentTone
                font.family: Theme.fontDisplay
                font.pixelSize: 17
                font.weight: Font.Bold
            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: Osd.label
                    elide: Text.ElideRight
                    color: Theme.moon
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 0.9
                }

                Text {
                    text: Osd.muted ? "Muted" : Osd.value + "%"
                    color: Osd.muted ? Theme.muted : root.instrumentTone
                    font.family: Theme.fontDisplay
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }

            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: 3
                color: Theme.line
                clip: true

                Rectangle {
                    width: parent.width * Math.min(100, Osd.value) / 100
                    height: parent.height
                    radius: parent.radius
                    color: Osd.muted ? Theme.lineBright : root.instrumentTone

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.motionScale > 0 ? Theme.motionFast : 0
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

        }

    }

    transform: Translate {
        y: Theme.motionScale > 0 ? (1 - root.presentation) * 18 : 0
    }

}
