pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.workspace.dbus as DBus
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    readonly property color accentColor: Kirigami.Theme.focusColor
    function linChannel(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
    readonly property color accentFg: (0.2126 * linChannel(accentColor.r) + 0.7152 * linChannel(accentColor.g) + 0.0722 * linChannel(accentColor.b)) > 0.34 ? "#101016" : "#f8f7fc"

    readonly property int desktopCount: Math.max(1, Math.min(10, virtualDesktopInfo.numberOfDesktops))
    readonly property int currentIndex: {
        for (let i = 0; i < virtualDesktopInfo.desktopIds.length; i++) {
            if (virtualDesktopInfo.desktopIds[i] === virtualDesktopInfo.currentDesktop) return i;
        }
        return 0;
    }

    // Spring-damped continuous index driving liquid SDF metaball neck stretching
    property real smoothActivePos: currentIndex
    Behavior on smoothActivePos {
        SpringAnimation { spring: 4.8; damping: 0.34; epsilon: 0.002 }
    }

    // Extra room on each side of the active capsule so every gap in the row is the same width.
    readonly property real activeRoom: 9.0

    property int hoveredIndex: -1
    property real hoverAmount: hoveredIndex >= 0 ? 1.0 : 0.0
    Behavior on hoverAmount { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Layout.minimumWidth: pill.implicitWidth
    Layout.preferredWidth: pill.implicitWidth
    Layout.maximumWidth: pill.implicitWidth
    Layout.fillHeight: true

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    // Desktop switching is one typed D-Bus call to KWin: no shell and no helper binary.
    QtObject {
        id: switcher
        property real wheelRemainder: 0
        function activate(oneBasedIndex) {
            const total = Math.max(1, virtualDesktopInfo.numberOfDesktops);
            const target = Math.max(1, Math.min(total, Math.floor(Number(oneBasedIndex) || 1)));
            DBus.SessionBus.asyncCall({
                "service": "org.kde.KWin",
                "path": "/KWin",
                "iface": "org.kde.KWin",
                "member": "setCurrentDesktop",
                "arguments": [new DBus.int32(target)]
            });
        }
        // Touchpads send many small deltas; move one desktop per full wheel notch.
        function wheel(angleDeltaY) {
            wheelRemainder += angleDeltaY;
            if (Math.abs(wheelRemainder) < 120) return;
            step(wheelRemainder < 0 ? 1 : -1);
            wheelRemainder = 0;
        }
        function step(delta) {
            const total = Math.max(1, virtualDesktopInfo.numberOfDesktops);
            if (total <= 1) return;
            const cur = root.currentIndex + 1;
            const next = Math.max(1, Math.min(total, cur + (delta > 0 ? 1 : -1)));
            if (next !== cur) activate(next);
        }
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        implicitWidth: 32 + root.activeRoom * 2 + (root.desktopCount - 1) * 20
        implicitHeight: 26
        radius: 8
        color: groupHover.hovered
            ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.055)
            : "transparent"
        Behavior on color { ColorAnimation { duration: 140 } }

        HoverHandler { id: groupHover }

        WheelHandler {
            onWheel: function(event) {
                switcher.wheel(event.angleDelta.y);
            }
        }

        // GPU GLSL Liquid Metaball SDF Indicator
        ShaderEffect {
            anchors.fill: parent
            property real uTime: 0.0
            property real uCount: root.desktopCount
            property real uActivePos: root.smoothActivePos
            property real uHoverIdx: root.hoveredIndex
            property real uHoverAmt: root.hoverAmount
            property vector2d uResolution: Qt.vector2d(width, height)
            property color uAccent: root.accentColor
            property color uText: Kirigami.Theme.textColor
            property color uMuted: Kirigami.Theme.disabledTextColor
            fragmentShader: Qt.resolvedUrl("../shaders/workspaces_metaball.frag.qsb")
        }

        // Crisp stable hit targets layered over each desktop node
        Repeater {
            model: root.desktopCount
            MouseArea {
                id: hitZone
                required property int index
                readonly property real padX: 16.0
                readonly property real stepX: root.desktopCount > 1 ? (pill.width - padX * 2.0 - root.activeRoom * 2.0) / (root.desktopCount - 1) : 0.0
                readonly property real shift: root.activeRoom * (Math.max(-1, Math.min(1, index - root.currentIndex)) + 1)
                readonly property real cx: root.desktopCount > 1 ? (padX + index * stepX + shift) : (pill.width * 0.5)
                readonly property real reach: index === root.currentIndex ? 14 : 10
                x: cx - reach
                y: 0
                width: reach * 2
                height: pill.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredIndex = hitZone.index
                onExited: if (root.hoveredIndex === hitZone.index) root.hoveredIndex = -1
                onClicked: switcher.activate(hitZone.index + 1)
            }
        }
    }
}
