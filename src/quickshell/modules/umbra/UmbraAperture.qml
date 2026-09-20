import QtQuick
import "../.."

// Pure presentation shared by the desktop veil and the non-locking preview.
// This item never acquires or releases a compositor session lock.
Item {
    id: root
    property real progress: 0
    ShaderEffect {
        id: effect
        anchors.fill: parent
        visible: root.GraphicsInfo.api !== GraphicsInfo.Software
        property real progress: root.progress
        property vector2d viewport: Qt.vector2d(width, height)
        property color primary: Theme.accent
        property color secondary: Theme.cyan
        property color backing: Theme.void_
        fragmentShader: Qt.resolvedUrl("shaders/aperture.frag.qsb")
    }
    Canvas {
        id: fallback
        anchors.fill: parent
        visible: root.GraphicsInfo.api === GraphicsInfo.Software || effect.status === ShaderEffect.Error
        Connections {
            target: root
            function onProgressChanged() { if (fallback.visible) fallback.requestPaint(); }
        }
        onVisibleChanged: if (visible) requestPaint()
        onWidthChanged: if (visible) requestPaint()
        onHeightChanged: if (visible) requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.progress >= 0.9999) return;
            ctx.fillStyle = Theme.void_;
            ctx.fillRect(0, 0, width, height);
            const p = root.progress;
            const t = p * p * p * (p * (p * 6 - 15) + 10);
            const radius = Math.max(0, -height * 0.025 + t * (Math.sqrt(width * width + height * height) * 0.56 + height * 0.025));
            ctx.globalCompositeOperation = "destination-out";
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, radius, 0, Math.PI * 2);
            ctx.fill();
        }
    }
}
