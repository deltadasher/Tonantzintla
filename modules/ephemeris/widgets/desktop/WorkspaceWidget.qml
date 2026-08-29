import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../.."
import "../../../../services"

Item {
    id: root

    function windowsFor(workspaceId) {
        return Niri.windows.filter(function(window) {
            return window.workspace_id === workspaceId;
        });
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "WORKSPACES"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }

            Rectangle {
                implicitWidth: 38
                implicitHeight: 38
                radius: width / 2
                color: overviewPointer.containsMouse ? Theme.accent : Theme.controlRest
                border.width: 0
                border.color: overviewPointer.containsMouse ? Theme.accentLine : Theme.line
                Text {
                    id: overviewText
                    anchors.centerIn: parent
                    text: "◎"
                    color: overviewPointer.containsMouse ? Theme.void_ : Theme.muted
                    font.family: Theme.fontDisplay
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }
                MouseArea {
                    id: overviewPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ShellState.closeEphemeris();
                        Quickshell.execDetached(["niri", "msg", "action", "toggle-overview"]);
                    }
                }
            }
        }

        GridView {
            id: workspaceGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: Niri.workspaces
            cellWidth: Math.max(280, width / Math.min(3, Math.max(1, Math.ceil(width / 330))))
            cellHeight: 224

            delegate: Item {
                id: workspaceDelegate
                required property var modelData
                width: workspaceGrid.cellWidth
                height: workspaceGrid.cellHeight
                readonly property var workspaceWindows: root.windowsFor(modelData.id)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 5
                    radius: Theme.radiusLarge
                    color: workspaceDelegate.modelData.is_focused
                        ? Theme.controlActive : workspacePointer.containsMouse ? Theme.controlHover : Theme.controlRest
                    border.width: 0
                    clip: true

                    MouseArea {
                        id: workspacePointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Niri.focusWorkspace(workspaceDelegate.modelData.id)
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 40
                        color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.34)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 7
                            Rectangle {
                                Layout.preferredWidth: 25
                                Layout.preferredHeight: 25
                                radius: 9
                                color: workspaceDelegate.modelData.is_focused ? Theme.accent : Theme.elevated
                                Text {
                                    anchors.centerIn: parent
                                    text: workspaceDelegate.modelData.idx
                                    color: workspaceDelegate.modelData.is_focused ? Theme.void_ : Theme.moon
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: -2
                                Text {
                                    Layout.fillWidth: true
                                    text: workspaceDelegate.modelData.name || "WORKSPACE " + workspaceDelegate.modelData.idx
                                    color: Theme.moon
                                    font.family: Theme.fontText
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: (workspaceDelegate.modelData.output || "OUTPUT") + " // " + workspaceDelegate.workspaceWindows.length + " WINDOWS"
                                    color: Theme.muted
                                    font.family: Theme.fontMono
                                    font.pixelSize: 10
                                }
                            }
                            Rectangle {
                                Layout.preferredWidth: 7
                                Layout.preferredHeight: 7
                                radius: 4
                                color: workspaceDelegate.modelData.is_focused ? Theme.success
                                    : workspaceDelegate.modelData.is_active ? Theme.cyan : Theme.lineBright
                            }
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 48
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9
                        spacing: 6

                        Repeater {
                            model: workspaceDelegate.workspaceWindows.slice(0, 4)
                            Rectangle {
                                required property var modelData
                                width: parent ? parent.width : 0
                                height: 30
                                radius: 9
                                color: modelData.is_focused ? Theme.accentVeil
                                    : windowPointer.containsMouse ? Theme.elevated : Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.26)
                                border.width: 0
                                border.color: modelData.is_focused ? Theme.accentLine : Theme.line
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 9
                                    anchors.rightMargin: 9
                                    spacing: 7
                                    Rectangle {
                                        Layout.preferredWidth: 5
                                        Layout.preferredHeight: 5
                                        radius: 3
                                        color: modelData.is_focused ? Theme.accent : Theme.lineBright
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title || modelData.app_id || "Untitled window"
                                        color: modelData.is_focused ? Theme.moon : Theme.muted
                                        font.family: Theme.fontText
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: (modelData.app_id || "APP").toUpperCase()
                                        color: Theme.lineBright
                                        font.family: Theme.fontMono
                                        font.pixelSize: 10
                                    }
                                }
                                MouseArea {
                                    id: windowPointer
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Niri.focusWindow(modelData.id);
                                        ShellState.closeEphemeris();
                                    }
                                }
                            }
                        }

                        Text {
                            visible: workspaceDelegate.workspaceWindows.length === 0
                            width: parent.width
                            height: 70
                            text: "EMPTY\nclick to switch to this workspace"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            lineHeight: 1.5
                        }
                        Text {
                            visible: workspaceDelegate.workspaceWindows.length > 4
                            width: parent.width
                            text: "+ " + (workspaceDelegate.workspaceWindows.length - 4) + " MORE WINDOWS"
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }

                }
            }

            Text {
                anchors.centerIn: parent
                visible: Niri.workspaces.length === 0
                text: Niri.available ? "WAITING FOR NIRI'S EVENT STREAM" : "REQUIRES A NIRI SESSION"
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.letterSpacing: 1
            }
        }
    }
}
