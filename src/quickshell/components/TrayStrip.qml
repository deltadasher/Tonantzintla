import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import ".."

RowLayout {
    spacing: 3

    Repeater {
        model: SystemTray.items.values

        Rectangle {
            id: trayItem
            required property var modelData
            Layout.preferredWidth: 27
            Layout.preferredHeight: 27
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
}
