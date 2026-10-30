import QtQuick
import ".."
import "../services"

Item {
    id: root

    // Presentation only: every style shares the same compositor state and targets.
    readonly property string requestedStyle: typeof Settings.barWorkspaceStyle === "string" ? Settings.barWorkspaceStyle : "orbital"
    readonly property string style: ["orbital", "pills", "dots", "track"].indexOf(requestedStyle) >= 0 ? requestedStyle : "orbital"
    readonly property bool motionEnabled: Settings.motion && Settings.motionSpeedProfile !== "instant"
    onMotionEnabledChanged: {
        if (!motionEnabled) {
            startMotion.complete();
            endMotion.complete();
        }
    }
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
        visible: root.workspaces.length > 0 && root.style === "orbital"
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
                startMotion.duration = root.motionEnabled ? 340 : 0;
                endMotion.duration = root.motionEnabled ? 180 : 0;
            } else {
                startMotion.duration = root.motionEnabled ? 180 : 0;
                endMotion.duration = root.motionEnabled ? 340 : 0;
            }
            previousIndex = currentIndex;
            animatedStart = targetOffset;
            animatedEnd = targetOffset + 30;
        }

        Behavior on animatedStart {
            NumberAnimation {
                id: startMotion
                duration: root.motionEnabled ? 240 : 0
                easing.type: Easing.OutExpo
            }
        }
        Behavior on animatedEnd {
            NumberAnimation {
                id: endMotion
                duration: root.motionEnabled ? 240 : 0
                easing.type: Easing.OutExpo
            }
        }
    }

    Rectangle {
        visible: root.style === "track" && root.workspaces.length > 0
        x: root.isVertical ? 14 : 15
        y: root.isVertical ? 15 : 14
        width: root.isVertical ? 2 : Math.max(0, root.implicitWidth - 30)
        height: root.isVertical ? Math.max(0, root.implicitHeight - 30) : 2
        radius: 1
        color: Theme.barHairlineHover
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
                objectName: "workspace-" + modelData.id
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Workspace " + modelData.idx + (active ? ", current" : hasWindows ? ", occupied" : ", empty") + (urgent ? ", urgent" : "")
                Accessible.onPressAction: Compositor.focusWorkspace(cell.modelData.id)
                Keys.onReturnPressed: Compositor.focusWorkspace(cell.modelData.id)
                Keys.onEnterPressed: Compositor.focusWorkspace(cell.modelData.id)
                Keys.onSpacePressed: Compositor.focusWorkspace(cell.modelData.id)
                property real entrance: 1

                width: 30
                height: 30
                opacity: entrance
                transform: Translate { y: (1 - cell.entrance) * 12 }

                Rectangle {
                    visible: root.style === "orbital"
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
                        color: cell.active ? (typeof Theme.onAccent === "undefined" ? Theme.void_ : Theme.onAccent)
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

                    Behavior on width { NumberAnimation { duration: root.motionEnabled ? 190 : 0; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Behavior on scale { NumberAnimation { duration: root.motionEnabled ? 180 : 0; easing.type: Easing.OutBack } }
                }

                Rectangle {
                    visible: root.style !== "orbital"
                    anchors.centerIn: parent
                    width: root.style === "pills" ? (root.isVertical ? 7 : cell.active ? 24 : 12)
                        : root.style === "track" ? (cell.active ? 18 : 9) : cell.active ? 12 : 7
                    height: root.style === "pills" ? (root.isVertical ? cell.active ? 24 : 12 : 7)
                        : width
                    radius: Math.min(width, height) / 2
                    color: cell.active ? Theme.accent : cell.urgent ? Theme.warning
                        : cell.hasWindows ? Theme.moon : "transparent"
                    border.width: cell.active || cell.hasWindows || cell.urgent ? 0 : 1
                    border.color: Theme.muted
                    opacity: cell.active || cell.urgent || cellPointer.containsMouse ? 1 : cell.hasWindows ? 0.75 : 0.6
                    Behavior on width { NumberAnimation { duration: root.motionEnabled ? 160 : 0 } }
                    Behavior on height { NumberAnimation { duration: root.motionEnabled ? 160 : 0 } }
                    // Keep urgent state visible even when this workspace is current.
                    Rectangle {
                        visible: cell.urgent && cell.active
                        anchors.centerIn: parent
                        width: 4; height: 4; radius: 2; color: Theme.warning
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: "transparent"
                    border.width: cell.activeFocus ? 1 : 0
                    border.color: Theme.accent
                    Rectangle {
                        visible: root.style !== "orbital" && cellPointer.containsMouse
                        anchors.fill: parent
                        radius: 9
                        color: Theme.barNeutralHover
                        opacity: 0.25
                    }
                }

                MouseArea {
                    id: cellPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Compositor.focusWorkspace(cell.modelData.id)
                }


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
