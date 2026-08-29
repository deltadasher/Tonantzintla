pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import ".."

QtObject {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var connectedDevice: {
        const device = devices.find(function(candidate) { return candidate.connected; });
        return device || null;
    }
    readonly property var connectedNetwork: {
        if (!connectedDevice || !connectedDevice.networks)
            return null;
        const networks = connectedDevice.networks.values;
        return networks.find(function(candidate) { return candidate.connected; }) || null;
    }
    readonly property bool connected: connectedDevice !== null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property string label: connectedNetwork && connectedNetwork.name
        ? connectedNetwork.name
        : connectedDevice && connectedDevice.name ? connectedDevice.name : "OFFLINE"
    readonly property string kind: connectedDevice
        ? (connectedDevice.type === DeviceType.Wifi ? "WIFI" : "LINK") : "NET"
    readonly property string helperPath: Environment.script("network-state.py")

    property bool managerAvailable: false
    property bool loading: false
    property var wifiNetworks: []
    property var bluetoothDevices: []
    property var ethernetDevices: []
    property string statusMessage: "READY"
    property string pendingAction: ""
    property bool refreshPending: false
    readonly property bool detailedActive: ShellState.ephemerisVisible
        && ShellState.ephemerisTab === "network"

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
        statusMessage = Networking.wifiEnabled ? "WI-FI ON" : "WI-FI OFF";
        refreshDelay.restart();
    }

    function toggleBluetooth() {
        DeviceState.toggleBluetooth();
        statusMessage = DeviceState.bluetoothEnabled
            ? "BLUETOOTH OFF" : "BLUETOOTH ON";
        refreshDelay.restart();
    }

    function refresh() {
        if (stateProcess.running) {
            refreshPending = true;
            return;
        }
        loading = true;
        stateProcess.running = true;
    }

    function runAction(command, message) {
        if (actionProcess.running)
            return;
        pendingAction = message;
        statusMessage = message;
        actionProcess.command = command;
        actionProcess.running = true;
    }

    function scanWifi() {
        runAction(["nmcli", "device", "wifi", "rescan"], "SCANNING WI-FI…");
    }

    function connectWifi(ssid, password) {
        const command = ["nmcli", "device", "wifi", "connect", ssid];
        if (password && password.length > 0)
            command.push("password", password);
        runAction(command, "LINKING TO " + ssid.toUpperCase() + "…");
    }

    function disconnectWifi(ssid) {
        runAction(["nmcli", "connection", "down", "id", ssid],
            "DISCONNECTING " + ssid.toUpperCase() + "…");
    }

    function forgetWifi(ssid) {
        runAction(["nmcli", "connection", "delete", "id", ssid],
            "FORGETTING " + ssid.toUpperCase() + "…");
    }

    function scanBluetooth() {
        runAction(["bluetoothctl", "--timeout", "5", "scan", "on"],
            "SCANNING BLUETOOTH…");
    }

    function bluetoothAction(address, connected, paired) {
        const operation = connected ? "disconnect" : paired ? "connect" : "pair";
        runAction(["bluetoothctl", "--timeout", "20", operation, address],
            operation.toUpperCase() + " " + address + "…");
    }

    function ethernetAction(device, connected) {
        runAction(["nmcli", "device", connected ? "disconnect" : "connect", device],
            (connected ? "DISCONNECTING " : "CONNECTING ") + device.toUpperCase() + "…");
    }

    property Process stateProcess: Process {
        command: ["python3", root.helperPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.managerAvailable = data.available === true;
                    root.wifiNetworks = data.wifi || [];
                    if (data.summary !== true) {
                        root.bluetoothDevices = data.bluetooth || [];
                        root.ethernetDevices = data.ethernet || [];
                    }
                    root.statusMessage = "NETWORK UPDATED";
                } catch (error) {
                    root.managerAvailable = false;
                    root.statusMessage = "COULD NOT READ NETWORK STATE";
                    console.warn("[Astralith/Network] State decode failed:", error);
                }
                root.loading = false;
            }
        }
        onRunningChanged: {
            if (!running && root.refreshPending) {
                root.refreshPending = false;
                root.refreshDelay.restart();
            }
        }
    }

    property Process actionProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.statusMessage = text.trim().split("\n").pop().toUpperCase();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.statusMessage = text.trim().split("\n").pop().toUpperCase();
            }
        }
        onRunningChanged: {
            if (!running)
                root.refreshDelay.restart();
        }
    }

    property Timer refreshDelay: Timer {
        interval: 900
        onTriggered: root.refresh()
    }

    property Timer pollTimer: Timer {
        interval: 10000
        running: root.detailedActive
        repeat: true
        onTriggered: root.refresh()
    }

    onDetailedActiveChanged: if (detailedActive) refreshDelay.restart()
}
