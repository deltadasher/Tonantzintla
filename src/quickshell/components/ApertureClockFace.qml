import QtQuick
import QtQuick.Layouts
import ".."

// One face is mounted at a time. The owning island supplies its existing clock.
Loader {
    id: root
    required property date dateTime
    property string variant: "classic"
    property bool vertical: false
    property bool compact: false
    sourceComponent: variant === "compact" ? compactFace : variant === "stacked" ? stackedFace : classicFace

    Component {
        id: classicFace
        ColumnLayout {
            spacing: root.vertical ? 1 : -2
            Text {
                text: Qt.formatDateTime(root.dateTime, root.vertical ? "HH\nmm" : Settings.clockFormat)
                color: Theme.moon; font.family: Theme.fontDisplay
                font.pixelSize: root.vertical ? 13 : root.compact ? 16 : 20
                font.weight: Font.Bold; font.letterSpacing: root.vertical ? 0.4 : 0.8
                horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter
                lineHeight: root.vertical ? 0.88 : 1
            }
            Text {
                visible: Settings.showDate && !root.vertical
                text: Qt.formatDateTime(root.dateTime, Settings.dateFormat)
                color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: Theme.textMicro
                font.letterSpacing: 1.1; Layout.alignment: Qt.AlignHCenter
            }
            Rectangle {
                visible: !root.compact && !root.vertical
                Layout.preferredWidth: 92; Layout.preferredHeight: 1; color: Theme.barHairlineHover
                Rectangle {
                    width: parent.width * root.dateTime.getSeconds() / 59; height: 1; color: Theme.accent
                    Behavior on width { NumberAnimation { duration: Theme.duration(240); easing.type: Easing.OutCubic } }
                }
            }
        }
    }
    Component {
        id: compactFace
        Text {
            text: Qt.formatDateTime(root.dateTime, root.vertical ? "HH\nmm" : Settings.clockFormat)
            color: Theme.moon; font.family: Theme.fontMono
            font.pixelSize: root.vertical ? 12 : root.compact ? 12 : 14
            font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter
        }
    }
    Component {
        id: stackedFace
        Column {
            spacing: 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.dateTime, Settings.clock12h ? "hh" : "HH")
                color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: root.compact ? 12 : 14; font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.dateTime, Settings.showSeconds && !root.vertical ? "mm:ss" : "mm") + (Settings.clock12h && !root.vertical ? " " + Qt.formatDateTime(root.dateTime, "AP") : "")
                color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: root.compact ? 10 : 12
            }
        }
    }
}
