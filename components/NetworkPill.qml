import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

Rectangle {
    id: root

    readonly property var activeNetwork: NetState.wifiNetworks.find(function(network) {
        return network.connected === true;
    }) || null
    readonly property int signal: activeNetwork ? Number(activeNetwork.signal || 0) : 0

    implicitWidth: Math.max(126, row.implicitWidth + 18)
    implicitHeight: Settings.compact ? 34 : 38
    radius: 10
    color: pointer.containsMouse ? Theme.barNeutralHover : "transparent"
    border.width: 0
    scale: pointer.containsMouse ? 1.025 : 1

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Item {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24

            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: 8 + index * 7
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: NetState.connected
                        ? Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b,
                            0.30 + index * 0.17)
                        : Theme.line
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 5
                height: 5
                radius: 3
                color: NetState.connected ? Theme.success : Theme.danger
            }

            Item {
                anchors.fill: parent
                rotation: 0
                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 4
                    height: 4
                    radius: 2
                    color: NetState.connected ? Theme.moon : Theme.muted
                }
                NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 6200
                    loops: Animation.Infinite
                    running: Settings.motion && NetState.connected && root.visible
                }
            }
        }

        ColumnLayout {
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
        onClicked: ShellState.toggleEphemeris("network")
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutBack } }
}
