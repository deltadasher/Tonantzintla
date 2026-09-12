import QtQuick
import ".."
import "../services"

Item {
    id: root

    required property string output
    readonly property var workspaces: Compositor.workspaces
        .filter(function(workspace) { return workspace.output === root.output; })
        .sort(function(a, b) { return a.idx - b.idx; })
    readonly property int activeIndex: {
        const found = workspaces.findIndex(function(workspace) {
            return workspace.is_active === true;
        });
        return Math.max(0, found);
    }

    readonly property bool isVertical: root.parent && typeof root.parent.isVertical !== "undefined" ? root.parent.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")

    implicitWidth: isVertical ? 30 : workspaceGrid.implicitWidth
    implicitHeight: isVertical ? workspaceGrid.implicitHeight : 30

    Rectangle {
        visible: root.workspaces.length > 0
        readonly property real targetOffset: root.activeIndex * (30 + 5)
        property real animatedStart: targetOffset
        property real animatedEnd: targetOffset + 30
        x: root.isVertical ? 0 : animatedStart
        y: root.isVertical ? animatedStart : 0
        width: root.isVertical ? 30 : (animatedEnd - animatedStart)
        height: root.isVertical ? (animatedEnd - animatedStart) : 30
        radius: 9
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.84)
        z: 0

        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: parent.radius + 1
            color: Theme.accent
            opacity: 0.18
            z: -1
        }

        property int previousIndex: 0
        property int currentIndex: root.activeIndex
        onCurrentIndexChanged: {
            if (currentIndex > previousIndex) {
                startMotion.duration = 340;
                endMotion.duration = 180;
            } else {
                startMotion.duration = 180;
                endMotion.duration = 340;
            }
            previousIndex = currentIndex;
            animatedStart = targetOffset;
            animatedEnd = targetOffset + 30;
        }

        Behavior on animatedStart {
            NumberAnimation {
                id: startMotion
                duration: Settings.motion ? 240 : 0
                easing.type: Easing.OutExpo
            }
        }
        Behavior on animatedEnd {
            NumberAnimation {
                id: endMotion
                duration: Settings.motion ? 240 : 0
                easing.type: Easing.OutExpo
            }
        }
    }

    Grid {
        id: workspaceGrid
        columns: root.isVertical ? 1 : -1
        spacing: 5
        z: 1

        Repeater {
            model: root.workspaces

            Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool active: modelData.is_active === true
                readonly property bool focused: modelData.is_focused === true
                readonly property bool urgent: modelData.is_urgent === true
                readonly property bool hasWindows: Compositor.windows.some(function(w) {
                    return w.workspace_id === cell.modelData.id;
                })
                property real entrance: 1

                width: 30
                height: 30
                opacity: entrance
                transform: Translate { y: (1 - cell.entrance) * 12 }

                Rectangle {
                    anchors.centerIn: parent
                    width: cell.active ? 30 : cellPointer.containsMouse ? 27 : 23
                    height: width
                    radius: 9
                    color: cell.active ? "transparent"
                        : cell.urgent ? Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.14)
                        : cellPointer.containsMouse ? Theme.barNeutralHover : "transparent"
                    border.width: 0
                    scale: cellPointer.containsMouse && !cell.active ? 1.06 : 1

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.idx
                        color: cell.active ? Theme.void_
                            : cell.urgent ? Theme.warning
                            : cellPointer.containsMouse || cell.focused ? Theme.moon : Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: cell.active ? Font.Black : Font.DemiBold
                    }

                    Rectangle {
                        visible: cell.hasWindows && !cell.active
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        width: 3
                        height: 3
                        radius: 1.5
                        color: cellPointer.containsMouse ? Theme.accent : Theme.muted
                        opacity: 0.8
                    }

                    Behavior on width { NumberAnimation { duration: Settings.motion ? 190 : 0; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Behavior on scale { NumberAnimation { duration: Settings.motion ? 180 : 0; easing.type: Easing.OutBack } }
                }

                MouseArea {
                    id: cellPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Compositor.focusWorkspace(cell.modelData.id)
                }

                Timer {
                    interval: cell.index * 55
                    running: true
                    onTriggered: cell.entrance = 1
                }
                Behavior on entrance { NumberAnimation { duration: Settings.motion ? 360 : 0; easing.type: Easing.OutBack } }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.workspaces.length === 0
        text: Compositor.available ? "CONNECTING" : "NIRI NOT RUNNING"
        color: Theme.muted
        font.family: Theme.fontMono
        font.pixelSize: 10
        font.letterSpacing: 1.2
    }
}
