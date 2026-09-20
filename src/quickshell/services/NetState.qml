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
    property bool apiAvailable: false
    property var vpnProfiles: []
    readonly property bool busy: actionProcess.running
    property string pendingKey: ""
    property string actionState: "idle"
    property string promptKind: ""
    property string promptMessage: ""
    property string requestPayload: ""
    property bool structuredAction: false
    property string actionHelper: ""
    property bool receivedResult: false
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

    function runAction(command, message, key) {
        if (actionProcess.running)
            return;
        structuredAction = false;
        actionHelper = "";
        receivedResult = false;
        actionState = "pending";
        pendingKey = key || "";
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

    function requestAction(helper, data, message, key) {
        if (busy) return false;
        runAction(["python3", Environment.script(helper)], message, key);
        structuredAction = true;
        actionHelper = helper;
        requestPayload = JSON.stringify(data) + "\n";
        return true;
    }

    function connectWifi(ssid, password, uuid) {
        if (!apiAvailable) { statusMessage = "Network control unavailable. Open Advanced settings."; return false; }
        return requestAction("network-action.py", {action: "wifi-connect", ssid: ssid,
            password: password || "", uuid: uuid || ""}, "Connecting to " + ssid + "…", ssid);
    }

    function disconnectWifi(network) {
        if (!network.uuid) { statusMessage = "Connection identity is unavailable. Refresh or open Advanced settings."; return; }
        requestAction("network-action.py", {action: "disconnect", uuid: network.uuid},
            "Disconnecting " + network.ssid + "…", network.ssid);
    }

    function vpnAction(profile) {
        requestAction("network-action.py", {action: profile.connected ? "disconnect" : "vpn-connect", uuid: profile.uuid},
            (profile.connected ? "Disconnecting " : "Connecting ") + profile.name + "…", profile.uuid);
    }

    function answerPrompt(value) {
        if (busy && structuredAction) actionProcess.write(JSON.stringify({response: value}) + "\n");
    }

    function cancelAction() {
        if (!busy) return;
        actionState = "cancelling";
        statusMessage = "Cancelling…";
        promptKind = "";
        if (structuredAction) actionProcess.write('{"cancel":true}\n');
        else actionProcess.signal(15);
    }

    function scanBluetooth() {
        runAction(["bluetoothctl", "--timeout", "5", "scan", "on"],
            "SCANNING BLUETOOTH…");
    }

    function bluetoothAction(address, connected, paired) {
        const operation = connected ? "disconnect" : paired ? "connect" : "pair";
        if (operation === "pair") {
            requestAction("bluetooth-pair.py", {address: address}, "Pairing " + address + "…", address);
            return;
        }
        runAction(["bluetoothctl", "--timeout", "20", operation, address],
            operation.toUpperCase() + " " + address + "…", address);
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
                        root.apiAvailable = data.apiAvailable === true;
                        root.vpnProfiles = data.vpn || [];
                        root.bluetoothDevices = data.bluetooth || [];
                        root.ethernetDevices = data.ethernet || [];
                    }
                    root.helperStateReady = true;
                    if (root.actionState === "idle") root.statusMessage = "Network updated.";
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
        stdinEnabled: true
        onStarted: {
            if (root.structuredAction) {
                write(root.requestPayload);
                root.requestPayload = "";
            }
        }
        stdout: SplitParser {
            onRead: function(line) {
                if (!root.structuredAction) return;
                try {
                    const data = JSON.parse(line);
                    if (data.prompt !== undefined) {
                        root.promptKind = data.prompt;
                        root.promptMessage = data.message || "";
                    }
                    if (data.ok !== undefined) {
                        root.receivedResult = true;
                        root.actionState = data.ok ? "success" : "failed";
                        root.statusMessage = data.message;
                    }
                } catch (error) { /* Only structured status reaches the UI. */ }
            }
        }
        onExited: function(code, status) {
            root.requestPayload = "";
            root.actionHelper = "";
            root.promptKind = "";
            root.pendingKey = "";
            if (!root.receivedResult) {
                const cancelled = root.actionState === "cancelling";
                root.actionState = cancelled ? "cancelled" : code === 0 ? "success" : "failed";
                root.statusMessage = cancelled ? "Cancelled." : code === 0 ? "Action completed. Refreshing…"
                    : "Action failed. Check the device and try again.";
            }
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
