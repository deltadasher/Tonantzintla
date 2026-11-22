pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Layout.minimumWidth: pill.implicitWidth
    Layout.preferredWidth: pill.implicitWidth
    Layout.maximumWidth: pill.implicitWidth
    Layout.fillHeight: true

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    Plasma5Support.DataSource {
        id: switcher
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName) { disconnectSource(sourceName); }
        function activate(oneBasedIndex) {
            const total = Math.max(1, virtualDesktopInfo.numberOfDesktops);
            const target = Math.max(1, Math.min(total, Math.floor(Number(oneBasedIndex) || 1)));
            connectSource("qdbus6 org.kde.KWin /KWin setCurrentDesktop " + target);
        }
        function step(delta) {
            const total = Math.max(1, virtualDesktopInfo.numberOfDesktops);
            if (total <= 1) return;
            let cur = 1;
            for (let i = 0; i < virtualDesktopInfo.desktopIds.length; i++) {
                if (virtualDesktopInfo.desktopIds[i] === virtualDesktopInfo.currentDesktop) { cur = i + 1; break; }
            }
            const next = Math.max(1, Math.min(total, cur + (delta > 0 ? 1 : -1)));
            if (next !== cur) activate(next);
        }
    }

    Item {
        id: pill
        anchors.centerIn: parent
        implicitWidth: Math.max(36, dotsRow.implicitWidth + 12)
        implicitHeight: 26

        WheelHandler {
            onWheel: function(event) {
                if (event.angleDelta.y !== 0) switcher.step(event.angleDelta.y < 0 ? 1 : -1);
            }
        }

        Row {
            id: dotsRow
            anchors.centerIn: parent
            spacing: 7

            Repeater {
                model: Math.max(1, virtualDesktopInfo.numberOfDesktops)

                Rectangle {
                    id: dot
                    required property int index
                    readonly property var desktopId: index < virtualDesktopInfo.desktopIds.length ? virtualDesktopInfo.desktopIds[index] : ""
                    readonly property bool active: desktopId === virtualDesktopInfo.currentDesktop || (virtualDesktopInfo.numberOfDesktops <= 1 && index === 0)
                    width: active ? 22 : 7
                    height: 7
                    radius: 3.5
                    color: active ? Kirigami.Theme.focusColor : (dotMouse.containsMouse ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor)
                    opacity: active ? 1.0 : (dotMouse.containsMouse ? 0.85 : 0.45)
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 140 } }

                    MouseArea {
                        id: dotMouse
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcher.activate(dot.index + 1)
                    }
                }
            }
        }
    }
}
