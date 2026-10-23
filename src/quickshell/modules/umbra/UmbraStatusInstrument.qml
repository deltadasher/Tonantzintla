import QtQuick
import "../.."
import "../../services"

Item {
    id: root
    property string kind: "weather"
    property real textSize: 10
    readonly property bool available: kind === "battery" ? DeviceState.batteryAvailable
        : kind === "weather" ? Weather.available : Compositor.keyboardLayoutName.length > 0
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width,parent.height); height: width; radius: width/2
        visible: root.kind === "battery"
        readonly property color ink: DeviceState.batteryLow ? Theme.danger : Theme.cyan
        color: Qt.rgba(ink.r,ink.g,ink.b,.15)
    }
    Text {
        anchors.fill: parent
        text: root.kind === "battery" ? (DeviceState.batteryAvailable
                ? (DeviceState.batteryCharging ? "+" : DeviceState.batteryPercent + "%") : "No battery")
            : root.kind === "weather" ? (Weather.available
                ? Math.round(Number(Weather.current.temp || 0)) + Weather.unitSymbol + "  /  " + String(Weather.current.condition || "").toUpperCase()
                : "Weather unavailable")
            : (Compositor.keyboardLayoutName || "Keyboard layout unavailable") + "  ·  Enter to unlock"
        color: root.kind === "battery" ? (DeviceState.batteryLow ? Theme.danger : Theme.cyan) : Theme.muted
        font.family: Theme.fontMono; font.pixelSize: root.textSize
        font.weight: root.kind === "battery" ? Font.Bold : Font.Normal
        fontSizeMode: Text.Fit; minimumPixelSize: 6; elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: root.kind === "battery" ? Text.AlignHCenter : Text.AlignLeft
    }
}
