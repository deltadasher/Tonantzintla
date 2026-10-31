import QtQuick
import "SceneDrawing.js" as Drawing

// Portable artwork shared by Umbra and the greeter. No shell or login state.
Item {
    id: root
    property string identity: "wabi-sabi"
    property color accent: Drawing.approvedAccent(identity)
    property bool lightMode: false
    property bool active: true
    property bool motion: true
    property url iconSource: Qt.resolvedUrl("../../assets/theme-marks/" + identity + ".svg")
    readonly property color backgroundColor: Drawing.background(identity, lightMode)
    readonly property color foregroundColor: lightMode ? "#24272B" : "#F3F1ED"
    readonly property color mutedColor: Drawing.mix(foregroundColor, backgroundColor, 0.30)
    readonly property color accentColor: Drawing.readableAccent(accent, backgroundColor, foregroundColor)
    readonly property color dangerColor: Drawing.readableAccent(lightMode ? "#a93649" : "#ed7d8f", backgroundColor, foregroundColor)
    readonly property bool portrait: height > width * 1.12
    // The entire square fits in a reserved region. Drawing uses an additional
    // 80-unit inset, so its silhouettes and small transforms never meet an edge.
    readonly property real artboardSize: Math.max(0, portrait
        ? Math.min(width * 0.90, height * 0.36)
        : Math.min(width * 0.52, height * 0.84))
    readonly property rect artRect: Qt.rect(
        portrait ? (width - artboardSize) * 0.5 : width * 0.44 + (width * 0.52 - artboardSize) * 0.5,
        portrait ? height * 0.04 : (height - artboardSize) * 0.5,
        artboardSize, artboardSize)
    // Shared placement contract for lock and greeter hosts. Portrait clocks and
    // authentication controls belong below the complete illustration.
    readonly property real suggestedClockY: height * (portrait ? 0.43 : 0.29)
    readonly property real suggestedInputY: height * (portrait ? 0.65 : 0.58)
    readonly property var mark: Drawing.markPlacement(identity)
    readonly property real motionUnit: artboardSize / 1000
    property real motionPhase: 0

    Rectangle { anchors.fill: parent; color: root.backgroundColor }

    Item {
        id: illustration
        objectName: "themeSceneArtboard"
        width: root.artRect.width
        height: width
        x: root.artRect.x
        y: root.artRect.y

        transform: [
            Translate {
                x: root.identity === "cloud" ? root.motionPhase * 4 * root.motionUnit : 0
                y: ["water-droplet", "ink"].indexOf(root.identity) !== -1 ? root.motionPhase * -2.5 * root.motionUnit : 0
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
            // These scenes draw their subject directly, without a pasted logo.
            visible: ["leaf", "ink", "cloud", "ruby", "ice-cube", "seashell", "sun", "moon", "night-sky", "snowflake"].indexOf(root.identity) === -1
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
                y: ["fire", "sun", "moon", "night-sky"].indexOf(root.identity) !== -1 ? root.motionPhase * -2 * root.motionUnit : 0
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
