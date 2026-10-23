pragma ComponentBehavior: Bound
import "../.."
import "../../services"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property real presentation: 1
    readonly property bool vertical: Settings.osdOrientation === "vertical"
    readonly property string instrumentModule: Osd.kind === "brightness" ? "battery" : Osd.kind === "microphone" ? "media" : "audio"
    readonly property color instrumentTone: Theme.moduleAccent(instrumentModule)
    readonly property string valueText: Osd.statusMode ? (Osd.value>0?"On":"Off") : Osd.muted ? "Muted" : Osd.value + "%"
    readonly property string glyph: Osd.kind==="capslock" ? "⇪" : Osd.kind==="numlock" ? "123" : Osd.kind==="airplane" ? "✈" : Osd.kind === "brightness" ? "☀" : Osd.kind === "microphone" ? (Osd.muted ? "×" : "●") : Osd.muted ? "×" : "♪"
    readonly property real contentScale: Math.max(.01,Math.min(1,width/(vertical?100:160),height/(vertical?140:60)))
    radius: Theme.radiusLarge
    color: Theme.mantle
    opacity: root.presentation
    scale: Theme.motionScale > 0 ? 0.9 + root.presentation * 0.1 : 1
    clip: true

    component Badge: Rectangle {
        implicitWidth: 40; implicitHeight: 40; radius: 13
        color: Qt.rgba(root.instrumentTone.r, root.instrumentTone.g, root.instrumentTone.b, 0.12)
        Text {
            anchors.centerIn: parent; text: root.glyph; color: root.instrumentTone
            font.family: Theme.iconFamily(text); font.pixelSize: 17; font.weight: Font.Normal
        }
    }
    component ValueText: Text {
        text: root.valueText; color: Osd.muted ? Theme.muted : root.instrumentTone
        font.family: Theme.fontDisplay; font.pixelSize: 15; font.weight: Font.Bold
    }
    component Level: Rectangle {
        property bool upright: false
        radius: 3; color: Theme.line; clip: true
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.upright ? parent.width : parent.width * Math.max(0,Math.min(100,Osd.value))/100
            height: parent.upright ? parent.height * Math.max(0,Math.min(100,Osd.value))/100 : parent.height
            radius: parent.radius; color: Osd.muted ? Theme.lineBright : root.instrumentTone
            Behavior on width { NumberAnimation { duration: Theme.motionScale > 0 ? Theme.motionFast : 0; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Theme.motionScale > 0 ? Theme.motionFast : 0; easing.type: Easing.OutCubic } }
        }
    }
    Loader {
        anchors.centerIn: parent
        width: root.width/root.contentScale; height: root.height/root.contentScale
        scale: root.contentScale
        sourceComponent: root.vertical ? upright : horizontal
    }
    Component {
        id: horizontal
        Item {
            objectName: "osdHorizontal"
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 15; anchors.rightMargin: 15; spacing: 13
                Badge { Layout.preferredWidth: 40; Layout.preferredHeight: 40 }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true; Layout.minimumWidth: 0
                            text: Osd.label; elide: Text.ElideRight; color: Theme.moon
                            font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: .9
                        }
                        ValueText {}
                    }
                    Level { Layout.fillWidth: true; Layout.preferredHeight: 5; visible: !Osd.statusMode }
                }
            }
        }
    }
    Component {
        id: upright
        Item {
            objectName: "osdVertical"
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 8
                Badge { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 34; Layout.preferredHeight: 34 }
                Text {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: Osd.label; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; color: Theme.moon
                    font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold
                }
                Level { upright: true; visible: !Osd.statusMode; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 7; Layout.fillHeight: true; Layout.minimumHeight: 0 }
                Item { visible: Osd.statusMode; Layout.fillHeight: true }
                ValueText { Layout.alignment: Qt.AlignHCenter }
            }
        }
    }
    transform: Translate { y: Theme.motionScale > 0 ? (1 - root.presentation) * 18 : 0 }
}
