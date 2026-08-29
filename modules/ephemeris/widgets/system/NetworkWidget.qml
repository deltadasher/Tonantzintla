import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../.."
import "../../../../services"

Item {
    id: root

    property string activeTab: "wifi"
    property string pendingSsid: ""
    property string wifiPassword: ""
    readonly property var activeWifi: NetState.wifiNetworks.find(function(network) {
        return network.connected === true;
    }) || null

    function submitPassword() {
        if (pendingSsid.length === 0)
            return;
        NetState.connectWifi(pendingSsid, wifiPassword);
        pendingSsid = "";
        wifiPassword = "";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
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
                border.width: 0
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
                    onClicked: {
                        if (root.activeTab === "bluetooth")
                            NetState.scanBluetooth();
                        else if (root.activeTab === "wifi")
                            NetState.scanWifi();
                        else
                            NetState.refresh();
                    }
                }
            }

            Rectangle {
                implicitWidth: radioLabel.implicitWidth + 32; implicitHeight: 34; radius: 11
                readonly property bool radioOn: root.activeTab === "bluetooth"
                    ? DeviceState.bluetoothEnabled : root.activeTab === "wifi" ? NetState.wifiEnabled : NetState.connected
                color: radioOn ? Theme.accent : Theme.elevated
                border.width: 0
                RowLayout {
                    anchors.centerIn: parent; spacing: 7
                    Rectangle { Layout.preferredWidth: 7; Layout.preferredHeight: 7; radius: 4; color: parent.parent.radioOn ? Theme.success : Theme.danger }
                    Text {
                        id: radioLabel
                        text: root.activeTab === "bluetooth" ? "BLUETOOTH"
                            : root.activeTab === "wifi" ? "WI-FI" : "ETHERNET"
                        color: parent.parent.radioOn ? Theme.void_ : Theme.moon; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    enabled: root.activeTab !== "ethernet"
                    onClicked: {
                        if (root.activeTab === "bluetooth")
                            NetState.toggleBluetooth();
                        else
                            NetState.toggleWifi();
                    }
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
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 12
                    readonly property bool selected: root.activeTab === modelData.id
                    color: selected ? Theme.accent : tabPointer.containsMouse ? Theme.elevated : "transparent"
                    border.width: 0
                    RowLayout {
                        anchors.centerIn: parent; spacing: 8
                        Text { text: modelData.label; color: parent.parent.selected ? Theme.void_ : Theme.muted; font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.Bold }
                        Rectangle { implicitWidth: 24; implicitHeight: 22; radius: 8; color: parent.parent.selected ? Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.18) : Theme.elevated; Text { anchors.centerIn: parent; text: modelData.count; color: parent.parent.parent.selected ? Theme.void_ : Theme.moon; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold } }
                    }
                    MouseArea {
                        id: tabPointer
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activeTab = modelData.id;
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
            radius: Theme.radiusMedium; color: Theme.mantle
            border.width: 0
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.motionNormal; easing.type: Easing.OutCubic } }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 13; anchors.rightMargin: 10; spacing: 9
                ColumnLayout {
                    Layout.preferredWidth: 150; spacing: 1
                    Text { text: "SECURED"; color: Theme.accent; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold }
                    Text { Layout.fillWidth: true; text: root.pendingSsid; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 11
                    color: passwordInput.activeFocus ? Theme.accentVeil : Theme.elevated; border.width: 0
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
                    border.width: 0
                    Text { anchors.centerIn: parent; text: "CONNECT"; color: Theme.void_; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold }
                    MouseArea { id: connectPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.submitPassword() }
                }
            }
        }

        RowLayout {
            visible: root.activeTab === "wifi"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 244
                Layout.fillHeight: true
                radius: 24
                color: Qt.rgba(Theme.elevated.r, Theme.elevated.g, Theme.elevated.b, 0.86)
                border.width: 0
                clip: true

                Rectangle {
                    width: 210
                    height: 210
                    radius: 105
                    x: -72
                    y: -84
                    color: Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.055)
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: "NETWORK"
                            color: Theme.moon
                            font.family: Theme.fontDisplay
                            font.pixelSize: 17
                            font.weight: Font.Bold
                        }
                        Text {
                            text: NetState.connected ? "PASSWORD REQUIRED" : "LOADING FORECAST"
                            color: NetState.connected ? Theme.success : Theme.warning
                            font.family: Theme.fontText
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }

                    Item {
                        id: radar
                        Layout.fillWidth: true
                        Layout.preferredHeight: 224

                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                anchors.centerIn: parent
                                width: 54 + index * 42
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.width: 0
                                border.color: Qt.rgba(Theme.cyan.r, Theme.cyan.g,
                                    Theme.cyan.b, 0.16 + index * 0.055)
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 74
                            height: 74
                            radius: 37
                            color: Theme.accentVeil
                            border.width: 0
                            Column {
                                anchors.centerIn: parent
                                spacing: -2
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.activeWifi ? root.activeWifi.signal + "%" : "—"
                                    color: Theme.moon
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: 24
                                    font.weight: Font.Bold
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "SIGNAL"
                                    color: Theme.cyan
                                    font.family: Theme.fontText
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Item {
                            anchors.centerIn: parent
                            width: 190
                            height: 190
                            Rectangle {
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 7
                                height: 7
                                radius: 4
                                color: Theme.moon
                            }
                            NumberAnimation on rotation {
                                from: 0; to: 360; duration: 6800
                                loops: Animation.Infinite
                                running: Settings.motion && root.visible
                            }
                        }

                        Repeater {
                            model: Math.min(8, NetState.wifiNetworks.length)
                            Rectangle {
                                required property int index
                                readonly property real angle: index * Math.PI * 0.77
                                readonly property real orbit: 52 + (index % 3) * 22
                                x: radar.width / 2 + Math.cos(angle) * orbit - width / 2
                                y: radar.height / 2 + Math.sin(angle) * orbit - height / 2
                                width: index === 0 ? 8 : 5
                                height: width
                                radius: width / 2
                                color: index === 0 ? Theme.success : Theme.cyan
                                opacity: 0.45 + (index % 3) * 0.2
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: NetState.connected ? NetState.label : "NOT CONNECTED"
                        color: Theme.moon
                        font.family: Theme.fontText
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: NetState.wifiNetworks.length + " NOTIFICATIONS"
                        color: Theme.muted
                        font.family: Theme.fontText
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            ListView {
                id: wifiList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: NetState.wifiNetworks
                spacing: 7
                clip: true

                delegate: Rectangle {
                    id: wifiRow
                    required property var modelData
                    width: wifiList.width
                    height: 72
                    radius: 18
                    color: modelData.connected ? Theme.elevated
                        : wifiHover.hovered ? Theme.elevated : Theme.mantle
                    border.width: 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 13
                        anchors.rightMargin: 10
                        spacing: 11

                        Item {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 38
                            Repeater {
                                model: 3
                                Rectangle {
                                    required property int index
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 7
                                    x: 5 + index * 10
                                    width: 6
                                    height: 9 + index * 8
                                    radius: 3
                                    color: wifiRow.modelData.signal >= (index + 1) * 25
                                        ? Theme.cyan : Theme.line
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: wifiRow.modelData.ssid
                                    color: Theme.moon
                                    font.family: Theme.fontText
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: wifiRow.modelData.saved
                                    text: "SAVED"
                                    color: Theme.violet
                                    font.family: Theme.fontText
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                            }
                            Text {
                                text: wifiRow.modelData.security + "  ·  "
                                    + wifiRow.modelData.frequency + " MHz  ·  "
                                    + wifiRow.modelData.signal + "%"
                                color: Theme.muted
                                font.family: Theme.fontText
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 94
                            Layout.preferredHeight: 36
                            radius: 12
                            color: wifiRow.modelData.connected
                                ? Theme.danger
                                : wifiButton.containsMouse ? Theme.cyan : Theme.accent
                            border.width: 0
                            Text {
                                anchors.centerIn: parent
                                text: wifiRow.modelData.connected ? "RELEASE" : "LINK"
                                color: Theme.void_
                                font.family: Theme.fontText
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                id: wifiButton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (wifiRow.modelData.connected) {
                                        NetState.disconnectWifi(wifiRow.modelData.ssid);
                                    } else if (wifiRow.modelData.secure && !wifiRow.modelData.saved) {
                                        root.pendingSsid = wifiRow.modelData.ssid;
                                        root.wifiPassword = "";
                                        Qt.callLater(function() { passwordInput.forceActiveFocus(); });
                                    } else {
                                        NetState.connectWifi(wifiRow.modelData.ssid, "");
                                    }
                                }
                            }
                        }
                    }
                    HoverHandler { id: wifiHover }
                }

                Text {
                    anchors.centerIn: parent
                    visible: wifiList.count === 0
                    text: NetState.loading ? "LOADING FORECAST…"
                        : !NetState.wifiEnabled ? "WI-FI IS OFF"
                        : "NO NETWORKS FOUND"
                    color: Theme.muted
                    font.family: Theme.fontText
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
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
                border.width: 0
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
                        border.width: 0
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
                border.width: 0
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 13; anchors.rightMargin: 10; spacing: 11
                    Rectangle { Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 13; color: Theme.elevated; Text { anchors.centerIn: parent; text: "ETH"; color: Theme.cyan; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold } }
                    ColumnLayout { Layout.fillWidth: true; spacing: 2; Text { text: ethernetRow.modelData.device; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.DemiBold } Text { text: (ethernetRow.modelData.connection || "NO PROFILE") + " // " + ethernetRow.modelData.state.toUpperCase(); color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 10 } }
                    Rectangle {
                        Layout.preferredWidth: 92; Layout.preferredHeight: 34; radius: 11; color: ethernetRow.modelData.connected ? Theme.danger : ethernetButton.containsMouse ? Theme.cyan : Theme.accent; border.width: 0
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
                : root.activeTab === "wifi" && !NetState.wifiEnabled ? "WI-FI IS OFF"
                : root.activeTab === "bluetooth" && !DeviceState.bluetoothEnabled ? "BLUETOOTH IS OFF"
                : "NO DEVICES DETECTED"
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 11; font.letterSpacing: 0.8
        }

        RowLayout {
            Layout.fillWidth: true
            Text { visible: NetState.statusMessage.indexOf("FAIL") >= 0; Layout.fillWidth: true; text: NetState.statusMessage; color: Theme.danger; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Rectangle {
                implicitWidth: 142; implicitHeight: 34; radius: 11
                color: advancedPointer.containsMouse ? Theme.cyan : Theme.elevated
                border.width: 0
                Text { anchors.centerIn: parent; text: "ADVANCED SETTINGS"; color: advancedPointer.containsMouse ? Theme.void_ : Theme.moon; font.family: Theme.fontText; font.pixelSize: 10; font.weight: Font.Bold }
                MouseArea { id: advancedPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { ShellState.closeEphemeris(); Quickshell.execDetached(["nm-connection-editor"]); } }
            }
        }
    }
}
