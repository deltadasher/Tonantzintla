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

    SystemReadout { visible: !root.isVertical; outputName: root.barWindow ? root.barWindow.outputName : "" }

    StatusPill {
        visible: root.isVertical && Settings.showSystemStats
        code: "CPU"
        value: SysStats.cpuPercent + "%"
        onActivated: root.toggleEphemeris("system")
    }

    StatusPill {
        visible: root.isVertical && Settings.showSystemStats
        code: "MEM"
        value: SysStats.memoryPercent + "%"
        onActivated: root.toggleEphemeris("system")
    }

    StatusPill {
        visible: root.isVertical && Settings.showSystemStats
        code: "GPU"
        value: SysStats.gpuTemperature > 0 ? SysStats.gpuTemperature + "°" : "—"
        onActivated: root.toggleEphemeris("system")
    }

    StatusPill {
        visible: root.isVertical && Settings.showSystemStats
        code: "DSK"
        value: SysStats.diskPercent + "%"
        onActivated: root.toggleEphemeris("system")
    }

    StatusPill {
        visible: root.isVertical && Settings.showAudio
        code: Audio.muted ? "MUT" : "VOL"
        value: Audio.percent + "%"
        warning: Audio.muted
        onActivated: root.toggleEphemeris("audio")
        onScrolled: function(delta) { Audio.change(delta > 0 ? 5 : -5); }
    }
}
