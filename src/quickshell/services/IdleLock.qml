pragma Singleton
import QtQuick
import ".."
import "../components"

QtObject {
    readonly property string status: watcher.status
    readonly property string error: watcher.error
    property IdleWatcher watcher: IdleWatcher {
        enabled: Settings.persistenceReady && Settings.idleLockEnabled
        seconds: Settings.idleLockMinutes * 60
        controlPath: Environment.controlPath
    }
}
