import QtQuick
import "../../../components"
import "../../../services"
import "../../.."

BarIsland {
    id: root
    islandId: "volume"
    islandVisible: Settings.showAudio
    reveal: barWindow ? barWindow.systemReveal : 1

    StatusPill {
        code: Audio.muted ? "MUT" : "VOL"
        value: Audio.percent + "%"
        warning: Audio.muted
        active: !Audio.muted
        accessibleLabel: Audio.muted ? "Volume muted" : "Volume " + Audio.percent + "%"
        onActivated: root.toggleEphemeris("audio")
        onScrolled: function(delta) { Audio.change(delta > 0 ? 5 : -5); }
    }
}
