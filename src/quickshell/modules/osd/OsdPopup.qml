import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../services"
import "../../components"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property bool targetScreen: Compositor.focusedOutput.length > 0
        ? Compositor.focusedOutput === modelData.name
        : Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]
    property real presentation: 0
    readonly property string instrumentModule: Osd.kind === "brightness" ? "battery"
        : Osd.kind === "microphone" ? "media" : "audio"
    readonly property color instrumentTone: Theme.moduleAccent(instrumentModule)

    anchors { bottom: true }
    margins.bottom: 62
    implicitWidth: 330
    implicitHeight: 74
    visible: Osd.visible && targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tonantzintla-orbit-osd"

    function pulse() {
        presentation = 0;
        reveal.restart();
    }

    Component.onCompleted: {
        if (Osd.visible && targetScreen)
            pulse();
    }

    onVisibleChanged: {
        if (visible)
            pulse();
    }

    Connections {
        target: Osd
        function onSerialChanged() {
            if (root.visible)
                root.pulse();
        }
    }

    Loader {
        anchors.fill: parent
        active: root.visible
        sourceComponent: osdContent
    }

    Component {
        id: osdContent

        Rectangle {
            radius: Theme.radiusLarge
            color: Theme.glass
            border.width: 0
            border.color: Theme.barHairlineHover
            opacity: root.presentation
            scale: 0.9 + root.presentation * 0.1
            transform: Translate { y: (1 - root.presentation) * 18 }
            clip: true

        Rectangle {
            width: 126
            height: 126
            radius: 63
            x: -42
            y: -54
            color: root.instrumentTone
            opacity: 0.08
        }

        InstrumentFrame {
            anchors.fill: parent
            anchors.margins: 4
            module: root.instrumentModule
            presentation: root.presentation
        }

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
                    text: Osd.kind === "brightness" ? "☀"
                        : Osd.kind === "microphone" ? (Osd.muted ? "×" : "●")
                        : Osd.muted ? "×" : "♪"
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
                        color: Theme.moon
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.9
                    }
                    Text {
                        text: Osd.value + "%"
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
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                }
            }
            }
        }
    }

    NumberAnimation {
        id: reveal
        target: root
        property: "presentation"
        to: 1
        duration: Settings.motion ? 260 : 0
        easing.type: Easing.OutBack
    }
}
