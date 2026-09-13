import QtQuick
import ".."

// One backing surface for an instrument and its attachment lip. Keeping both
// shapes in a single Canvas fill prevents translucent overlap seams: alpha is
// applied once to the complete silhouette, as it would be in an SDF blob group.
Canvas {
    id: root
    required property var geometry
    property string edge: "top"
    property color fillColor: Theme.mantle
    property bool attached: true

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

    function verticalLip(ctx, sourceX, sourceY, landingX, landingY,
            sourceHalf, landingHalf) {
        const distance = landingY - sourceY;
        if (Math.abs(distance) < 0.5)
            return;
        const controlOne = sourceY + distance * 0.22;
        const controlTwo = sourceY + distance * 0.70;
        ctx.moveTo(sourceX - sourceHalf, sourceY);
        ctx.bezierCurveTo(sourceX - sourceHalf, controlOne,
            landingX - landingHalf, controlTwo, landingX - landingHalf, landingY);
        ctx.lineTo(landingX + landingHalf, landingY);
        ctx.bezierCurveTo(landingX + landingHalf, controlTwo,
            sourceX + sourceHalf, controlOne, sourceX + sourceHalf, sourceY);
        ctx.quadraticCurveTo(sourceX, sourceY - Math.sign(distance) * sourceHalf * 0.35,
            sourceX - sourceHalf, sourceY);
    }

    function horizontalLip(ctx, sourceX, sourceY, landingX, landingY,
            sourceHalf, landingHalf) {
        const distance = landingX - sourceX;
        if (Math.abs(distance) < 0.5)
            return;
        const controlOne = sourceX + distance * 0.22;
        const controlTwo = sourceX + distance * 0.70;
        ctx.moveTo(sourceX, sourceY - sourceHalf);
        ctx.bezierCurveTo(controlOne, sourceY - sourceHalf,
            controlTwo, landingY - landingHalf, landingX, landingY - landingHalf);
        ctx.lineTo(landingX, landingY + landingHalf);
        ctx.bezierCurveTo(controlTwo, landingY + landingHalf,
            controlOne, sourceY + sourceHalf, sourceX, sourceY + sourceHalf);
        ctx.quadraticCurveTo(sourceX - Math.sign(distance) * sourceHalf * 0.35,
            sourceY, sourceX, sourceY - sourceHalf);
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (!visible)
            return;

        const g = geometry;
        const source = g.origin;
        const amount = g.amount;
        const sourceHalf = Math.max(8, Math.min(28,
            (edge === "top" || edge === "bottom" ? source.width : source.height) * 0.42));
        const landingHalf = sourceHalf + 10 + amount * 10;
        const overlap = 6;

        ctx.beginPath();
        roundedRect(ctx, g.x, g.y, g.width, g.height, g.radius);

        if (!attached) {
            ctx.fillStyle = fillColor;
            ctx.fill();
            return;
        }

        if (edge === "bottom") {
            const sx = source.x + source.width / 2;
            const sy = source.y + overlap;
            const dx = clamp(sx, g.x + g.radius, g.x + g.width - g.radius);
            verticalLip(ctx, sx, sy, dx, g.y + g.height - overlap, sourceHalf, landingHalf);
        } else if (edge === "left") {
            const sx = source.x + source.width - overlap;
            const sy = source.y + source.height / 2;
            const dy = clamp(sy, g.y + g.radius, g.y + g.height - g.radius);
            horizontalLip(ctx, sx, sy, g.x + overlap, dy, sourceHalf, landingHalf);
        } else if (edge === "right") {
            const sx = source.x + overlap;
            const sy = source.y + source.height / 2;
            const dy = clamp(sy, g.y + g.radius, g.y + g.height - g.radius);
            horizontalLip(ctx, sx, sy, g.x + g.width - overlap, dy, sourceHalf, landingHalf);
        } else {
            const sx = source.x + source.width / 2;
            const sy = source.y + source.height - overlap;
            const dx = clamp(sx, g.x + g.radius, g.x + g.width - g.radius);
            verticalLip(ctx, sx, sy, dx, g.y + overlap, sourceHalf, landingHalf);
        }
        ctx.fillStyle = fillColor;
        ctx.fill();
    }
}
