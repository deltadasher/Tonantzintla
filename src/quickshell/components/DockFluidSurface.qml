import QtQuick
import ".."

// A single filled contour. Its flared feet meet the monitor boundary, with
// inward depth in local coordinates regardless of the chosen screen edge.
Canvas {
    id: root
    property string edge: "bottom"
    property real reveal: 0
    property real cursorAlong: 0.5
    property color fillColor: Theme.mantle
    readonly property bool vertical: edge === "left" || edge === "right"
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onEdgeChanged: requestPaint()
    onRevealChanged: requestPaint()
    onCursorAlongChanged: requestPaint()
    onFillColorChanged: requestPaint()
    antialiasing: true
    onPaint: {
        const c = getContext("2d");
        c.reset();
        const span = vertical ? height : width;
        const depth = vertical ? width : height;
        if (span < 1 || depth < 1 || reveal < 0.001) return;
        if (edge === "bottom") { c.translate(0, height); c.scale(1, -1); }
        else if (edge === "left") c.transform(0, 1, 1, 0, 0, 0);
        else if (edge === "right") c.transform(0, 1, -1, 0, width, 0);
        const h = (depth - 12) * reveal;
        const foot = Math.min(32, span / 5);
        const cx = Math.max(foot + 24, Math.min(span - foot - 24, cursorAlong * span));
        const wave = Math.sin(reveal * Math.PI) * 9;
        c.beginPath();
        c.moveTo(0, 0);
        c.bezierCurveTo(foot, 0, foot * 0.4, h, foot * 1.7, h);
        c.lineTo(Math.max(foot * 1.7, cx - 30), h);
        c.bezierCurveTo(cx - 15, h, cx - 15, h + wave, cx, h + wave);
        c.bezierCurveTo(cx + 15, h + wave, cx + 15, h, cx + 30, h);
        c.lineTo(span - foot * 1.7, h);
        c.bezierCurveTo(span - foot * 0.4, h, span - foot, 0, span, 0);
        c.closePath();
        c.fillStyle = fillColor.toString();
        c.fill();
    }
}
