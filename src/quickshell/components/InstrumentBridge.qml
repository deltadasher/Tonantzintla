import QtQuick
import ".."

// One backing surface that grows directly from an instrument's source bounds.
// The animated rounded rectangle is the blob; there is deliberately no second
// connector shape, neck, or inward-curving bridge to expose the wallpaper.
Canvas {
    id: root
    required property var geometry
    property string edge: "top"
    property color fillColor: Theme.mantle
    property bool attached: false

    antialiasing: true
    onVisibleChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onEdgeChanged: requestPaint()
    onAttachedChanged: requestPaint()
    onFillColorChanged: requestPaint()

    Connections {
        target: root.geometry
        function onProgressChanged() { root.requestPaint(); }
        function onOriginChanged() { root.requestPaint(); }
        function onDestinationChanged() { root.requestPaint(); }
    }
    Connections { target: Theme; function onMantleChanged() { root.requestPaint(); } }

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function roundedRect(ctx, x, y, width, height, radius) {
        const r = Math.max(0, Math.min(radius, width / 2, height / 2));
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + width - r, y);
        ctx.quadraticCurveTo(x + width, y, x + width, y + r);
        ctx.lineTo(x + width, y + height - r);
        ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
        ctx.lineTo(x + r, y + height);
        ctx.quadraticCurveTo(x, y + height, x, y + height - r);
        ctx.lineTo(x, y + r);
        ctx.quadraticCurveTo(x, y, x + r, y);
        ctx.closePath();
    }

    // Fill the normally concave junction between the source and the deployed
    // body with two convex shoulders. These are expressed per edge so the same
    // silhouette survives bar rotation without positional special cases.
    function outwardShoulders(ctx, g, source) {
        const spread = Math.max(18, Math.min(46,
            (edge === "top" || edge === "bottom" ? source.width : source.height) * 0.38));
        const bend = spread * 0.72;
        const sr = Math.max(5, Math.min(12, source.width / 2, source.height / 2));

        if (edge === "bottom") {
            const seam = g.y + g.height;
            const shoulderY = source.y + source.height - sr;
            ctx.moveTo(source.x - spread, seam);
            ctx.bezierCurveTo(source.x - bend * 0.35, seam,
                source.x, shoulderY + bend * 0.55, source.x, shoulderY);
            ctx.lineTo(source.x, seam);
            ctx.closePath();
            ctx.moveTo(source.x + source.width + spread, seam);
            ctx.bezierCurveTo(source.x + source.width + bend * 0.35, seam,
                source.x + source.width, shoulderY + bend * 0.55,
                source.x + source.width, shoulderY);
            ctx.lineTo(source.x + source.width, seam);
            ctx.closePath();
        } else if (edge === "left") {
            const seam = g.x;
            const shoulderX = source.x + sr;
            ctx.moveTo(seam, source.y - spread);
            ctx.bezierCurveTo(seam, source.y - bend * 0.35,
                shoulderX + bend * 0.55, source.y, shoulderX, source.y);
            ctx.lineTo(seam, source.y);
            ctx.closePath();
            ctx.moveTo(seam, source.y + source.height + spread);
            ctx.bezierCurveTo(seam, source.y + source.height + bend * 0.35,
                shoulderX + bend * 0.55, source.y + source.height,
                shoulderX, source.y + source.height);
            ctx.lineTo(seam, source.y + source.height);
            ctx.closePath();
        } else if (edge === "right") {
            const seam = g.x + g.width;
            const shoulderX = source.x + source.width - sr;
            ctx.moveTo(seam, source.y - spread);
            ctx.bezierCurveTo(seam, source.y - bend * 0.35,
                shoulderX - bend * 0.55, source.y, shoulderX, source.y);
            ctx.lineTo(seam, source.y);
            ctx.closePath();
            ctx.moveTo(seam, source.y + source.height + spread);
            ctx.bezierCurveTo(seam, source.y + source.height + bend * 0.35,
                shoulderX - bend * 0.55, source.y + source.height,
                shoulderX, source.y + source.height);
            ctx.lineTo(seam, source.y + source.height);
            ctx.closePath();
        } else {
            const seam = g.y;
            const shoulderY = source.y + sr;
            ctx.moveTo(source.x - spread, seam);
            ctx.bezierCurveTo(source.x - bend * 0.35, seam,
                source.x, shoulderY - bend * 0.55, source.x, shoulderY);
            ctx.lineTo(source.x, seam);
            ctx.closePath();
            ctx.moveTo(source.x + source.width + spread, seam);
            ctx.bezierCurveTo(source.x + source.width + bend * 0.35, seam,
                source.x + source.width, shoulderY - bend * 0.55,
                source.x + source.width, shoulderY);
            ctx.lineTo(source.x + source.width, seam);
            ctx.closePath();
        }
        roundedRect(ctx, source.x, source.y, source.width, source.height, sr);
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (!visible)
            return;

        const g = geometry;
        ctx.beginPath();
        roundedRect(ctx, g.x, g.y, g.width, g.height, g.radius);
        if (attached && g.amount > 0.08)
            outwardShoulders(ctx, g, g.origin);
        ctx.fillStyle = fillColor;
        ctx.fill();
    }
}
