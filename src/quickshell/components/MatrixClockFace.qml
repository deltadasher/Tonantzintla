import QtQuick
import ".."

// Static dot geometry. Time is supplied by the owning island's existing clock;
// no blink, animation, canvas repaint loop or second clock service.
Item {
    id: root
    objectName: "matrixClock"
    required property date dateTime
    property bool vertical: false
    property bool compact: false
    readonly property string timeText: Qt.formatDateTime(dateTime,
        vertical ? "HH:mm" : Settings.clock12h ? (Settings.showSeconds ? "hh:mm:ss AP" : "hh:mm AP")
        : Settings.showSeconds ? "HH:mm:ss" : "HH:mm").split(" ")[0]
    readonly property string periodText: Settings.clock12h && !vertical ? Qt.formatDateTime(dateTime, "AP") : ""
    readonly property real pitch: vertical ? 2.2 : compact ? 2.4 : 3
    readonly property var lines: vertical ? timeText.split(":") : [timeText]
    // Explicit width avoids a centered child feeding its old x back into the
    // Column's implicit size after a horizontal-to-vertical orientation change.
    implicitWidth: Math.max((vertical ? 2 : timeText.length) * pitch * 3.7 - pitch,
                            caption.visible ? caption.implicitWidth : 0)
    implicitHeight: contents.implicitHeight

    function glyph(character) {
        switch (character) {
        case "0": return "111101101101111";
        case "1": return "010110010010111";
        case "2": return "111001111100111";
        case "3": return "111001111001111";
        case "4": return "101101111001001";
        case "5": return "111100111001111";
        case "6": return "111100111101111";
        case "7": return "111001010010010";
        case "8": return "111101111101111";
        case "9": return "111101111001111";
        case ":": return "000010000010000";
        default: return "000000000000000";
        }
    }

    Column {
        id: contents
        width: parent.width
        spacing: root.vertical ? 3 : 1
        Repeater {
            model: root.lines
            Row {
                id: line
                required property string modelData
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.pitch
                Repeater {
                    model: line.modelData.length
                    Grid {
                        id: character
                        required property int index
                        readonly property string pattern: root.glyph(line.modelData[index])
                        columns: 3
                        spacing: root.pitch * 0.3
                        Repeater {
                            model: 15
                            Rectangle {
                                required property int index
                                width: root.pitch * 0.7; height: width; radius: width / 2
                                color: character.pattern[index] === "1" ? Theme.moon : Theme.muted
                                opacity: character.pattern[index] === "1" ? 1 : 0.13
                            }
                        }
                    }
                }
            }
        }
        Text {
            id: caption
            visible: root.periodText !== "" || (Settings.showDate && !root.vertical)
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.periodText + (Settings.showDate && !root.vertical ? (root.periodText ? " · " : "") + Qt.formatDateTime(root.dateTime, Settings.dateFormat) : "")
            font.family: Theme.fontMono; font.pixelSize: 10
            color: Theme.muted
        }
    }
}
