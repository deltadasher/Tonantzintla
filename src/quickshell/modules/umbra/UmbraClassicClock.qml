import QtQuick
import "../.."
import "../../components/ClockNotation.js" as Notation

// Identical composition in the editor and live surface, scaled within its box.
// The host owns the shared minute clock; this face has no time acquisition.
Item {
    id: root
    objectName: "umbraClassicClock"
    property date dateTime: new Date()
    readonly property string timeText: Notation.time(dateTime, Settings.clock12h)
    readonly property real metricScale: Math.max(0, Math.min(width / 560, height / 240))
    Text {
        objectName: "classicDate"
        width: parent.width
        text: Qt.formatDateTime(root.dateTime, "dddd, MMMM dd").toUpperCase()
        color: Theme.accent; font.family: Theme.fontMono
        font.pixelSize: 11 * root.metricScale; font.letterSpacing: 2 * root.metricScale
        elide: Text.ElideRight
    }
    Text {
        objectName: "classicTime"
        y: 23 * root.metricScale; width: parent.width; height: 156 * root.metricScale
        text: root.timeText
        color: Theme.moon; font.family: Theme.fontDisplay
        font.pixelSize: 126 * root.metricScale; font.weight: Font.Light
        font.letterSpacing: -5 * root.metricScale
        fontSizeMode: Text.Fit; minimumPixelSize: 1
    }
    Rectangle {
        objectName: "classicRule"
        y: 180 * root.metricScale; width: 42 * root.metricScale; height: 2 * root.metricScale
        color: Theme.accent
    }
}
