import QtQuick
import Quickshell.Services.SystemTray
import "../../../components"
import "../../../services"
import "../../.."

BarIsland {
    id: root
    islandId: "tray"
    // Placement in Bar Studio is the visibility switch for the tray.
    // A global toggle could leave a valid tray slot at zero width.
    islandVisible: true

    TrayStrip { visible: true }
}
