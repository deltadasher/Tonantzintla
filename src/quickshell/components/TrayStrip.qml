import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import ".."

Item {
    id: root
    readonly property bool isVertical: root.parent && typeof root.parent.isVertical !== "undefined" ? root.parent.isVertical : (Settings.barPosition === "left" || Settings.barPosition === "right")
    property bool expanded: false
    readonly property int maxCollapsed: 5
    readonly property var allItems: SystemTray.items.values
    readonly property bool hasOverflow: allItems.length > maxCollapsed
    readonly property var visibleItems: (hasOverflow && !expanded) ? allItems.slice(0, maxCollapsed) : allItems
    readonly property int displayCount: visibleItems.length + (hasOverflow ? 1 : 0)

    implicitWidth: isVertical ? 28 : Math.max(28, displayCount * 28 + Math.max(0, displayCount - 1) * 3)
    implicitHeight: isVertical ? Math.max(28, displayCount * 28 + Math.max(0, displayCount - 1) * 3) : 28
    Behavior on implicitWidth { NumberAnimation { duration: Settings.motion ? 150 : 0 } }
    Behavior on implicitHeight { NumberAnimation { duration: Settings.motion ? 150 : 0 } }

    Grid {
        anchors.fill: parent
        columns: root.isVertical ? 1 : Math.max(1, root.displayCount)
        spacing: 3

    Repeater {
        model: root.visibleItems

        Rectangle {
            id: trayItem
            required property var modelData
            width: 28
            height: 28
            radius: 8
            color: trayPointer.containsMouse ? Theme.barNeutralHover : "transparent"

            function openMenu() {
                if (modelData && modelData.hasMenu)
                    trayMenu.open();
            }

            QsMenuAnchor {
                id: trayMenu
                menu: trayItem.modelData ? trayItem.modelData.menu : null
                anchor.item: trayItem
            }

            IconImage {
                id: trayIcon
                anchors.centerIn: parent
                implicitSize: 16
                source: trayItem.modelData.icon
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !trayIcon.visible
                text: {
                    const title = trayItem.modelData.tooltipTitle
                        || trayItem.modelData.title || trayItem.modelData.id || "?";
                    return title.length > 0 ? title.charAt(0).toUpperCase() : "?";
                }
                color: Theme.moon
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.weight: Font.Bold
            }

            MouseArea {
                id: trayPointer
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onPressed: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        trayItem.openMenu();
                        mouse.accepted = true;
                    }
                }
                onClicked: function(mouse) {
                    if (mouse.button === Qt.MiddleButton)
                        trayItem.modelData.secondaryActivate();
                    else if (mouse.button === Qt.LeftButton && trayItem.modelData.onlyMenu)
                        trayItem.openMenu();
                    else if (mouse.button === Qt.LeftButton)
                        trayItem.modelData.activate();
                }
                onWheel: function(event) {
                    trayItem.modelData.scroll(event.angleDelta.y, false);
                    event.accepted = true;
                }
            }

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }
    }

        Rectangle {
            id: overflowPill
            visible: root.hasOverflow
            width: 28
            height: 28
            radius: 8
            color: overflowPointer.containsMouse ? Theme.controlActive : Theme.controlRest
            Text {
                anchors.centerIn: parent
                text: root.expanded ? "«" : "⋯"
                color: overflowPointer.containsMouse ? Theme.accent : Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: root.expanded ? 12 : 11
                font.bold: true
            }
            MouseArea {
                id: overflowPointer
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }
    }
}
