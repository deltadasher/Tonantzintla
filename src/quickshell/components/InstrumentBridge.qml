import QtQuick
import ".."

// A bounded visual neck between a real bar control and its instrument. The
// fullscreen host remains fixed; only this canvas and the internal deck move.
Canvas {
    id: root
    required property var geometry
    property string edge: "top"

    antialiasing: true
    onVisibleChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onEdgeChanged: requestPaint()

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

    function verticalNeck(ctx, sourceX, sourceY, landingX, landingY,
            sourceHalf, landingHalf) {
        const distance = landingY - sourceY;
        if (Math.abs(distance) < 0.5)
            return;
        const controlOne = sourceY + distance * 0.38;
        const controlTwo = sourceY + distance * 0.72;
        ctx.moveTo(sourceX - sourceHalf, sourceY);
        ctx.bezierCurveTo(sourceX - sourceHalf, controlOne,
            landingX - landingHalf, controlTwo, landingX - landingHalf, landingY);
        ctx.lineTo(landingX + landingHalf, landingY);
        ctx.bezierCurveTo(landingX + landingHalf, controlTwo,
            sourceX + sourceHalf, controlOne, sourceX + sourceHalf, sourceY);
        ctx.quadraticCurveTo(sourceX, sourceY - Math.sign(distance) * sourceHalf * 0.35,
            sourceX - sourceHalf, sourceY);
    }

    function horizontalNeck(ctx, sourceX, sourceY, landingX, landingY,
            sourceHalf, landingHalf) {
        const distance = landingX - sourceX;
        if (Math.abs(distance) < 0.5)
            return;
        const controlOne = sourceX + distance * 0.38;
        const controlTwo = sourceX + distance * 0.72;
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
        const sourceHalf = Math.max(4, Math.min(11,
            (edge === "top" || edge === "bottom" ? source.width : source.height) * 0.22));
        const landingHalf = 7 + amount * 9;

        ctx.beginPath();
        if (edge === "bottom") {
            const sx = source.x + source.width / 2;
            const sy = source.y;
            const dx = clamp(sx, g.x + g.radius, g.x + g.width - g.radius);
            verticalNeck(ctx, sx, sy, dx, g.y + g.height, sourceHalf, landingHalf);
        } else if (edge === "left") {
            const sx = source.x + source.width;
            const sy = source.y + source.height / 2;
            const dy = clamp(sy, g.y + g.radius, g.y + g.height - g.radius);
            horizontalNeck(ctx, sx, sy, g.x, dy, sourceHalf, landingHalf);
        } else if (edge === "right") {
            const sx = source.x;
            const sy = source.y + source.height / 2;
            const dy = clamp(sy, g.y + g.radius, g.y + g.height - g.radius);
            horizontalNeck(ctx, sx, sy, g.x + g.width, dy, sourceHalf, landingHalf);
        } else {
            const sx = source.x + source.width / 2;
            const sy = source.y + source.height;
            const dx = clamp(sx, g.x + g.radius, g.x + g.width - g.radius);
            verticalNeck(ctx, sx, sy, dx, g.y, sourceHalf, landingHalf);
        }
        ctx.closePath();
        ctx.fillStyle = Theme.mantle;
        ctx.fill();
    }
}
