import QtQuick
import "../.."
import "../../components/ClockNotation.js" as Notation
import "../../components/identity"
import "../../components/identity/LockStyles.js" as LockStyles

// Identical composition in the editor and live surface, scaled within its box.
// The host owns the shared minute clock; this face has no time acquisition.
Item {
    id: root
    property color accentColor: Theme.accent
    property color foregroundColor: Theme.moon
    property color mutedColor: Theme.muted
    objectName: "umbraClassicClock"
    property date dateTime: new Date()
    // An identity's clock and date roles (LockStyles.js); absent, the shell fonts.
    property var timeType: ({ families: [Theme.fontDisplay], weight: Font.Light, tracking: -.04 })
    property var dateType: ({ families: [Theme.fontMono], tracking: .11, caps: "upper", format: "dddd, MMMM dd" })
    readonly property string timeText: Notation.time(dateTime, Settings.clock12h)
    readonly property real metricScale: Math.max(0, Math.min(width / 560, height / 240))
    SceneLabel {
        id: dateLabel
        objectName: "classicDate"
        width: parent.width
        height: 24 * root.metricScale
        verticalAlignment: Text.AlignVCenter
        text: LockStyles.date(root.dateType, root.dateTime)
        type: root.dateType
        color: root.accentColor
        size: 18 * root.metricScale
        elide: Text.ElideRight
    }
    SceneLabel {
        objectName: "classicTime"
        y: 36 * root.metricScale; width: parent.width; height: 156 * root.metricScale
        text: root.timeText
        type: root.timeType
        color: root.foregroundColor
        size: 126 * root.metricScale
        fontSizeMode: Text.Fit; minimumPixelSize: 1
    }
    Rectangle {
        objectName: "classicRule"
        y: 180 * root.metricScale; width: 42 * root.metricScale; height: 2 * root.metricScale
        color: root.accentColor
    }
}
