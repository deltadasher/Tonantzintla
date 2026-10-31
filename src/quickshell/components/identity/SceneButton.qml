import QtQuick
import "ControlDrawing.js" as Draw

// A button in an identity's shape, with a drawn icon (never a font glyph).
Item {
    id: root
    property string shape: "circle"
    property string icon: "enter"
    property string label: ""
    property bool filled: false
    property bool showLabel: false
    property color accent: "#e9b872"
    property color foreground: "#f3f1ed"
    property color background: "#16191c"
    property var labelType
    signal triggered()

    implicitWidth: 44
    implicitHeight: 44
    opacity: enabled ? 1 : .35
    scale: pointer.pressed ? .9 : pointer.containsMouse ? 1.07 : 1
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: if (root.enabled) root.triggered()
    Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack } }

    readonly property bool lit: filled || pointer.containsMouse

    Canvas {
        id: face
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.Image
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width <= 0) return;
            const size = Math.min(width, height);
            ctx.translate((width - size) / 2, (height - size) / 2);
            Draw.paintShape(ctx, root.shape, size, root.lit ? Draw.rgba(root.accent, 1)
                : Draw.rgba(root.foreground, .12));
            const g = Draw.glyph(root.shape, size);
            Draw.paintIcon(ctx, root.icon, g[0], g[1], g[2], root.lit ? Draw.rgba(root.background, 1)
                : Draw.rgba(root.foreground, .92));
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
    onLitChanged: face.requestPaint()
    onShapeChanged: face.requestPaint()
    onIconChanged: face.requestPaint()
    onAccentChanged: face.requestPaint()
    onForegroundChanged: face.requestPaint()
    onBackgroundChanged: face.requestPaint()

    SceneLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 8
        visible: root.showLabel && root.label.length > 0
        opacity: pointer.containsMouse ? .8 : 0
        text: root.label
        type: root.labelType || ({ families: ["sans-serif"] })
        color: root.foreground
        size: 11
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
