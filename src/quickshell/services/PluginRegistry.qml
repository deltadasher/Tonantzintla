pragma Singleton

import QtQuick
import ".."

QtObject {

    readonly property var entries: [
        { "id": "resonance", "code": "MED", "name": "Media",
            "detail": "Audio and video player controls", "enabled": Settings.showMedia,
            "available": Media.available, "status": Media.playerCount + (Media.playerCount === 1 ? " PLAYER" : " PLAYERS") },
        { "id": "parallax", "code": "WAL", "name": "Wallpaper",
            "detail": "Wallpaper browser and switcher", "enabled": true,
            "available": Environment.canSetWallpaper,
            "status": Environment.wallpapers.length + " WALLPAPERS" },
        { "id": "devices", "code": "DEV", "name": "Devices",
            "detail": "Bluetooth, brightness, battery, mic", "enabled": Settings.showBluetooth || Settings.showBrightness || Settings.showBattery || Settings.showMicrophone,
            "available": DeviceState.bluetoothAvailable || DeviceState.brightnessAvailable || DeviceState.batteryAvailable,
            "status": "BUILT-IN" },
        { "id": "telemetry", "code": "SYS", "name": "System stats",
            "detail": "CPU, memory, audio, and network", "enabled": Settings.showSystemStats,
            "available": true, "status": "ONLINE" },
        { "id": "relay", "code": "TRY", "name": "System tray",
            "detail": "Tray icons from running apps", "enabled": Settings.showTray,
            "available": true, "status": "ONLINE" },
        { "id": "transit", "code": "NTF", "name": "Notifications",
            "detail": "Popups, history, unread count, and DND", "enabled": true,
            "available": true, "status": Notifications.history.count + (Notifications.history.count === 1 ? " NOTIFICATION" : " NOTIFICATIONS") },
        { "id": "clipboard", "code": "CLP", "name": "Clipboard",
            "detail": "Searchable text and image history", "enabled": true,
            "available": Clipboard.available, "status": Clipboard.entries.length + (Clipboard.entries.length === 1 ? " CLIP" : " CLIPS") },
        { "id": "optics", "code": "CAP", "name": "Screenshots",
            "detail": "Screenshots, editing, and recording", "enabled": true,
            "available": Environment.canCaptureRegion,
            "status": Environment.recording ? "RECORDING"
                : Environment.canRecord ? "PHOTO + VIDEO" : Environment.canCaptureRegion ? "PHOTO" : "MISSING" },
        { "id": "quickactions", "code": "QCK", "name": "Quick actions",
            "detail": "Timers and performance stats",
            "enabled": Settings.quickActionsEnabled, "available": true,
            "status": Timekeeper.anyRunning ? Timekeeper.activeDisplay : "READY" }
    ]

    function toggle(id) {
        if (id === "resonance")
            Settings.showMedia = !Settings.showMedia;
        else if (id === "devices") {
            const enable = !(Settings.showBluetooth || Settings.showBrightness
                || Settings.showBattery || Settings.showMicrophone);
            Settings.showBluetooth = enable;
            Settings.showBrightness = enable;
            Settings.showBattery = enable;
            Settings.showMicrophone = enable;
        } else if (id === "telemetry")
            Settings.showSystemStats = !Settings.showSystemStats;
        else if (id === "relay")
            Settings.showTray = !Settings.showTray;
        else if (id === "quickactions") {
            Settings.quickActionsEnabled = !Settings.quickActionsEnabled;
            if (!Settings.quickActionsEnabled)
                ShellState.hideQuickActions();
        }
    }
}
