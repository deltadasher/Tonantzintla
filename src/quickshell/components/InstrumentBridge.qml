import QtQuick
import ".."

// An original curved attachment, not Caelestia's SDF renderer. Experimental
// until checked on the live compositor. Geometry and the body share progress.
Canvas {
    id: root
    required property var geometry
    visible: geometry.motion && geometry.amount > 0.01 && geometry.amount < 0.99
    antialiasing: true
    onVisibleChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Connections {
        target: root.geometry
        function onProgressChanged() { root.requestPaint(); }
        function onDestinationChanged() { root.requestPaint(); }
    }
    Connections { target: Theme; function onMantleChanged() { root.requestPaint(); } }
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const g = geometry;
        if (!visible) return;
        const source = g.origin;
        const center = source.x + source.width / 2;
        const top = source.y + source.height / 2;
        const bottom = g.y + Math.min(g.height / 2, g.radius + 8);
        const neck = Math.max(2, source.width / 2 * (1 - g.amount));
        const landing = Math.max(g.x + g.radius, Math.min(g.x + g.width - g.radius, center));
        const spread = Math.max(0, Math.min(g.width / 2 - g.radius, neck + 26 * Math.sin(g.amount * Math.PI)));
        const middle = top + (bottom - top) * 0.6;
        ctx.beginPath();
        ctx.moveTo(center - neck, top);
        ctx.bezierCurveTo(center - neck, middle, landing - spread, middle, landing - spread, bottom);
        ctx.lineTo(landing + spread, bottom);
        ctx.bezierCurveTo(landing + spread, middle, center + neck, middle, center + neck, top);
        ctx.quadraticCurveTo(center, top - neck, center - neck, top);
        ctx.closePath();
        ctx.fillStyle = Theme.mantle;
        ctx.fill();
    }
}
