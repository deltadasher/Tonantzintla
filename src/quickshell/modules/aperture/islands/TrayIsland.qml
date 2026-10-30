import QtQuick
import Quickshell.Services.SystemTray
import "../../../components"
import "../../../services"
import "../../.."

BarIsland {
    id: root
    islandId: "tray"
    // Keep watching the tray even while its empty island occupies no space.
    islandVisible: tray.displayCount > 0

    TrayStrip { id: tray }
}
