import QtQuick
import "../../.."
import "../../../components"

BarIsland {
    id: root
    islandId: "dock"
    islandVisible: Settings.dockEnabled
    reactive: false
    border.width: 0
    Accessible.name: "Dock — drag to move, click to customize"
    // The standard BarIsland supplies click-to-configure, live drag proxy,
    // cancellation and all twelve edge/zone targets. Never launch apps here.
    // A stable handle, not a miniature second dock. No child input handlers:
    // the owning BarIsland retains the entire click/drag hit target.
    Item {
        width: 32; height: 30
        WabiSabiBlackHole {
            anchors.centerIn: parent
            width: 32; height: 24
            diskColor: Theme.accent
            horizonColor: Theme.void_
        }
    }
}
