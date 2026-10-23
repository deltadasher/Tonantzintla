import QtQuick
import "../../../components"
import "../../../services"
import "../../.."

BarIsland {
    id: root
    islandId: "system_stats"
    readonly property bool isVertical: barWindow ? barWindow.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")
    islandVisible: (Settings.showSystemStats || Settings.showAudio)
        && (root.isVertical || !barWindow || barWindow.width >= 1480)
    reveal: barWindow ? barWindow.systemReveal : (typeof window !== "undefined" && window ? window.systemReveal : 1)

    SystemReadout {
        id: horizontalReadout
        visible: !root.isVertical
        outputName: root.barWindow ? root.barWindow.outputName : ""
        anchorHost: root
        compactContent: root.compactContent
    }

    Repeater {
        model: root.isVertical && Settings.showSystemStats ? [
            {id:"cpu",code:"CPU"}, {id:"memory",code:"MEM"},
            {id:"gpu",code:"GPU"}, {id:"disk",code:"DSK"}
        ].filter(function(metric) {return Settings.barTelemetryMetrics.indexOf(metric.id)>=0;}) : []
        Loader {
            id: metricLoader
            readonly property bool isVertical: root.isVertical
            required property var modelData
            readonly property var metric: horizontalReadout.reading(modelData.id)
            sourceComponent: Settings.barTelemetryFace === "numeric" ? numericFace : chartFace
            Component {
                id: numericFace
                StatusPill {
                    implicitWidth: root.compactContent ? 36 : 40
                    code: metricLoader.modelData.code; value: metricLoader.metric.value
                    onActivated: root.toggleEphemeris("system", metricLoader)
                }
            }
            Component {
                id: chartFace
                TelemetryReadoutFace {
                    code: metricLoader.modelData.code; value: metricLoader.metric.value
                    level: metricLoader.metric.level; variant: Settings.barTelemetryFace
                    compact: root.compactContent; vertical: true
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Open System · " + code + " " + value
                    Accessible.onPressAction: root.toggleEphemeris("system", metricLoader)
                    Keys.onReturnPressed: root.toggleEphemeris("system", metricLoader)
                    Keys.onSpacePressed: root.toggleEphemeris("system", metricLoader)
                    TapHandler { onTapped: root.toggleEphemeris("system", metricLoader) }
                    Rectangle {anchors.fill:parent;color:"transparent";border.width:parent.activeFocus?1:0;border.color:Theme.accent;radius:3}
                }
            }
        }
    }

    StatusPill {
        id: audioControl
        visible: root.isVertical && Settings.showAudio
        code: Audio.muted ? "MUT" : "VOL"
        value: Audio.percent + "%"
        warning: Audio.muted
        onActivated: root.toggleEphemeris("audio", audioControl)
        onScrolled: function(delta) { Audio.change(delta > 0 ? 5 : -5); }
    }
}
