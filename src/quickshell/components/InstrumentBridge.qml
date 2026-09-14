import QtQuick
import ".."

// One backing surface that grows from an instrument's source bounds. The final
// body is deliberately sunk beneath Aperture's source capsule: Aperture is the
// visible cap and this surface is the expansion behind it. Keeping the final
// silhouette to one rounded body avoids rotation-specific connector artifacts.
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

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (!visible)
            return;

        const g = geometry;
        ctx.beginPath();
        roundedRect(ctx, g.x, g.y, g.width, g.height, g.radius);
        ctx.fillStyle = fillColor;
        ctx.fill();
    }
}
