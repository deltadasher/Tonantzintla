pragma Singleton

import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.UPower
import ".."

QtObject {
    id: root

    // Quickshell's generated Bluetooth type metadata omits the model dependencies.
    // qmllint disable unresolved-type
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothAvailable: bluetoothAdapter !== null
    readonly property bool bluetoothEnabled: bluetoothAvailable && bluetoothAdapter.enabled
    readonly property var connectedDevices: Bluetooth.devices.values.filter(function(device) {
        return device.connected;
    })
    readonly property int bluetoothCount: connectedDevices.length
    readonly property string bluetoothLabel: !bluetoothAvailable ? "N/A"
        : !bluetoothEnabled ? "OFF"
        : bluetoothCount > 0 ? bluetoothCount.toString() : "ON"
    // qmllint enable unresolved-type

    readonly property var battery: UPower.displayDevice
    readonly property bool batteryAvailable: battery !== null && battery.ready
        && battery.isPresent && battery.isLaptopBattery
    readonly property int batteryPercent: batteryAvailable
        ? Math.round(battery.percentage <= 1 ? battery.percentage * 100 : battery.percentage) : 0
    readonly property bool batteryCharging: batteryAvailable
        && (battery.state === UPowerDeviceState.Charging
            || battery.state === UPowerDeviceState.PendingCharge)
    readonly property bool batteryLow: batteryAvailable && batteryPercent <= 20 && !batteryCharging
    readonly property int batterySecondsRemaining: !batteryAvailable ? 0
        : batteryCharging ? Math.max(0, battery.timeToFull)
        : Math.max(0, battery.timeToEmpty)
    readonly property string batteryTimeLabel: formatDuration(batterySecondsRemaining)
    readonly property int batteryHealthPercent: !batteryAvailable || !battery.healthSupported ? -1
        : Math.round(battery.healthPercentage <= 1
            ? battery.healthPercentage * 100 : battery.healthPercentage)
    readonly property real batteryEnergy: batteryAvailable
        ? Math.round(battery.energy * 10) / 10 : 0
    readonly property real batteryCapacity: batteryAvailable
        ? Math.round(battery.energyCapacity * 10) / 10 : 0
    readonly property real batteryRate: batteryAvailable
        ? Math.round(Math.abs(battery.changeRate) * 10) / 10 : 0
    readonly property string batteryModel: batteryAvailable && battery.model.length > 0
        ? battery.model : "BATTERY"

    property bool powerProfileAvailable: false
    property string powerProfile: "balanced"

    property int brightnessPercent: 0
    property bool brightnessAvailable: false
    readonly property bool brightnessActive: Settings.showBrightness && brightnessAvailable
    readonly property bool profileActive: ShellState.ephemerisVisible
        && ShellState.ephemerisTab === "battery"

    function toggleBluetooth() {
        if (bluetoothAvailable)
            bluetoothAdapter.enabled = !bluetoothAdapter.enabled;
    }

    function formatDuration(seconds) {
        if (!seconds || seconds <= 0)
            return batteryCharging ? "CALCULATING" : "UNKNOWN";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        return hours > 0 ? hours + "H " + minutes + "M" : minutes + "M";
    }

    function refreshBrightness() {
        if (!brightnessRead.running)
            brightnessRead.running = true;
    }

    function changeBrightness(delta) {
        if (!brightnessAvailable)
            return;
        Osd.show("brightness", Math.max(0, Math.min(100, brightnessPercent + delta)),
            "BRIGHTNESS", false);
        brightnessWrite.command = ["brightnessctl", "set",
            Math.abs(delta) + "%" + (delta >= 0 ? "+" : "-")];
        brightnessWrite.running = true;
        brightnessRefresh.restart();
    }

    function refreshPowerProfile() {
        if (!powerProfileRead.running)
            powerProfileRead.running = true;
    }

    function setPowerProfile(profile) {
        if (!powerProfileAvailable || powerProfileWrite.running)
            return;
        powerProfile = profile;
        powerProfileWrite.command = ["powerprofilesctl", "set", profile];
        powerProfileWrite.running = true;
        powerProfileRefresh.restart();
    }

    property Process brightnessRead: Process {
        command: ["brightnessctl", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/,([0-9]+)%,/);
                root.brightnessAvailable = match !== null;
                if (match)
                    root.brightnessPercent = parseInt(match[1]);
            }
        }
    }

    property Process brightnessWrite: Process {}

    property Process powerProfileRead: Process {
        command: ["powerprofilesctl", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const profile = text.trim();
                root.powerProfileAvailable = profile === "performance"
                    || profile === "balanced" || profile === "power-saver";
                if (root.powerProfileAvailable)
                    root.powerProfile = profile;
            }
        }
    }

    property Process powerProfileWrite: Process {}

    property Timer powerProfileRefresh: Timer {
        interval: 500
        onTriggered: root.refreshPowerProfile()
    }

    property Timer brightnessRefresh: Timer {
        interval: 140
        onTriggered: root.refreshBrightness()
    }

    property Timer pollTimer: Timer {
        interval: 8000
        running: root.brightnessActive || root.profileActive
        repeat: true
        onTriggered: {
            if (root.brightnessActive)
                root.refreshBrightness();
            if (root.profileActive)
                root.refreshPowerProfile();
        }
    }

    onBrightnessActiveChanged: if (brightnessActive) refreshBrightness()
    onProfileActiveChanged: if (profileActive) refreshPowerProfile()
}
