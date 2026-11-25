pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kcmutils as KCMUtils
import org.kde.plasma.private.volume as PlasmaVolume
import org.kde.plasma.private.battery as PlasmaBattery

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    readonly property var sink: PlasmaVolume.PreferredDevice.sink
    readonly property int volPercent: sink ? Math.round((sink.volume / 65536.0) * 100) : 0
    readonly property bool volMuted: sink ? sink.muted : false
    readonly property string volIcon: {
        if (volMuted || volPercent <= 0) return "audio-volume-muted";
        if (volPercent < 34) return "audio-volume-low";
        if (volPercent < 67) return "audio-volume-medium";
        return "audio-volume-high";
    }
    readonly property color accentColor: Kirigami.Theme.focusColor
    function linChannel(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
    readonly property color accentFg: (0.2126 * linChannel(accentColor.r) + 0.7152 * linChannel(accentColor.g) + 0.0722 * linChannel(accentColor.b)) > 0.34 ? "#101016" : "#f8f7fc"
    // JetBrains Mono when it is installed; otherwise the system fixed-width font, so digits never shift.
    readonly property string monoFamily: Qt.fontFamilies().indexOf("JetBrains Mono") >= 0
        ? "JetBrains Mono"
        : Kirigami.Theme.fixedWidthFont.family
    readonly property color textFg: (0.2126 * linChannel(Kirigami.Theme.textColor.r) + 0.7152 * linChannel(Kirigami.Theme.textColor.g) + 0.0722 * linChannel(Kirigami.Theme.textColor.b)) > 0.34 ? "#101016" : "#f8f7fc"

    PlasmaBattery.BatteryControlModel {
        id: batteryModel
    }

    compactRepresentation: Item {
        Layout.minimumWidth: pillsRow.implicitWidth + 8
        Layout.preferredWidth: pillsRow.implicitWidth + 8
        Layout.maximumWidth: pillsRow.implicitWidth + 8
        Layout.fillHeight: true

        Row {
            id: pillsRow
            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                visible: root.sink !== null && root.sink !== undefined
                width: volLabel.implicitWidth + 18
                height: 24
                radius: 7
                color: root.volMuted ? Kirigami.Theme.alternateBackgroundColor : root.accentColor
                opacity: volMouse.containsMouse ? 0.90 : 1.0
                scale: volMouse.pressed ? 0.95 : 1.0
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on opacity { NumberAnimation { duration: 100 } }
                Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.42 } }
                Text {
                    id: volLabel
                    anchors.centerIn: parent
                    text: root.volMuted ? "MUTE" : ("VOL " + root.volPercent + "%")
                    color: root.volMuted ? Kirigami.Theme.disabledTextColor : root.accentFg
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
                MouseArea {
                    id: volMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.MiddleButton) {
                            if (root.sink) root.sink.muted = !root.sink.muted;
                        } else {
                            root.expanded = !root.expanded;
                        }
                    }
                    onWheel: function(wheel) {
                        if (!root.sink) return;
                        const delta = wheel.angleDelta.y > 0 ? 3277 : -3277;
                        root.sink.volume = Math.max(0, Math.min(98304, root.sink.volume + delta));
                    }
                }
            }

            Rectangle {
                visible: batteryModel.hasBatteries
                width: batLabel.implicitWidth + 18
                height: 24
                radius: 7
                color: batteryModel.percent <= 20 && !batteryModel.pluggedIn ? Kirigami.Theme.negativeTextColor : (batteryModel.pluggedIn ? Kirigami.Theme.textColor : Kirigami.Theme.alternateBackgroundColor)
                Text {
                    id: batLabel
                    anchors.centerIn: parent
                    text: (batteryModel.pluggedIn ? "⚡ " : "BAT ") + batteryModel.percent + "%"
                    color: batteryModel.pluggedIn ? root.textFg : (batteryModel.percent <= 20 ? "#101016" : Kirigami.Theme.textColor)
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expanded = !root.expanded
                }
            }
        }
    }

    // ULTRA-CLEAN GLSL LIQUID-PRISM TACTILE AUDIO & POWER POPUP
    fullRepresentation: Item {
        id: statusRoot
        implicitWidth: 304
        implicitHeight: batteryModel.hasBatteries ? 212 : 156

        property real faderTime: 0.0
        property real faderEnergy: 0.0
        property real mutedBlend: root.volMuted ? 1.0 : 0.0
        Behavior on mutedBlend { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        FrameAnimation {
            running: statusRoot.visible
            onTriggered: {
                const dt = Math.min(0.05, Math.max(0.001, frameTime));
                statusRoot.faderTime = (statusRoot.faderTime + dt) % 1000.0;
                if (statusRoot.faderEnergy > 0.004) statusRoot.faderEnergy *= Math.pow(0.05, dt);
                else statusRoot.faderEnergy = 0.0;
            }
        }

        Connections {
            target: root
            function onVolPercentChanged() {
                statusRoot.faderEnergy = 1.0;
            }
        }

        // Pinned to the top so a resized popup keeps its rhythm instead of spreading the rows apart.
        ColumnLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: root.sink ? (root.sink.description || root.sink.name || "Output") : "Audio"
                    color: Kirigami.Theme.textColor
                    font.family: root.monoFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    text: root.volMuted ? "Muted" : (root.volPercent + "%")
                    color: root.volMuted ? Kirigami.Theme.negativeTextColor : root.accentColor
                    font.family: root.monoFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }

            // GPU GLSL Liquid-Prism Tactile Volume Fader
            Item {
                id: sliderTrack
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                readonly property real fillRatio: Math.max(0.0, Math.min(1.0, root.volPercent / 100.0))
                property real displayRatio: fillRatio
                Behavior on displayRatio {
                    enabled: !sliderMouse.pressed
                    SpringAnimation { spring: 6.2; damping: 0.48; epsilon: 0.002 }
                }

                property real pressedBlend: sliderMouse.pressed ? 1.0 : 0.0
                Behavior on pressedBlend { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                ShaderEffect {
                    anchors.fill: parent
                    property real uTime: statusRoot.faderTime
                    property real uRatio: sliderTrack.displayRatio
                    property real uMuted: statusRoot.mutedBlend
                    property real uPressed: sliderTrack.pressedBlend
                    property real uEnergy: statusRoot.faderEnergy
                    property vector2d uResolution: Qt.vector2d(width, height)
                    property color uAccent: root.accentColor
                    property color uAccentFg: root.accentFg
                    property color uSurface: Kirigami.Theme.alternateBackgroundColor
                    property color uText: Kirigami.Theme.textColor
                    fragmentShader: Qt.resolvedUrl("../shaders/status_fader.frag.qsb")
                }

                // Embedded dynamic speaker icon with auto-contrast over active fill
                Kirigami.Icon {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15
                    height: 15
                    source: root.volIcon
                    isMask: true
                    color: (!root.volMuted && sliderTrack.displayRatio * sliderTrack.width > 28) ? root.accentFg : Kirigami.Theme.disabledTextColor
                }

                MouseArea {
                    id: sliderMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    function setFromX(mx) {
                        if (!root.sink) return;
                        const ratio = Math.max(0, Math.min(1, mx / Math.max(1, sliderTrack.width)));
                        root.sink.muted = false;
                        root.sink.volume = Math.round(ratio * 65536);
                        statusRoot.faderEnergy = 0.85;
                    }
                    onPressed: function(mouse) { setFromX(mouse.x); }
                    onPositionChanged: function(mouse) { if (pressed) setFromX(mouse.x); }
                    onWheel: function(wheel) {
                        if (!root.sink) return;
                        const delta = wheel.angleDelta.y > 0 ? 3277 : -3277;
                        root.sink.muted = false;
                        root.sink.volume = Math.max(0, Math.min(65536, root.sink.volume + delta));
                        statusRoot.faderEnergy = 1.0;
                    }
                }
            }

            // Clean Battery readout + slim charge bar when hardware battery is present
            ColumnLayout {
                visible: batteryModel.hasBatteries
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: batteryModel.pluggedIn ? "Charging" : "Battery"
                        color: Kirigami.Theme.disabledTextColor
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }
                    Text {
                        text: batteryModel.percent + "%"
                        color: batteryModel.percent <= 20 && !batteryModel.pluggedIn
                            ? Kirigami.Theme.negativeTextColor
                            : (batteryModel.pluggedIn ? Kirigami.Theme.positiveTextColor : root.accentColor)
                        font.family: root.monoFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Kirigami.Theme.alternateBackgroundColor
                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, batteryModel.percent / 100.0))
                        radius: 3
                        color: batteryModel.percent <= 20 && !batteryModel.pluggedIn
                            ? Kirigami.Theme.negativeTextColor
                            : (batteryModel.pluggedIn ? Kirigami.Theme.positiveTextColor : root.accentColor)
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 9
                    color: root.volMuted
                        ? root.accentColor
                        : (muteMouse.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.11) : Kirigami.Theme.alternateBackgroundColor)
                    scale: muteMouse.pressed ? 0.94 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.42 } }
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14
                            source: root.volMuted ? "audio-volume-high" : "audio-volume-muted"
                            isMask: true
                            color: root.volMuted ? root.accentFg : Kirigami.Theme.textColor
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.volMuted ? "Unmute" : "Mute"
                            color: root.volMuted ? root.accentFg : Kirigami.Theme.textColor
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }
                    MouseArea {
                        id: muteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.sink) root.sink.muted = !root.sink.muted
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 9
                    color: cfgMouse.containsMouse ? root.accentColor : Kirigami.Theme.alternateBackgroundColor
                    scale: cfgMouse.pressed ? 0.94 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.42 } }
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14
                            source: "configure"
                            isMask: true
                            color: cfgMouse.containsMouse ? root.accentFg : Kirigami.Theme.textColor
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Mixer"
                            color: cfgMouse.containsMouse ? root.accentFg : Kirigami.Theme.textColor
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }
                    MouseArea {
                        id: cfgMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            KCMUtils.KCMLauncher.openSystemSettings("kcm_pulseaudio");
                            root.expanded = false;
                        }
                    }
                }
            }
        }
    }
}
