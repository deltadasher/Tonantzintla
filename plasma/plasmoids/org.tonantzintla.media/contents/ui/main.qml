pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    readonly property var player: mprisModel.currentPlayer
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackStatus === 2
    readonly property color accentColor: Kirigami.Theme.focusColor
    function linChannel(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
    readonly property color accentFg: (0.2126 * linChannel(accentColor.r) + 0.7152 * linChannel(accentColor.g) + 0.0722 * linChannel(accentColor.b)) > 0.34 ? "#101016" : "#f8f7fc"
    Layout.minimumWidth: hasPlayer ? pill.implicitWidth : 0
    Layout.preferredWidth: hasPlayer ? pill.implicitWidth : 0
    Layout.maximumWidth: hasPlayer ? 276 : 0
    Layout.fillHeight: true

    Mpris.Mpris2Model {
        id: mprisModel
    }

    Rectangle {
        id: pill
        visible: root.hasPlayer
        anchors.centerIn: parent
        implicitWidth: Math.min(268, contentRow.implicitWidth + 14)
        implicitHeight: 28
        radius: 8
        color: mediaHover.hovered ? Kirigami.Theme.alternateBackgroundColor : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        HoverHandler { id: mediaHover }

        RowLayout {
            id: contentRow
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 7

            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: 5
                color: Kirigami.Theme.alternateBackgroundColor
                border.width: 1
                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.hasPlayer ? (root.player.artUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !root.hasPlayer || !root.player.artUrl
                    text: "♪"
                    color: root.accentColor
                    font.pixelSize: 11
                }
            }

            // Micro 3-bar live playback visualizer
            Row {
                visible: root.playing
                spacing: 1.5
                Layout.alignment: Qt.AlignVCenter
                Repeater {
                    model: 3
                    Item {
                        id: eqSlot
                        required property int index
                        width: 2
                        height: 12
                        Rectangle {
                            width: 2
                            height: 4
                            radius: 1
                            anchors.bottom: parent.bottom
                            color: root.accentColor
                            SequentialAnimation on height {
                                running: root.playing
                                loops: Animation.Infinite
                                NumberAnimation { to: eqSlot.index === 1 ? 11 : (eqSlot.index === 0 ? 9 : 8); duration: 240 + eqSlot.index * 95; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 3; duration: 220 + eqSlot.index * 80; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.maximumWidth: 148
                text: root.hasPlayer ? (root.player.track || root.player.identity || "Media") : ""
                color: root.playing ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                font.family: "JetBrains Mono"
                font.pixelSize: 11
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                text: "‹"
                color: prevMouse.containsMouse ? root.accentColor : Kirigami.Theme.disabledTextColor
                font.family: "JetBrains Mono"
                font.pixelSize: 14
                font.bold: true
                MouseArea {
                    id: prevMouse
                    anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.hasPlayer) root.player.Previous()
                }
            }
            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 6
                color: playMouse.containsMouse ? root.accentColor : Kirigami.Theme.alternateBackgroundColor
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: root.playing ? "❚❚" : "▶"
                    color: playMouse.containsMouse ? root.accentFg : Kirigami.Theme.textColor
                    font.pixelSize: 9
                }
                MouseArea {
                    id: playMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.hasPlayer) root.player.PlayPause()
                }
            }
            Text {
                text: "›"
                color: nextMouse.containsMouse ? root.accentColor : Kirigami.Theme.disabledTextColor
                font.family: "JetBrains Mono"
                font.pixelSize: 14
                font.bold: true
                MouseArea {
                    id: nextMouse
                    anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.hasPlayer) root.player.Next()
                }
            }
        }
    }
}
