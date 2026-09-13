import QtQuick
import ".."

// A solid instrument grown inward from the fluid beyond a monitor edge.
// The leading edge deforms during deployment; content stays stable above it.
Canvas {
    id: root

    property string edge: "bottom"
    property real reveal: 1
    property real energy: 0
    property real cursorAlong: 0.5
    property color fillColor: Theme.mantle

    antialiasing: true
    opacity: Math.max(0, Math.min(1, reveal))

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onRevealChanged: requestPaint()
    onEnergyChanged: requestPaint()
    onCursorAlongChanged: requestPaint()
    onFillColorChanged: requestPaint()

    function clamp(value, low, high) {
        return Math.max(low, Math.min(high, value));
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (width < 2 || height < 2 || reveal <= 0.001)
            return;

        const p = root.clamp(reveal, 0, 1);
        const deployment = Math.sin(p * Math.PI);
        const impulse = root.clamp(Math.abs(energy), 0, 1);
        const radius = 26;
        ctx.fillStyle = fillColor.toString();
        ctx.beginPath();

        if (edge === "right") {
            const lead = 18 + deployment * 18;
            const cy = root.clamp(cursorAlong, 0.12, 0.88) * height;
            const swell = 16 + deployment * 28 + impulse * 12;
            ctx.moveTo(width, 0);
            ctx.lineTo(lead + radius, 0);
            ctx.quadraticCurveTo(lead, 0, lead, radius);
            ctx.lineTo(lead, Math.max(radius, cy - swell));
            ctx.bezierCurveTo(lead, cy - swell * 0.45, Math.max(0, lead - swell), cy - swell * 0.45, Math.max(0, lead - swell), cy);
            ctx.bezierCurveTo(Math.max(0, lead - swell), cy + swell * 0.45, lead, cy + swell * 0.45, lead, Math.min(height - radius, cy + swell));
            ctx.lineTo(lead, height - radius);
            ctx.quadraticCurveTo(lead, height, lead + radius, height);
            ctx.lineTo(width, height);
        } else {
            const lead = 18 + deployment * 18;
            const cx = root.clamp(cursorAlong, 0.1, 0.9) * width;
            const swell = 18 + deployment * 30 + impulse * 12;
            ctx.moveTo(0, height);
            ctx.lineTo(0, lead + radius);
            ctx.quadraticCurveTo(0, lead, radius, lead);
            ctx.lineTo(Math.max(radius, cx - swell), lead);
            ctx.bezierCurveTo(cx - swell * 0.45, lead, cx - swell * 0.45, Math.max(0, lead - swell), cx, Math.max(0, lead - swell));
            ctx.bezierCurveTo(cx + swell * 0.45, Math.max(0, lead - swell), cx + swell * 0.45, lead, Math.min(width - radius, cx + swell), lead);
            ctx.lineTo(width - radius, lead);
            ctx.quadraticCurveTo(width, lead, width, lead + radius);
            ctx.lineTo(width, height);
        }

        ctx.closePath();
        ctx.fill();
    }
}
