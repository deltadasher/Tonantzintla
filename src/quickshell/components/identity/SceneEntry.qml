import QtQuick
import "ControlDrawing.js" as Draw

// An identity's password line. Each typed character adds one glyph; the
// password itself is never drawn. Repaints only when its state changes.
Item {
    id: root
    property string kind: "orbit"
    property int cap: 32
    property int count: 0
    property bool failed: false
    property bool authenticating: false
    property bool motion: true
    property color accent: "#e9b872"
    property color foreground: "#f3f1ed"
    property color danger: "#ed7d8f"
    objectName: "sceneEntry_" + kind

    Canvas {
        id: line
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.Image
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width <= 0 || height <= 0) return;
            const glyph = root.failed ? root.danger : root.accent;
            Draw.paintEntry(ctx, root.kind, root.cap, root.count, width, height, {
                track: Draw.rgba(root.foreground, .22),
                glyph: Draw.rgba(glyph, 1),
                newest: Draw.rgba(root.failed ? root.danger : Qt.tint(root.accent, Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, .35)), 1)
            });
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
    onCountChanged: line.requestPaint()
    onFailedChanged: line.requestPaint()
    onKindChanged: line.requestPaint()
    onAccentChanged: line.requestPaint()
    onForegroundChanged: line.requestPaint()
    onDangerChanged: line.requestPaint()

    // Authentication breathes the whole line rather than repainting it.
    SequentialAnimation on opacity {
        running: root.authenticating && root.motion
        loops: Animation.Infinite
        NumberAnimation { to: .45; duration: 520; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 520; easing.type: Easing.InOutSine }
        onStopped: root.opacity = 1
    }
}
