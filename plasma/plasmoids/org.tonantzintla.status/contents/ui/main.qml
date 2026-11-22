import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.volume as PlasmaVolume
import org.kde.plasma.private.battery as PlasmaBattery

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    readonly property var sink: PlasmaVolume.PreferredDevice.sink
    readonly property int volPercent: sink ? Math.round((sink.volume / 65536.0) * 100) : 0
    readonly property bool volMuted: sink ? sink.muted : false
    readonly property color accentColor: Kirigami.Theme.focusColor
    function linChannel(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
    readonly property color accentFg: (0.2126 * linChannel(accentColor.r) + 0.7152 * linChannel(accentColor.g) + 0.0722 * linChannel(accentColor.b)) > 0.34 ? "#101016" : "#f8f7fc"
    readonly property color textFg: (0.2126 * linChannel(Kirigami.Theme.textColor.r) + 0.7152 * linChannel(Kirigami.Theme.textColor.g) + 0.0722 * linChannel(Kirigami.Theme.textColor.b)) > 0.34 ? "#101016" : "#f8f7fc"
    Layout.minimumWidth: pillsRow.implicitWidth + 8
    Layout.preferredWidth: pillsRow.implicitWidth + 8
    Layout.maximumWidth: pillsRow.implicitWidth + 8
    Layout.fillHeight: true

    PlasmaBattery.BatteryControlModel {
        id: batteryModel
    }

    Row {
        id: pillsRow
        anchors.centerIn: parent
        spacing: 6

        // Inverted accent Audio pill (Serpantinum signature)
        Rectangle {
            visible: root.sink !== null && root.sink !== undefined
            width: volLabel.implicitWidth + 18
            height: 24
            radius: 7
            color: root.volMuted ? Kirigami.Theme.alternateBackgroundColor : root.accentColor
            opacity: volMouse.containsMouse ? 0.90 : 1.0
            border.width: root.volMuted ? 1 : 0
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on opacity { NumberAnimation { duration: 100 } }
            Text {
                id: volLabel
                anchors.centerIn: parent
                text: root.volMuted ? "MUTE" : ("VOL " + root.volPercent + "%")
                color: root.volMuted ? Kirigami.Theme.disabledTextColor : root.accentFg
                font.family: "JetBrains Mono"
                font.pixelSize: 11
                font.weight: Font.Bold
            }
            MouseArea {
                id: volMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.sink) root.sink.muted = !root.sink.muted
                onWheel: function(wheel) {
                    if (!root.sink) return;
                    const delta = wheel.angleDelta.y > 0 ? 3277 : -3277;
                    root.sink.volume = Math.max(0, Math.min(98304, root.sink.volume + delta));
                }
            }
        }

        // Battery pill (shown on laptops)
        Rectangle {
            visible: batteryModel.hasBatteries
            width: batLabel.implicitWidth + 18
            height: 24
            radius: 7
            color: batteryModel.percent <= 20 && !batteryModel.pluggedIn ? Kirigami.Theme.negativeTextColor : (batteryModel.pluggedIn ? Kirigami.Theme.textColor : Kirigami.Theme.alternateBackgroundColor)
            border.width: batteryModel.pluggedIn || batteryModel.percent <= 20 ? 0 : 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
            Text {
                id: batLabel
                anchors.centerIn: parent
                text: (batteryModel.pluggedIn ? "⚡ " : "BAT ") + batteryModel.percent + "%"
                color: batteryModel.pluggedIn ? root.textFg : (batteryModel.percent <= 20 ? "#101016" : Kirigami.Theme.textColor)
                font.family: "JetBrains Mono"
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }
    }
}
