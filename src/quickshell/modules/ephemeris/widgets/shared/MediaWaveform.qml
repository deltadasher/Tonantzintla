import QtQuick
import "../../../.."
import "../../../../services"

Item {
    id: root

    property real progress: 0
    property bool enabledControl: true
    property bool interacting: false
    property real previewProgress: progress
    // Live loudness fed by the parent; remembered per timeline slot so the
    // envelope shows the parts of the track that have actually played.
    property real energy: 0
    property string trackKey: ""
    property var envelope: []
    signal seekRequested(real progress)

    implicitHeight: 54

    onTrackKeyChanged: {
        envelope = new Array(72).fill(0);
        wave.requestPaint();
    }

    onProgressChanged: {
        if (interacting || energy <= 0 || envelope.length === 0)
            return;
        const slot = Math.max(0, Math.min(71, Math.floor(progress * 72)));
        if (energy > envelope[slot])
            envelope[slot] = energy;
    }

    Component.onCompleted: envelope = new Array(72).fill(0)

    function updateFromX(x) {
        previewProgress = Math.max(0, Math.min(1, x / Math.max(1, width)));
        wave.requestPaint();
    }

    Canvas {
        id: wave
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const context = getContext("2d");
            context.reset();
            const values = Spectrum.available ? Spectrum.values : [];
            const count = 72;
            const center = height / 2;
            const shown = root.interacting ? root.previewProgress : root.progress;
            const playSlot = Math.floor(shown * count);
            for (let index = 0; index < count; index++) {
                const ratio = index / Math.max(1, count - 1);
                const remembered = Number(root.envelope[index] || 0);
                // Heard slots keep their recorded loudness and the slot under
                // the playhead breathes with the live spectrum. Unheard slots
                // are drawn as hairline ticks: inventing a shape for audio
                // that never played turns the strip into a meaningless fence,
                // most visibly while paused.
                let source = remembered;
                if (index === playSlot && values.length > 0) {
                    let live = 0;
                    values.forEach(function(value) { live += Number(value || 0); });
                    source = Math.max(source, live / values.length);
                }
                const heard = source > 0;
                const bar = heard
                    ? 5 + Math.min(1, source) * height * 0.40
                    : 2;
                const x = ratio * width;
                context.beginPath();
                context.moveTo(x, center - bar);
                context.lineTo(x, center + bar);
                context.strokeStyle = ratio <= shown ? Theme.accent : Theme.lineBright;
                context.globalAlpha = (ratio <= shown ? 0.96 : 0.34) * (heard ? 1 : 0.6);
                context.lineWidth = Math.max(2, width / count * 0.42);
                context.stroke();
            }
            context.globalAlpha = 1;
            const playhead = shown * width;
            context.beginPath();
            context.arc(playhead, center, root.interacting ? 7 : 5, 0, Math.PI * 2);
            context.fillStyle = Theme.moon;
            context.fill();
        }
        Connections {
            target: Spectrum
            function onValuesChanged() { wave.requestPaint(); }
        }
        Connections {
            target: root
            function onProgressChanged() { wave.requestPaint(); }
        }
        Component.onCompleted: requestPaint()
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        enabled: root.enabledControl
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: function(mouse) { root.interacting = true; root.updateFromX(mouse.x); }
        onPositionChanged: function(mouse) { if (pressed) root.updateFromX(mouse.x); }
        onReleased: function(mouse) {
            root.updateFromX(mouse.x);
            root.seekRequested(root.previewProgress);
            root.interacting = false;
        }
    }
}
