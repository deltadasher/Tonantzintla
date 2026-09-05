import QtQuick
import ".."

Item {
    id: root

    property real value: 0
    property bool muted: false
    property color accentColor: Theme.accent
    property string label: "OUTPUT"
    property bool energized: false
    property real activity: energized ? 1 : 0
    property real displayedValue: value
    readonly property real fillRatio: Math.max(0, Math.min(100, displayedValue)) / 100
    readonly property real overdriveRatio: Math.max(0, Math.min(50, displayedValue - 100)) / 50
    signal activated()

    implicitWidth: 138
    implicitHeight: 138

    Behavior on displayedValue {
        NumberAnimation { duration: Settings.motion ? 320 : 0; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 18
        height: width
        radius: width / 2
        color: root.muted ? Theme.danger : root.accentColor
        opacity: orbPointer.containsMouse ? 0.17 : 0.09

        SequentialAnimation on scale {
            running: Settings.motion && root.visible
            loops: Animation.Infinite
            NumberAnimation { to: 1.055; duration: 1700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 1700; easing.type: Easing.InOutSine }
        }
        Behavior on color { ColorAnimation { duration: Theme.motionNormal } }
        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.void_
        border.width: 0
        clip: true

        Canvas {
            id: liquid
            anchors.fill: parent
            property real phase: 0

            NumberAnimation on phase {
                from: 0
                to: Math.PI * 2
                duration: root.energized ? 620 : 1500
                loops: Animation.Infinite
                running: Settings.motion && root.visible && root.fillRatio > 0
                    && root.fillRatio < 1 && !root.muted
            }

            onPhaseChanged: requestPaint()
            Connections {
                target: root
                function onDisplayedValueChanged() { liquid.requestPaint(); overdrive.requestPaint(); }
                function onMutedChanged() { liquid.requestPaint(); }
                function onAccentColorChanged() { liquid.requestPaint(); overdrive.requestPaint(); }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (root.fillRatio <= 0 || root.muted)
                    return;

                const fillY = height * (1 - root.fillRatio);
                const amplitude = (6 + root.activity * 11)
                    * Math.sin(root.fillRatio * Math.PI);
                ctx.save();
                ctx.beginPath();
                ctx.arc(width / 2, height / 2, width / 2, 0, Math.PI * 2);
                ctx.clip();
                ctx.beginPath();
                ctx.moveTo(0, fillY);
                ctx.bezierCurveTo(width * 0.30,
                    fillY + Math.sin(phase) * amplitude,
                    width * 0.70,
                    fillY + Math.cos(phase + Math.PI) * amplitude,
                    width, fillY);
                ctx.lineTo(width, height);
                ctx.lineTo(0, height);
                ctx.closePath();
                const gradient = ctx.createLinearGradient(0, 0, 0, height);
                gradient.addColorStop(0, Qt.lighter(root.accentColor, 1.18).toString());
                gradient.addColorStop(1, root.accentColor.toString());
                ctx.fillStyle = gradient;
                ctx.globalAlpha = 0.90;
                ctx.fill();
                ctx.restore();
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 1
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.muted ? "MUTE" : Math.round(root.displayedValue) + "%"
                color: root.muted ? Theme.danger
                    : root.fillRatio >= 0.47 ? Theme.void_ : Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: root.muted ? 24 : 28
                font.weight: Font.Black
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.displayedValue > 100 ? "OVERDRIVE" : root.label
                color: root.displayedValue > 100 ? Theme.warning
                    : root.fillRatio >= 0.58 ? Theme.void_ : Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 1
            }
        }
    }

    Canvas {
        id: overdrive
        anchors.fill: parent
        visible: root.overdriveRatio > 0
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const radius = width / 2 - 4;
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, radius, -Math.PI / 2,
                -Math.PI / 2 + Math.PI * 2 * root.overdriveRatio);
            ctx.lineWidth = 5;
            ctx.lineCap = "round";
            ctx.strokeStyle = Theme.warning.toString();
            ctx.stroke();
        }
    }

    MouseArea {
        id: orbPointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    scale: orbPointer.containsMouse ? 1.025 : 1
    Behavior on scale { NumberAnimation { duration: Settings.motion ? 180 : 0; easing.type: Easing.OutCubic } }
}
