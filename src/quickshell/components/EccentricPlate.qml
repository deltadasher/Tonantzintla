import QtQuick
import ".."

Canvas {
    id: root

    property color fillColor: Theme.glass
    property color lineColor: "transparent"
    property color tone: Theme.accent
    property real cut: 18
    property real energy: 0
    property real lineWidth: 0

    antialiasing: true

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onToneChanged: requestPaint()
    onCutChanged: requestPaint()
    onEnergyChanged: requestPaint()
    onLineWidthChanged: requestPaint()

    function platePath(ctx, inset) {
        const x = inset;
        const y = inset;
        const w = Math.max(0, width - inset * 2);
        const h = Math.max(0, height - inset * 2);
        const radius = Math.max(8, Math.min(root.cut - inset, 22, w / 2, h / 2));

        ctx.beginPath();
        ctx.moveTo(x + radius, y);
        ctx.lineTo(x + w - radius, y);
        ctx.quadraticCurveTo(x + w, y, x + w, y + radius);
        ctx.lineTo(x + w, y + h - radius);
        ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h);
        ctx.lineTo(x + radius, y + h);
        ctx.quadraticCurveTo(x, y + h, x, y + h - radius);
        ctx.lineTo(x, y + radius);
        ctx.quadraticCurveTo(x, y, x + radius, y);
        ctx.closePath();
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        platePath(ctx, root.lineWidth * 0.5);
        ctx.fillStyle = root.fillColor.toString();
        ctx.fill();
        if (root.lineWidth > 0) {
            ctx.lineWidth = root.lineWidth;
            ctx.strokeStyle = root.lineColor.toString();
            ctx.lineJoin = "round";
            ctx.stroke();
        }
    }
}
