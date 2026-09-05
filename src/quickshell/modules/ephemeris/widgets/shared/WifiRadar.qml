import QtQuick
import "../../../.."

Item {
    id: root

    property var networks: []
    property bool loading: false
    property bool radioEnabled: true
    property var hoveredNetwork: null
    signal networkActivated(var network)

    readonly property int networkCount: networks ? networks.length : 0
    readonly property int usableCount: networks ? networks.filter(function(network) {
        return Number(network.signal) >= 45;
    }).length : 0
    readonly property var connectedNetwork: networks ? networks.find(function(network) {
        return network.connected === true;
    }) || null : null
    readonly property var radarNetworks: networks ? networks.filter(function(network) {
        return network.connected !== true;
    }) : []

    function stableHash(value) {
        let hash = 2166136261;
        const text = String(value || "");
        for (let index = 0; index < text.length; index++) {
            hash ^= text.charCodeAt(index);
            hash = Math.imul(hash, 16777619);
        }
        return Math.abs(hash);
    }

    function angleFor(network) {
        const frequency = Number(network.frequency);
        const jitter = (stableHash(network.ssid) % 1000 / 1000 - 0.5) * 1.08;
        if (frequency >= 5925)
            return 1.72 + Math.min(1, (frequency - 5925) / 1200) * 1.45 + jitter;
        if (frequency >= 4900)
            return -0.58 + Math.min(1, (frequency - 4900) / 1000) * 1.75 + jitter;
        if (frequency >= 2400)
            return -2.76 + Math.min(1, (frequency - 2412) / 80) * 1.65 + jitter;
        return stableHash(network.ssid) % 6283 / 1000;
    }

    function radiusFor(network) {
        const maximum = Math.max(92, Math.min(width, height) * 0.43);
        const minimum = Math.min(82, maximum * 0.40);
        const strength = Math.max(0, Math.min(100, Number(network.signal)));
        const lane = stableHash(String(network.ssid) + "-orbit") % 5 - 2;
        return Math.max(minimum, Math.min(maximum,
            minimum + (100 - strength) / 100 * (maximum - minimum) + lane * 7));
    }

    Rectangle {
        anchors.fill: parent
        radius: 28
        color: Qt.rgba(Theme.elevated.r, Theme.elevated.g, Theme.elevated.b, 0.36)
    }

    Canvas {
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            const radius = Math.min(width, height) * 0.46;
            const cx = width / 2;
            const cy = height / 2;
            ctx.lineWidth = 1;
            for (let ring = 0; ring < 4; ring++) {
                ctx.strokeStyle = Qt.rgba(Theme.cyan.r, Theme.cyan.g,
                    Theme.cyan.b, 0.16 - ring * 0.025);
                ctx.beginPath();
                ctx.arc(cx, cy, Math.min(width, height) * (0.13 + ring * 0.095),
                    0, Math.PI * 2);
                ctx.stroke();
            }
            const sectors = [
                { "start": -2.82, "end": -1.02, "label": "2.4" },
                { "start": -0.72, "end": 1.32, "label": "5" },
                { "start": 1.58, "end": 3.18, "label": "6" }
            ];
            ctx.lineWidth = 2;
            ctx.lineCap = "round";
            for (let index = 0; index < sectors.length; index++) {
                const sector = sectors[index];
                ctx.strokeStyle = index === 0 ? Theme.cyan
                    : index === 1 ? Theme.accent : Theme.rose;
                ctx.globalAlpha = 0.20;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, sector.start, sector.end);
                ctx.stroke();
            }
            ctx.globalAlpha = 1;
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }

    Rectangle {
        anchors.centerIn: parent
        width: 88
        height: 88
        radius: width / 2
        color: root.connectedNetwork ? Theme.accent : Theme.controlRest
        Column {
            anchors.centerIn: parent
            spacing: -1
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.connectedNetwork ? root.connectedNetwork.signal + "%" : "—"
                color: root.connectedNetwork ? Theme.void_ : Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 25
                font.weight: Font.Black
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 76
                horizontalAlignment: Text.AlignHCenter
                text: root.connectedNetwork ? root.connectedNetwork.ssid : "OFFLINE"
                color: root.connectedNetwork ? Theme.void_ : Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.weight: Font.Black
                elide: Text.ElideRight
            }
        }
    }

    Repeater {
        model: root.radarNetworks
        Item {
            id: networkNode
            required property int index
            required property var modelData
            readonly property real angle: root.angleFor(modelData)
            readonly property real orbit: root.radiusFor(modelData)
            readonly property int bodySize: modelData.saved ? 26
                : Number(modelData.signal) >= 60 ? 23 : 19
            x: root.width / 2 + Math.cos(angle) * orbit - width / 2
            y: root.height / 2 + Math.sin(angle) * orbit - height / 2
            width: 106
            height: 54
            z: nodePointer.containsMouse ? 4 : 2

            Rectangle {
                anchors.centerIn: parent
                width: networkNode.bodySize
                height: width
                radius: width / 2
                color: networkNode.modelData.secure
                        ? networkNode.modelData.saved ? Theme.accent : Theme.muted
                        : Theme.cyan
                scale: nodePointer.containsMouse ? 1.16 : 1
                Behavior on scale { NumberAnimation { duration: Settings.motion ? 150 : 0; easing.type: Easing.OutCubic } }

                Rectangle {
                    visible: !networkNode.modelData.secure
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: width / 2
                    color: Theme.elevated
                }

                Rectangle {
                    visible: networkNode.modelData.saved
                    anchors.centerIn: parent
                    width: 7
                    height: 7
                    radius: width / 2
                    color: Theme.moon
                }
            }

            Rectangle {
                visible: nodePointer.containsMouse
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.verticalCenter
                anchors.topMargin: networkNode.bodySize / 2 + 5
                width: Math.min(104, nodeLabel.implicitWidth + 16)
                height: 24
                radius: 12
                color: Theme.controlRest
                Text {
                    id: nodeLabel
                    anchors.centerIn: parent
                    width: Math.min(88, implicitWidth)
                    text: networkNode.modelData.ssid
                    color: Theme.moon
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: nodePointer
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredNetwork = networkNode.modelData
                onExited: if (root.hoveredNetwork === networkNode.modelData) root.hoveredNetwork = null
                onClicked: root.networkActivated(networkNode.modelData)
            }

            Behavior on x { NumberAnimation { duration: Settings.motion ? 420 : 0; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: Settings.motion ? 420 : 0; easing.type: Easing.OutCubic } }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 18
        spacing: 2
        Text {
            text: root.hoveredNetwork ? root.hoveredNetwork.ssid
                : root.usableCount + " USABLE / " + root.networkCount + " FOUND"
            color: Theme.moon
            font.family: Theme.fontDisplay
            font.pixelSize: 17
            font.weight: Font.Bold
        }
        Text {
            text: root.hoveredNetwork
                ? root.hoveredNetwork.signal + "%  ·  " + root.hoveredNetwork.frequency
                    + " MHz  ·  " + root.hoveredNetwork.security
                : "CLOSER MEANS STRONGER"
            color: root.hoveredNetwork ? Theme.cyan : Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }

    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 18
        spacing: 14
        Text { text: "● SAVED"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
        Text { text: "○ OPEN"; color: Theme.cyan; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
        Text { text: "RINGS = SIGNAL"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
    }

    Text {
        anchors.centerIn: parent
        visible: root.networkCount === 0
        text: root.loading ? "SCANNING…" : !root.radioEnabled ? "WI-FI IS OFF" : "NO NETWORKS FOUND"
        color: Theme.muted
        font.family: Theme.fontMono
        font.pixelSize: 11
        font.weight: Font.Bold
    }
}
