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
    property bool fallbackConnected: false
    property string fallbackLabel: ""
    property string fallbackKind: "NET"
    property string manager: "external"
    // Once the helper has answered, use its current kernel/NetworkManager
    // result as the authority. Quickshell's device graph can briefly retain a
    // stale disconnected object during a manager resync.
    property bool helperStateReady: false
    readonly property bool connected: helperStateReady
        ? fallbackConnected : connectedDevice !== null
    readonly property bool wifiEnabled: managerAvailable
        ? Networking.wifiEnabled
        : wifiNetworks.some(function(network) { return network.connected === true; })
    readonly property string label: helperStateReady
        ? (fallbackConnected && fallbackLabel.length ? fallbackLabel : "OFFLINE")
        : connectedNetwork && connectedNetwork.name ? connectedNetwork.name
            : connectedDevice && connectedDevice.name ? connectedDevice.name
                : "OFFLINE"
    readonly property string kind: helperStateReady
        ? fallbackKind : connectedDevice
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
        if (!managerAvailable) {
            statusMessage = "NETWORK IS MANAGED OUTSIDE TONANTZINTLA";
            refreshDelay.restart();
            return;
        }
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
        if (!managerAvailable) {
            statusMessage = "NETWORK IS MANAGED OUTSIDE TONANTZINTLA";
            refreshDelay.restart();
            return;
        }
        runAction(["nmcli", "device", "wifi", "rescan"], "SCANNING WI-FI…");
    }

    function connectWifi(ssid, password) {
        if (!managerAvailable) {
            statusMessage = "NETWORKMANAGER ACCESS IS UNAVAILABLE";
            return;
        }
        const command = ["nmcli", "device", "wifi", "connect", ssid];
        if (password && password.length > 0)
            command.push("password", password);
        runAction(command, "LINKING TO " + ssid.toUpperCase() + "…");
    }

    function disconnectWifi(ssid) {
        if (!managerAvailable) {
            statusMessage = "NETWORKMANAGER ACCESS IS UNAVAILABLE";
            return;
        }
        runAction(["nmcli", "connection", "down", "id", ssid],
            "DISCONNECTING " + ssid.toUpperCase() + "…");
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
        if (!managerAvailable) {
            statusMessage = "NETWORKMANAGER ACCESS IS UNAVAILABLE";
            return;
        }
        runAction(["nmcli", "device", connected ? "disconnect" : "connect", device],
            (connected ? "DISCONNECTING " : "CONNECTING ") + device.toUpperCase() + "…");
    }

    property Process stateProcess: Process {
        command: root.detailedActive
            ? ["python3", root.helperPath]
            : ["python3", root.helperPath, "--summary"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.managerAvailable = data.available === true;
                    root.wifiNetworks = data.wifi || [];
                    root.manager = data.manager || "external";
                    const activeWifi = root.wifiNetworks.find(function(network) {
                        return network.connected === true;
                    }) || null;
                    const activeEthernet = (data.ethernet || root.ethernetDevices).find(function(device) {
                        return device.connected === true;
                    }) || null;
                    root.fallbackConnected = activeWifi !== null || activeEthernet !== null;
                    root.fallbackConnected = data.connected === true || root.fallbackConnected;
                    root.fallbackLabel = data.label || (activeWifi ? activeWifi.ssid
                        : activeEthernet ? (activeEthernet.connection || activeEthernet.device) : "");
                    root.fallbackKind = data.kind || (activeWifi ? "WIFI"
                        : activeEthernet ? "LINK" : "NET");
                    if (data.summary !== true) {
                        root.bluetoothDevices = data.bluetooth || [];
                        root.ethernetDevices = data.ethernet || [];
                    }
                    root.helperStateReady = true;
                    root.statusMessage = "NETWORK UPDATED";
                } catch (error) {
                    root.managerAvailable = false;
                    root.helperStateReady = false;
                    root.statusMessage = "COULD NOT READ NETWORK STATE";
                    console.warn("[Tonantzintla/Network] State decode failed:", error);
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
        interval: root.detailedActive ? 10000 : 30000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    onDetailedActiveChanged: if (detailedActive) refreshDelay.restart()
    Component.onCompleted: refreshDelay.restart()
}
