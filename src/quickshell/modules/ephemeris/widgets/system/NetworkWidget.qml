import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../.."
import "../../../../services"
import "../shared" as Shared

Item {
    id: root

    property string activeTab: "wifi"
    property string pendingSsid: ""
    property string wifiPassword: ""

    function submitPassword() {
        if (pendingSsid.length === 0)
            return;
        NetState.connectWifi(pendingSsid, wifiPassword);
        pendingSsid = "";
        wifiPassword = "";
    }

    function activateNetwork(network) {
        if (network.connected) {
            NetState.disconnectWifi(network.ssid);
        } else if (network.secure && !network.saved) {
            pendingSsid = network.ssid;
            wifiPassword = "";
            Qt.callLater(function() { passwordInput.forceActiveFocus(); });
        } else {
            NetState.connectWifi(network.ssid, "");
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: "NETWORK"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 24; font.weight: Font.Bold }
                Text {
                    text: NetState.connected ? NetState.kind + " // " + NetState.label : "NOT CONNECTED"
                    color: NetState.connected ? Theme.success : Theme.warning
                    font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.DemiBold
                }
            }

            Rectangle {
                implicitWidth: 104; implicitHeight: 34; radius: 11
                color: scanPointer.containsMouse ? Theme.accent : Theme.elevated
                Text {
                    anchors.centerIn: parent
                    text: NetState.loading ? "SCANNING…" : "REFRESH"
                    color: scanPointer.containsMouse ? Theme.void_ : NetState.loading ? Theme.warning : Theme.moon
                    font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold
                }
                MouseArea {
                    id: scanPointer
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    enabled: !NetState.loading
                    onClicked: root.activeTab === "bluetooth" ? NetState.scanBluetooth()
                        : root.activeTab === "wifi" ? NetState.scanWifi() : NetState.refresh()
                }
            }

            Rectangle {
                id: radioButton
                implicitWidth: radioLabel.implicitWidth + 34; implicitHeight: 34; radius: 11
                readonly property bool radioOn: root.activeTab === "bluetooth"
                    ? DeviceState.bluetoothEnabled : root.activeTab === "wifi"
                        ? NetState.wifiEnabled : NetState.connected
                color: radioOn ? Theme.accent : Theme.elevated
                RowLayout {
                    anchors.centerIn: parent; spacing: 7
                    Rectangle { Layout.preferredWidth: 7; Layout.preferredHeight: 7; radius: 4; color: radioButton.radioOn ? Theme.success : Theme.danger }
                    Text {
                        id: radioLabel
                        text: root.activeTab === "bluetooth" ? "BLUETOOTH"
                            : root.activeTab === "wifi" ? "WI-FI" : "ETHERNET"
                        color: radioButton.radioOn ? Theme.void_ : Theme.moon
                        font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    enabled: root.activeTab !== "ethernet"
                    onClicked: root.activeTab === "bluetooth"
                        ? NetState.toggleBluetooth() : NetState.toggleWifi()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 7
            Repeater {
                model: [
                    { "id": "wifi", "label": "WI-FI", "count": NetState.wifiNetworks.length },
                    { "id": "bluetooth", "label": "BLUETOOTH", "count": NetState.bluetoothDevices.length },
                    { "id": "ethernet", "label": "ETHERNET", "count": NetState.ethernetDevices.length }
                ]
                Rectangle {
                    id: tabButton
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 12
                    readonly property bool selected: root.activeTab === modelData.id
                    color: selected ? Theme.accent : tabPointer.containsMouse ? Theme.elevated : "transparent"
                    RowLayout {
                        anchors.centerIn: parent; spacing: 8
                        Text { text: tabButton.modelData.label; color: tabButton.selected ? Theme.void_ : Theme.muted; font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Bold }
                        Rectangle {
                            implicitWidth: 24; implicitHeight: 22; radius: 8
                            color: tabButton.selected ? Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.18) : Theme.elevated
                            Text { anchors.centerIn: parent; text: tabButton.modelData.count; color: tabButton.selected ? Theme.void_ : Theme.moon; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold }
                        }
                    }
                    MouseArea {
                        id: tabPointer
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activeTab = tabButton.modelData.id;
                            root.pendingSsid = "";
                            root.wifiPassword = "";
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.pendingSsid.length > 0 ? 64 : 0
            visible: height > 0
            radius: Theme.radiusMedium
            color: Theme.mantle
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Settings.motion ? Theme.motionNormal : 0; easing.type: Easing.OutCubic } }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 13; anchors.rightMargin: 10; spacing: 9
                ColumnLayout {
                    Layout.preferredWidth: 150; spacing: 1
                    Text { text: "PASSWORD REQUIRED"; color: Theme.accent; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold }
                    Text { Layout.fillWidth: true; text: root.pendingSsid; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 11
                    color: passwordInput.activeFocus ? Theme.accentVeil : Theme.elevated
                    TextInput {
                        id: passwordInput
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.wifiPassword
                        onTextChanged: root.wifiPassword = text
                        echoMode: TextInput.Password
                        color: Theme.moon; selectionColor: Theme.accent; selectedTextColor: Theme.void_
                        font.family: Theme.fontText; font.pixelSize: 11
                        Keys.onReturnPressed: root.submitPassword()
                        Keys.onEscapePressed: { root.pendingSsid = ""; root.wifiPassword = ""; }
                    }
                    Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; visible: passwordInput.text.length === 0 && !passwordInput.activeFocus; text: "NETWORK PASSWORD"; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 10 }
                }
                Rectangle {
                    Layout.preferredWidth: 78; Layout.preferredHeight: 38; radius: 11
                    color: connectPointer.containsMouse ? Theme.cyan : Theme.accent
                    Text { anchors.centerIn: parent; text: "CONNECT"; color: Theme.void_; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold }
                    MouseArea { id: connectPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.submitPassword() }
                }
            }
        }

        Shared.WifiRadar {
            visible: root.activeTab === "wifi"
            Layout.fillWidth: true
            Layout.fillHeight: true
            networks: NetState.wifiNetworks
            loading: NetState.loading
            radioEnabled: NetState.wifiEnabled
            onNetworkActivated: function(network) { root.activateNetwork(network); }
        }

        ListView {
            id: bluetoothList
            visible: root.activeTab === "bluetooth"
            Layout.fillWidth: true; Layout.fillHeight: true
            model: NetState.bluetoothDevices; spacing: 7; clip: true
            delegate: Rectangle {
                id: bluetoothRow
                required property var modelData
                width: bluetoothList.width; height: 68; radius: Theme.radiusMedium
                color: modelData.connected ? Theme.accentVeil : bluetoothHover.hovered ? Theme.elevated : Theme.mantle
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 13; anchors.rightMargin: 10; spacing: 11
                    Rectangle { Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 13; color: Qt.rgba(Theme.violet.r, Theme.violet.g, Theme.violet.b, 0.20); Text { anchors.centerIn: parent; text: "BT"; color: Theme.violet; font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Bold } }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { Layout.fillWidth: true; text: bluetoothRow.modelData.name; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        Text { text: bluetoothRow.modelData.address + (bluetoothRow.modelData.paired ? " // PAIRED" : " // DISCOVERED"); color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 10 }
                    }
                    Rectangle {
                        Layout.preferredWidth: 92; Layout.preferredHeight: 34; radius: 11
                        color: bluetoothRow.modelData.connected ? Theme.danger : bluetoothButton.containsMouse ? Theme.cyan : Theme.accent
                        Text { anchors.centerIn: parent; text: bluetoothRow.modelData.connected ? "DISCONNECT" : bluetoothRow.modelData.paired ? "CONNECT" : "PAIR"; color: Theme.void_; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold }
                        MouseArea { id: bluetoothButton; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NetState.bluetoothAction(bluetoothRow.modelData.address, bluetoothRow.modelData.connected, bluetoothRow.modelData.paired) }
                    }
                }
                HoverHandler { id: bluetoothHover }
            }
        }

        ListView {
            id: ethernetList
            visible: root.activeTab === "ethernet"
            Layout.fillWidth: true; Layout.fillHeight: true
            model: NetState.ethernetDevices; spacing: 7; clip: true
            delegate: Rectangle {
                id: ethernetRow
                required property var modelData
                width: ethernetList.width; height: 68; radius: Theme.radiusMedium
                color: modelData.connected ? Theme.accentVeil : Theme.mantle
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 13; anchors.rightMargin: 10; spacing: 11
                    Rectangle { Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 13; color: Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.18); Text { anchors.centerIn: parent; text: "LAN"; color: Theme.cyan; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold } }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { Layout.fillWidth: true; text: ethernetRow.modelData.connection || ethernetRow.modelData.device; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        Text { text: ethernetRow.modelData.device + " // " + ethernetRow.modelData.state.toUpperCase(); color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 10 }
                    }
                    Rectangle {
                        Layout.preferredWidth: 92; Layout.preferredHeight: 34; radius: 11
                        color: ethernetRow.modelData.connected ? Theme.danger : ethernetButton.containsMouse ? Theme.cyan : Theme.accent
                        Text { anchors.centerIn: parent; text: ethernetRow.modelData.connected ? "DISCONNECT" : "CONNECT"; color: Theme.void_; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold }
                        MouseArea { id: ethernetButton; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NetState.ethernetAction(ethernetRow.modelData.device, ethernetRow.modelData.connected) }
                    }
                }
            }
        }

        Text {
            visible: (root.activeTab === "bluetooth" && bluetoothList.count === 0)
                || (root.activeTab === "ethernet" && ethernetList.count === 0)
            Layout.fillWidth: true; Layout.fillHeight: true
            text: NetState.loading ? "SCANNING…"
                : root.activeTab === "bluetooth" && !DeviceState.bluetoothEnabled ? "BLUETOOTH IS OFF"
                : "NO DEVICES DETECTED"
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 11; font.letterSpacing: 0.8
        }

        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: NetState.statusMessage; visible: text.length > 0; color: text.indexOf("FAIL") >= 0 || text.indexOf("COULD NOT") >= 0 ? Theme.danger : Theme.muted; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Rectangle {
                implicitWidth: 142; implicitHeight: 34; radius: 11
                color: advancedPointer.containsMouse ? Theme.cyan : Theme.elevated
                Text { anchors.centerIn: parent; text: "ADVANCED SETTINGS"; color: advancedPointer.containsMouse ? Theme.void_ : Theme.moon; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold }
                MouseArea { id: advancedPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { ShellState.closeEphemeris(); Quickshell.execDetached(["nm-connection-editor"]); } }
            }
        }
    }
}
