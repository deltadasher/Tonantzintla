import QtQuick
import "../.."
import "../../components/ClockNotation.js" as Notation

// Identical composition in the editor and live surface, scaled within its box.
// The host owns the shared minute clock; this face has no time acquisition.
Item {
    id: root
    property color accentColor: Theme.accent
    property color foregroundColor: Theme.moon
    property color mutedColor: Theme.muted
    objectName: "umbraClassicClock"
    property date dateTime: new Date()
    readonly property string timeText: Notation.time(dateTime, Settings.clock12h)
    readonly property real metricScale: Math.max(0, Math.min(width / 560, height / 240))
    Text {
        id: dateLabel
        objectName: "classicDate"
        width: parent.width
        height: 24 * root.metricScale
        verticalAlignment: Text.AlignVCenter
        text: Qt.formatDateTime(root.dateTime, "dddd, MMMM dd").toUpperCase()
        color: root.accentColor; font.family: Theme.fontMono
        font.pixelSize: 18 * root.metricScale; font.letterSpacing: 2 * root.metricScale
        elide: Text.ElideRight
    }
    Text {
        objectName: "classicTime"
        y: 36 * root.metricScale; width: parent.width; height: 156 * root.metricScale
        text: root.timeText
        color: root.foregroundColor; font.family: Theme.fontDisplay
        font.pixelSize: 126 * root.metricScale; font.weight: Font.Light
        font.letterSpacing: -5 * root.metricScale
        fontSizeMode: Text.Fit; minimumPixelSize: 1
    }
    Rectangle {
        objectName: "classicRule"
        y: 180 * root.metricScale; width: 42 * root.metricScale; height: 2 * root.metricScale
        color: root.accentColor
    }
}
