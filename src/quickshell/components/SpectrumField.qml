import QtQuick
import ".."
import "../services"

Item {
    id: root

    property color accentColor: Theme.accent
    property color secondaryColor: Theme.cyan
    property string title: Spectrum.available ? "LIVE ROOM RESPONSE" : "NO AUDIO"
    property string detail: Spectrum.available ? "CAVA // 28 CHANNEL FFT" : "WAITING FOR SOMETHING TO PLAY"
    property real phase: 0

    NumberAnimation on phase {
        from: 0
        to: Math.PI * 2
        duration: 2600
        loops: Animation.Infinite
        running: Settings.motion && root.visible
    }

    Canvas {
        id: orbitalTrace
        anchors.fill: parent
        opacity: 0.42

        Connections {
            target: root
            function onPhaseChanged() { orbitalTrace.requestPaint(); }
            function onAccentColorChanged() { orbitalTrace.requestPaint(); }
            function onSecondaryColorChanged() { orbitalTrace.requestPaint(); }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const centerX = width / 2;
            const centerY = height * 0.50;
            const radiusX = Math.max(20, width * 0.43);
            const radiusY = Math.max(16, height * 0.30);

            ctx.save();
            ctx.setLineDash([5, 9]);
            ctx.lineWidth = 1;
            ctx.strokeStyle = Qt.rgba(root.accentColor.r, root.accentColor.g,
                root.accentColor.b, 0.46).toString();
            ctx.beginPath();
            ctx.ellipse(centerX, centerY, radiusX, radiusY, -0.10, 0, Math.PI * 2);
            ctx.stroke();

            ctx.setLineDash([]);
            for (let index = 0; index < 7; index++) {
                const angle = root.phase * 0.20 + index * Math.PI * 2 / 7;
                const x = centerX + Math.cos(angle) * radiusX;
                const y = centerY + Math.sin(angle) * radiusY;
                ctx.beginPath();
                ctx.arc(x, y, index % 3 === 0 ? 2.5 : 1.5, 0, Math.PI * 2);
                ctx.fillStyle = (index % 2 === 0
                    ? root.secondaryColor : root.accentColor).toString();
                ctx.globalAlpha = 0.68;
                ctx.fill();
            }
            ctx.restore();
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.72, 440)
        height: Math.min(parent.height * 0.66, 190)
        radius: height / 2
        color: root.accentColor
        opacity: 0.035

        SequentialAnimation on scale {
            running: Settings.motion && root.visible
            loops: Animation.Infinite
            NumberAnimation { to: 1.06; duration: 2200; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 2200; easing.type: Easing.InOutSine }
        }
    }

    Row {
        id: bandRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Math.max(24, parent.width * 0.10)
        anchors.rightMargin: Math.max(24, parent.width * 0.10)
        height: Math.max(72, parent.height * 0.44)
        spacing: 4

        Repeater {
            model: 28
            Rectangle {
                required property int index
                readonly property real liveLevel: Spectrum.available
                    ? Spectrum.values[index]
                    : 0.10 + (Math.sin(root.phase + index * 0.54) + 1) * 0.10
                        + (Math.sin(root.phase * 1.7 - index * 0.31) + 1) * 0.045
                width: Math.max(2, (bandRow.width - 27 * bandRow.spacing) / 28)
                height: Math.max(3, bandRow.height * liveLevel)
                anchors.bottom: parent.bottom
                radius: Math.min(width / 2, 4)
                color: index % 4 === 0 ? root.secondaryColor : root.accentColor
                opacity: Spectrum.available ? 0.82 : 0.40

                Behavior on height {
                    NumberAnimation { duration: Spectrum.available ? 70 : 130; easing.type: Easing.OutQuad }
                }
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        spacing: 3
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            color: Spectrum.available ? root.secondaryColor : Theme.moon
            font.family: Theme.fontMono
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 1.1
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.detail
            color: Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: 10
            font.letterSpacing: 0.8
        }
    }
}
