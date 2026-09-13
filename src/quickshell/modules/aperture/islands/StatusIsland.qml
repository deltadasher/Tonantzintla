import QtQuick
import "../../../components"
import "../../../services"
import "../../.."

BarIsland {
    id: root
    islandId: "status"
    readonly property bool isVertical: barWindow ? barWindow.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")
    islandVisible: root.isVertical
        || Environment.recording
        || Settings.showMicrophone
        || Settings.showBrightness
        || Settings.showBluetooth
        || (Settings.showBattery && DeviceState.batteryAvailable)
        || (!barWindow || barWindow.width >= 1080)
    reveal: barWindow ? barWindow.systemReveal : (typeof window !== "undefined" && window ? window.systemReveal : 1)

    StatusPill {
        visible: Environment.recording
        code: "REC"
        value: "LIVE"
        active: true
        warning: true
        accentColor: Theme.danger
        accessibleLabel: "Screen recording active"
        onActivated: root.toggleEphemeris("capture")
    }

    StatusPill {
        visible: Settings.showMicrophone && (root.isVertical ? (!barWindow || barWindow.height >= 920) : (!barWindow || barWindow.width >= 1180))
        code: Audio.inputMuted ? "MIC×" : "MIC"
        value: Audio.inputPercent + "%"
        active: !Audio.inputMuted
        warning: Audio.inputMuted
        accentColor: Theme.rose
        accessibleLabel: "Microphone " + value
        onActivated: root.toggleEphemeris("audio")
    }

    StatusPill {
        visible: Settings.showBrightness && DeviceState.brightnessAvailable
            && (root.isVertical ? (!barWindow || barWindow.height >= 980) : (!barWindow || barWindow.width >= 1360))
        code: "LUX"
        value: DeviceState.brightnessPercent + "%"
        accentColor: Theme.warning
        accessibleLabel: "Brightness " + value
        onScrolled: function(delta) {
            DeviceState.changeBrightness(delta > 0 ? 5 : -5);
        }
        onActivated: root.toggleEphemeris("settings")
    }

    StatusPill {
        visible: Settings.showBluetooth && DeviceState.bluetoothAvailable
            && (root.isVertical ? (!barWindow || barWindow.height >= 860) : (!barWindow || barWindow.width >= 1260))
        code: "BT"
        value: DeviceState.bluetoothLabel
        active: DeviceState.bluetoothEnabled
        accentColor: Theme.violet
        accessibleLabel: "Bluetooth " + value
        onActivated: root.toggleEphemeris("network")
    }

    StatusPill {
        visible: Settings.showBattery && DeviceState.batteryAvailable
        code: DeviceState.batteryCharging ? "PWR" : "BAT"
        value: DeviceState.batteryPercent + "%"
        active: !DeviceState.batteryLow
        warning: DeviceState.batteryLow
        accentColor: DeviceState.batteryCharging ? Theme.success : Theme.cyan
        accessibleLabel: "Battery " + value
        onActivated: root.toggleEphemeris("battery")
    }

    NetworkPill { visible: root.isVertical || (!barWindow || barWindow.width >= 1080); outputName: root.barWindow ? root.barWindow.outputName : "" }
}
