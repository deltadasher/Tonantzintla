import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../services"

Rectangle {
    id: root
    property string outputName: ""
    property var anchorHost: null

    property string accessibleLabel: "Open network · " + (NetState.connected ? NetState.label : "Disconnected")
    function activate() {
        if (root.anchorHost) root.anchorHost.toggleEphemeris("network", root);
        else ShellState.toggleEphemeris("network", root.outputName);
    }

    readonly property var activeNetwork: NetState.wifiNetworks.find(function(network) {
        return network.connected === true;
    }) || null
    readonly property int signal: activeNetwork ? Number(activeNetwork.signal || 0) : 0
    readonly property bool isVertical: root.parent && typeof root.parent.isVertical !== "undefined"
        ? root.parent.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")
    readonly property bool sourceActive: ShellState.ephemerisVisible
        && ShellState.ephemerisAnchorTarget === root
    readonly property bool hovered: pointer.containsMouse && !pointer.hoverSuppressed
        && !sourceActive

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: accessibleLabel
    Accessible.onPressAction: activate()
    Keys.onReturnPressed: activate()
    Keys.onSpacePressed: activate()

    ToolTip {
        visible: root.hovered
        delay: 500
        text: root.accessibleLabel
        background: Rectangle { color: Theme.mantle; radius: Theme.radiusSmall; border.color: Theme.accentLine }
        contentItem: Text { text: root.accessibleLabel; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: Theme.textLabel }
    }

    readonly property bool inverted: NetState.connected && !root.isVertical
    implicitWidth: isVertical ? (Settings.compact ? 32 : 36) : Math.max(96, row.implicitWidth + 18)
    implicitHeight: Settings.compact ? 26 : 30
    radius: Math.min(Theme.radiusSmall, height / 2)
    color: root.inverted ? (root.hovered ? Qt.lighter(Theme.accent, 1.06) : Theme.accent)
        : root.hovered ? Theme.controlHover : Theme.pillRest
    border.width: 1
    border.color: activeFocus ? Theme.focusRing
        : root.inverted ? color
        : root.hovered ? Theme.surfaceBorderHover : Theme.surfaceBorder

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Canvas {
            id: networkIcon
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter

            readonly property bool connected: NetState.connected
            readonly property bool isEthernet: NetState.kind === "LINK"
            readonly property int sigLevel: root.signal > 0 ? root.signal : (connected ? 80 : 0)
            readonly property color activeColor: root.inverted ? Theme.onAccent : Theme.cyan
            readonly property color mutedColor: root.inverted ? Theme.onAccent : Theme.lineBright

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
            onActiveColorChanged: requestPaint()
            onMutedColorChanged: requestPaint()
        }

        RowLayout {
            visible: !root.isVertical
            spacing: 5
            Text {
                Layout.maximumWidth: 112
                text: !NetState.connected ? "Offline"
                    : Settings.showNetworkLabel ? NetState.label : "Online"
                color: root.inverted ? Theme.onAccent : Theme.danger
                font.family: Theme.fontMono
                font.pixelSize: Theme.textCaption
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                visible: NetState.connected && root.signal > 0
                text: root.signal + "%"
                color: root.inverted ? Qt.rgba(Theme.onAccent.r, Theme.onAccent.g, Theme.onAccent.b, 0.78) : Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: Theme.textMicro
                font.weight: Font.Bold
            }
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        property bool hoverSuppressed: false
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            hoverSuppressed = true;
            root.activate();
        }
        onExited: hoverSuppressed = false
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
}
