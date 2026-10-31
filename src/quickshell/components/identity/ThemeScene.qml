import QtQuick
import "SceneDrawing.js" as Drawing

// Portable artwork shared by Umbra and the greeter. No shell or login state.
Item {
    id: root
    property string identity: "wabi-sabi"
    property color accent: Drawing.approvedAccent(identity)
    property bool lightMode: ["ruby", "fire", "leaf", "night-sky", "cloud", "ink"].indexOf(identity) !== -1
    property bool active: true
    property bool motion: true
    property url iconSource: Qt.resolvedUrl("../../assets/theme-marks/" + identity + ".svg")
    readonly property color backgroundColor: Drawing.background(identity, lightMode)
    readonly property color foregroundColor: lightMode ? "#24272B" : "#F3F1ED"
    readonly property color mutedColor: Drawing.mix(foregroundColor, backgroundColor, 0.30)
    readonly property color accentColor: Drawing.readableAccent(accent, backgroundColor, foregroundColor)
    readonly property bool portrait: height > width * 1.12
    readonly property var mark: Drawing.markPlacement(identity)
    property real motionPhase: 0
    clip: true

    Rectangle { anchors.fill: parent; color: root.backgroundColor }

    Item {
        id: illustration
        // The landscape's left 42% remains quiet; portrait art moves above the form.
        width: root.portrait ? root.width * 1.18 : Math.min(root.width * 0.65, root.height * 1.48)
        height: width
        x: root.portrait ? root.width * 0.12 : root.width - width * 0.96
        y: root.portrait ? -width * 0.18 : (root.height - height) * 0.5

        transform: [
            Translate {
                x: root.identity === "cloud" ? root.motionPhase * 4 : 0
                y: ["water-droplet", "ink"].indexOf(root.identity) !== -1 ? root.motionPhase * -2.5 : 0
            },
            Rotation {
                origin.x: illustration.width * 0.6
                origin.y: ["leaf", "snowflake"].indexOf(root.identity) !== -1 ? illustration.height * 0.88 : illustration.height * 0.47
                angle: ["leaf", "snowflake", "ringed-planet", "wabi-sabi"].indexOf(root.identity) !== -1 ? root.motionPhase * 0.35 : 0
            }
        ]

        Canvas {
            id: artwork
            anchors.fill: parent
            antialiasing: true
            renderTarget: Canvas.Image
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.scale(width / 1000, height / 1000);
                Drawing.paint(ctx, root.identity, root.accent, root.backgroundColor, root.foregroundColor, root.lightMode);
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        Image {
            id: approvedMark
            x: root.mark.x / 1000 * illustration.width
            y: root.mark.y / 1000 * illustration.height
            width: root.mark.size / 1000 * illustration.width
            height: width
            source: root.iconSource
            sourceSize.width: Math.ceil(width * 2)
            sourceSize.height: Math.ceil(height * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
            // Flame and celestial marks move independently of their grounded scenery.
            transform: Translate {
                y: ["fire", "sun", "moon", "night-sky"].indexOf(root.identity) !== -1 ? root.motionPhase * -2 : 0
            }
        }
    }
    SequentialAnimation on motionPhase {
        running: root.active && root.visible && root.motion
                 && ["ruby", "seashell", "ice-cube"].indexOf(root.identity) === -1
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: 5000; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: -1; duration: 10000; easing.type: Easing.InOutSine }
        NumberAnimation { from: -1; to: 0; duration: 5000; easing.type: Easing.InOutSine }
        onStopped: root.motionPhase = 0
    }
    onIdentityChanged: artwork.requestPaint()
    onAccentChanged: artwork.requestPaint()
    onLightModeChanged: artwork.requestPaint()
}
