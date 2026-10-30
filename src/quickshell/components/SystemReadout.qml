import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../services"

Rectangle {
    id: root
    property bool compactContent: Settings.compact
    readonly property string faceName: Settings.barTelemetryFace
    readonly property var metricsModel: Settings.showSystemStats ? [
        { id: "cpu", code: "CPU" }, { id: "memory", code: "MEM" },
        { id: "gpu", code: "GPU" }, { id: "disk", code: "DISK" }
    ].filter(function(metric) { return Settings.barTelemetryMetrics.indexOf(metric.id) >= 0; }) : []
    function reading(id) {
        if(id === "cpu") return {value:SysStats.cpuPercent+"%",level:SysStats.cpuPercent/100};
        if(id === "memory") return {value:SysStats.memoryPercent+"%",level:SysStats.memoryPercent/100};
        if(id === "gpu") return {value:SysStats.gpuTemperature>0?SysStats.gpuTemperature+"°":"—",level:SysStats.gpuTemperature/100};
        return {value:SysStats.diskPercent+"%",level:SysStats.diskPercent/100};
    }
    property string outputName: ""
    property var anchorHost: null
    readonly property bool sourceActive: ShellState.ephemerisVisible
        && ShellState.ephemerisAnchorTarget === root
    implicitWidth: row.implicitWidth + 18
    implicitHeight: compactContent ? 34 : 38
    radius: 9
    color: "transparent"
    border.width: 0

    property bool tooltipSuppressed: false

    function openPanel(panel) {
        tooltipSuppressed = true;
        if (root.anchorHost) root.anchorHost.toggleEphemeris(panel, root);
        else ShellState.toggleEphemeris(panel, root.outputName);
    }

    HoverHandler {
        id: hover
        onHoveredChanged: if (!hovered) root.tooltipSuppressed = false
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: root.compactContent ? 8 : 12

        Repeater {
            model: root.metricsModel

            Item {
                id: statHitbox
                required property var modelData
                readonly property var metric: root.reading(modelData.id)
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Open System · " + modelData.code + " " + metric.value
                Accessible.onPressAction: root.openPanel("system")
                Keys.onReturnPressed: root.openPanel("system")
                Keys.onSpacePressed: root.openPanel("system")
                HoverHandler { id: statHitboxHover }
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: -3
                    anchors.rightMargin: -3
                    radius: Theme.radiusSmall
                    color: "transparent"
                    border.width: statHitbox.activeFocus ? 1 : 0
                    border.color: Theme.accent
                }
                ToolTip {
                    visible: statHitboxHover.hovered && !root.sourceActive && !root.tooltipSuppressed
                    delay: 500
                    text: statHitbox.Accessible.name
                    background: Rectangle { color: Theme.mantle; radius: Theme.radiusSmall; border.color: Theme.accentLine }
                    contentItem: Text { text: statHitbox.Accessible.name; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: Theme.textLabel }
                }
                Layout.preferredWidth: stat.implicitWidth
                Layout.preferredHeight: root.implicitHeight

                TelemetryReadoutFace {
                    id: stat
                    anchors.centerIn: parent
                    code: statHitbox.modelData.code
                    value: statHitbox.metric.value
                    level: statHitbox.metric.level
                    variant: root.faceName
                    compact: root.compactContent
                }
                TapHandler {
                    onTapped: root.openPanel("system")
                }
            }
        }

        Rectangle {
            visible: Settings.showAudio && Settings.showSystemStats
            Layout.preferredWidth: 1
            Layout.preferredHeight: 13
            color: Theme.barHairlineHover
        }

        Item {
            id: audioHitbox
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Open audio · " + (Audio.muted ? "Muted" : Audio.percent + "%")
            Accessible.onPressAction: root.openPanel("audio")
            Keys.onReturnPressed: root.openPanel("audio")
            Keys.onSpacePressed: root.openPanel("audio")
            HoverHandler { id: audioHitboxHover }
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -3
                anchors.rightMargin: -3
                radius: Theme.radiusSmall
                color: "transparent"
                border.width: audioHitbox.activeFocus ? 1 : 0
                border.color: Theme.accent
            }
            ToolTip {
                visible: audioHitboxHover.hovered && !root.sourceActive && !root.tooltipSuppressed
                delay: 500
                text: audioHitbox.Accessible.name
                background: Rectangle { color: Theme.mantle; radius: Theme.radiusSmall; border.color: Theme.accentLine }
                contentItem: Text { text: audioHitbox.Accessible.name; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: Theme.textLabel }
            }
            visible: Settings.showAudio
            Layout.preferredWidth: audioReadout.implicitWidth
            Layout.preferredHeight: root.implicitHeight

            RowLayout {
                id: audioReadout
                anchors.centerIn: parent
                spacing: 4
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Audio.muted ? "MUT" : "VOL"
                    color: Audio.muted ? Theme.warning : Theme.muted
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textCaption
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.45
                }
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Audio.percent + "%"
                    color: Theme.moon
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textLabel
                    font.weight: Font.DemiBold
                }
            }
            TapHandler {
                onTapped: root.openPanel("audio")
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onWheel: function(event) {
            Audio.change(event.angleDelta.y > 0 ? 5 : -5);
            event.accepted = true;
        }
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
}
