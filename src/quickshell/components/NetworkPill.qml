import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

Rectangle {
    id: root
    property string outputName: ""

    readonly property var activeNetwork: NetState.wifiNetworks.find(function(network) {
        return network.connected === true;
    }) || null
    readonly property int signal: activeNetwork ? Number(activeNetwork.signal || 0) : 0
    readonly property bool isVertical: root.parent && typeof root.parent.isVertical !== "undefined"
        ? root.parent.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")

    implicitWidth: isVertical ? (Settings.compact ? 36 : 40) : Math.max(126, row.implicitWidth + 18)
    implicitHeight: Settings.compact ? 34 : 38
    radius: 10
    color: pointer.containsMouse ? Theme.barNeutralHover : "transparent"
    border.width: 0
    scale: pointer.containsMouse ? 1.025 : 1

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Canvas {
            id: networkIcon
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter

            readonly property bool connected: NetState.connected
            readonly property bool isEthernet: NetState.kind === "LINK"
            readonly property int sigLevel: root.signal > 0 ? root.signal : (connected ? 80 : 0)
            readonly property color activeColor: Theme.cyan
            readonly property color mutedColor: Theme.lineBright

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                if (isEthernet) {
                    ctx.beginPath();
                    ctx.rect(3, 4, 14, 11);
                    ctx.lineWidth = 1.8;
                    ctx.strokeStyle = connected ? activeColor.toString() : mutedColor.toString();
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.moveTo(6, 15); ctx.lineTo(6, 17);
                    ctx.moveTo(10, 15); ctx.lineTo(10, 18);
                    ctx.moveTo(14, 15); ctx.lineTo(14, 17);
                    ctx.lineWidth = 1.5;
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.arc(10, 9.5, 2, 0, 2 * Math.PI);
                    ctx.fillStyle = connected ? activeColor.toString() : Theme.danger.toString();
                    ctx.fill();
                    return;
                }

                const cx = 10;
                const cy = 16.5;

                ctx.beginPath();
                ctx.arc(cx, cy, 1.8, 0, 2 * Math.PI);
                ctx.fillStyle = connected ? activeColor.toString() : Theme.danger.toString();
                ctx.fill();

                if (!connected) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, 8, -Math.PI * 0.75, -Math.PI * 0.25);
                    ctx.lineWidth = 1.8;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = Qt.rgba(Theme.line.r, Theme.line.g, Theme.line.b, 0.4).toString();
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.moveTo(4, 5); ctx.lineTo(16, 17);
                    ctx.lineWidth = 1.6;
                    ctx.strokeStyle = Theme.danger.toString();
                    ctx.stroke();
                    return;
                }

                const startAngle = -Math.PI * 0.75;
                const endAngle = -Math.PI * 0.25;
                const radii = [5.5, 9.5, 13.5];
                const thresholds = [0, 40, 70];

                for (let i = 0; i < 3; i++) {
                    const active = connected && sigLevel >= thresholds[i];
                    ctx.beginPath();
                    ctx.arc(cx, cy, radii[i], startAngle, endAngle);
                    ctx.lineWidth = 1.8;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = active
                        ? activeColor.toString()
                        : Qt.rgba(mutedColor.r, mutedColor.g, mutedColor.b, 0.22).toString();
                    ctx.stroke();
                }
            }

            Connections {
                target: NetState
                function onConnectedChanged() { networkIcon.requestPaint(); }
                function onKindChanged() { networkIcon.requestPaint(); }
            }
            onSigLevelChanged: requestPaint()
        }

        ColumnLayout {
            visible: !root.isVertical
            spacing: -1
            Text {
                Layout.maximumWidth: 112
                text: Settings.showNetworkLabel ? NetState.label : "NETWORK"
                color: Theme.moon
                font.family: Theme.fontText
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                text: NetState.connected
                    ? "CONNECTED" + (root.signal > 0 ? "  " + root.signal + "%" : "")
                    : "DISCONNECTED"
                color: NetState.connected ? Theme.cyan : Theme.danger
                font.family: Theme.fontText
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 0.35
            }
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.toggleEphemeris("network", outputName)
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutBack } }
}
