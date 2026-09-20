import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../.."
import "../../../../services"
import "../../../../components"
import "../shared" as Shared

Item {
    id: root
    property string activeTab: "wifi"
    property string pendingSsid: ""
    function focusPrimary() { refreshButton.forceActiveFocus(); }
    function submitPassword() {
        if (pendingSsid && NetState.connectWifi(pendingSsid, passwordInput.text, "")) {
            passwordInput.clear();
            pendingSsid = "";
        }
    }
    function activateNetwork(network) {
        if (NetState.busy) return;
        if (network.connected) NetState.disconnectWifi(network);
        else if (network.secure && !network.saved) {
            pendingSsid = network.ssid;
            passwordInput.clear();
            passwordInput.forceActiveFocus();
        } else NetState.connectWifi(network.ssid, "", network.uuid);
    }
    function advanced() { Quickshell.execDetached(["nm-connection-editor"]); }
    Component.onDestruction: { passwordInput.clear(); if (NetState.actionHelper === "bluetooth-pair.py" && NetState.busy) NetState.cancelAction(); }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                Text { text: "LINK ARRAY"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 24; font.bold: true }
                Text { text: NetState.connected ? NetState.label : "Not connected"; color: NetState.connected ? Theme.success : Theme.muted; font.family: Theme.fontText; font.pixelSize: 12 }
            }
            ActionButton {
                id: refreshButton
                text: "Scan"
                enabled: !NetState.busy && !NetState.loading
                onClicked: root.activeTab === "bluetooth" ? NetState.scanBluetooth() : root.activeTab === "wifi" ? NetState.scanWifi() : NetState.refresh()
            }
            ActionButton {
                visible: root.activeTab === "wifi" || root.activeTab === "bluetooth"
                text: root.activeTab === "wifi" ? (NetState.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off") : (DeviceState.bluetoothEnabled ? "Bluetooth on" : "Bluetooth off")
                selected: root.activeTab === "wifi" ? NetState.wifiEnabled : DeviceState.bluetoothEnabled
                enabled: !NetState.busy
                onClicked: root.activeTab === "wifi" ? NetState.toggleWifi() : NetState.toggleBluetooth()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: [{id:"wifi",label:"Wi-Fi"},{id:"bluetooth",label:"Bluetooth"},{id:"ethernet",label:"Ethernet"},{id:"vpn",label:"VPN"}]
                ActionButton {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.label
                    selected: root.activeTab === modelData.id
                    onClicked: { root.activeTab = modelData.id; root.pendingSsid = ""; passwordInput.clear(); }
                }
            }
        }
        Rectangle {
            visible: root.pendingSsid !== ""
            Layout.fillWidth: true
            implicitHeight: 68
            radius: 14; color: Theme.mantle
            RowLayout {
                anchors.fill: parent; anchors.margins: 12
                Text { Layout.preferredWidth: 140; text: root.pendingSsid; elide: Text.ElideRight; color: Theme.moon; font.family: Theme.fontText }
                TextInput {
                    id: passwordInput
                    Layout.fillWidth: true; Layout.preferredHeight: 36
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 14
                    Accessible.name: "Wi-Fi password"
                    Keys.onReturnPressed: root.submitPassword()
                    Keys.onEscapePressed: { clear(); root.pendingSsid = ""; }
                }
                ActionButton { text: "Connect"; enabled: !NetState.busy; onClicked: root.submitPassword() }
                ActionButton { text: "Cancel"; onClicked: { passwordInput.clear(); root.pendingSsid = ""; } }
            }
        }
        Rectangle {
            visible: NetState.promptKind !== ""
            Layout.fillWidth: true
            implicitHeight: pairingContent.implicitHeight + 24
            radius: 14; color: Theme.accentVeil
            ColumnLayout {
                id: pairingContent
                anchors.fill: parent; anchors.margins: 12
                Text { Layout.fillWidth: true; text: NetState.promptMessage; wrapMode: Text.WordWrap; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 15 }
                RowLayout {
                    TextInput {
                        id: pairingInput
                        visible: NetState.promptKind === "pin" || NetState.promptKind === "passkey"
                        Layout.fillWidth: true; Layout.preferredHeight: 32
                        color: Theme.moon; font.pixelSize: 18; font.family: Theme.fontMono
                        Accessible.name: "Bluetooth pairing code"
                        maximumLength: NetState.promptKind === "passkey" ? 6 : 16
                        Keys.onReturnPressed: { NetState.answerPrompt(text); clear(); }
                        onVisibleChanged: if (visible) { clear(); forceActiveFocus(); }
                    }
                    ActionButton {
                        visible: NetState.promptKind !== "display"
                        text: NetState.promptKind === "confirm" ? "Codes match" : "Submit"
                        onClicked: { NetState.answerPrompt(NetState.promptKind === "confirm" ? "yes" : pairingInput.text); pairingInput.clear(); }
                    }
                    ActionButton { text: "Cancel pairing"; onClicked: NetState.cancelAction() }
                }
            }
        }
        Shared.WifiRadar {
            visible: root.activeTab === "wifi"
            Layout.fillWidth: true; Layout.fillHeight: true
            enabled: !NetState.busy
            networks: NetState.wifiNetworks
            loading: NetState.loading
            radioEnabled: NetState.wifiEnabled
            onNetworkActivated: function(network) { root.activateNetwork(network); }
        }
        ListView {
            id: deviceList
            visible: root.activeTab !== "wifi"
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 8
            model: root.activeTab === "bluetooth" ? NetState.bluetoothDevices : root.activeTab === "vpn" ? NetState.vpnProfiles : NetState.ethernetDevices
            delegate: Rectangle {
                required property var modelData
                width: deviceList.width; height: 70
                radius: 14; color: modelData.connected ? Theme.accentVeil : Theme.mantle
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: modelData.name || modelData.connection || modelData.device; elide: Text.ElideRight; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 14 }
                        Text { text: modelData.connected ? "Connected" : modelData.paired ? "Paired" : root.activeTab === "vpn" ? "Saved profile" : "Available"; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 11 }
                    }
                    ActionButton {
                        text: modelData.connected ? "Disconnect" : root.activeTab === "bluetooth" && !modelData.paired ? "Pair" : "Connect"
                        pending: NetState.busy && NetState.pendingKey === (modelData.address || modelData.uuid || modelData.device)
                        enabled: !NetState.busy && (root.activeTab !== "vpn" || NetState.apiAvailable)
                        onClicked: {
                            if (root.activeTab === "bluetooth") NetState.bluetoothAction(modelData.address, modelData.connected, modelData.paired);
                            else if (root.activeTab === "vpn") NetState.vpnAction(modelData);
                            else NetState.ethernetAction(modelData.device, modelData.connected);
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                width: parent.width - 30
                visible: deviceList.count === 0
                text: NetState.loading ? "Checking devices…" : root.activeTab === "vpn" ? "No saved VPN profiles. Add or import one in Advanced settings." : "No devices found. Enable the radio and scan again."
                wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 13
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: NetState.statusMessage
                wrapMode: Text.WordWrap
                color: NetState.actionState === "failed" ? Theme.danger : NetState.busy ? Theme.accent : Theme.muted
                font.family: Theme.fontText; font.pixelSize: 12
                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }
            ActionButton { visible: NetState.busy; text: "Cancel"; enabled: NetState.actionState !== "cancelling"; onClicked: NetState.cancelAction() }
            ActionButton { text: "Advanced settings"; onClicked: root.advanced() }
        }
    }
}
