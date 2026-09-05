import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../.."

PanelWindow {
    id: root

    required property var modelData
    property bool transitionActive: false
    property real aperture: 0
    property real phase: 0

    screen: modelData
    anchors { top: true; right: true; bottom: true; left: true }
    visible: transitionActive
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "tonantzintla-umbra-reveal"

    function beginReveal() {
        transitionActive = true;
        aperture = 0;
        revealSequence.restart();
    }

    Connections {
        target: ShellState
        function onUmbraRevealSerialChanged() {
            root.beginReveal();
        }
    }

    Component.onCompleted: {
        if (ShellState.umbraRevealSerial > 0)
            beginReveal();
    }

    SequentialAnimation {
        id: revealSequence
        PauseAnimation { duration: Settings.motion && Settings.umbraMotion ? 1510 : 45 }
        NumberAnimation {
            target: root
            property: "aperture"
            from: 0
            to: 1
            duration: Settings.motion && Settings.umbraMotion ? 820 : 0
            easing.type: Easing.OutExpo
        }
        ScriptAction { script: root.transitionActive = false }
    }

    NumberAnimation on phase {
        from: 0
        to: 1
        loops: Animation.Infinite
        duration: Settings.motion && Settings.umbraMotion ? 2800 : 1
        running: root.transitionActive
    }

    Loader {
        anchors.fill: parent
        active: root.transitionActive
        sourceComponent: veilComponent
    }

    Component {
        id: veilComponent

        Canvas {
            id: veil

            Connections {
                target: root
                function onApertureChanged() { veil.requestPaint(); }
                function onPhaseChanged() { veil.requestPaint(); }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            function rgba(color, alpha) {
                return "rgba(" + Math.round(color.r * 255) + ","
                    + Math.round(color.g * 255) + ","
                    + Math.round(color.b * 255) + "," + alpha + ")";
            }

            onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width * 0.5;
            const cy = height * 0.5;
            const diagonal = Math.sqrt(width * width + height * height);
            const radius = diagonal * 0.56 * root.aperture;

            ctx.fillStyle = rgba(Theme.void_, 1);
            ctx.fillRect(0, 0, width, height);

            if (root.aperture > 0) {
                ctx.globalCompositeOperation = "destination-out";
                ctx.fillStyle = "rgba(0,0,0,1)";
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.fill();
                ctx.globalCompositeOperation = "source-over";

                const fade = Math.max(0, 1 - root.aperture);
                for (let ring = 0; ring < 4; ring++) {
                    const orbit = radius * (1 + ring * 0.035) + 8 + ring * 7;
                    const start = root.phase * Math.PI * 2 * (ring % 2 ? -1 : 1)
                        + ring * 0.82;
                    ctx.beginPath();
                    ctx.arc(cx, cy, orbit, start, start + 1.35 + ring * 0.24);
                    ctx.lineWidth = Math.max(2, 7 - ring);
                    ctx.lineCap = "round";
                    ctx.strokeStyle = rgba(ring % 2 ? Theme.cyan : Theme.accent,
                        fade * (0.54 - ring * 0.08));
                    ctx.stroke();
                }
            }
            }
        }
    }
}
