import QtQuick
import "../.."

// One backing for every bar island while arranging. Drawing all droplets into
// one canvas lets nearby islands merge without outlines or competing layers.
Canvas {
    id: root

    required property var bar
    property color fillColor: Theme.void_

    anchors.fill: parent
    antialiasing: true
    visible: ShellState.barEditMode && bar.capsules

    onVisibleChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onFillColorChanged: requestPaint()

    Connections {
        target: ShellState
        function onDragGlobalXChanged() { root.requestPaint(); }
        function onDragGlobalYChanged() { root.requestPaint(); }
        function onDragVelocityXChanged() { root.requestPaint(); }
        function onDragVelocityYChanged() { root.requestPaint(); }
        function onIsDraggingIslandChanged() { root.requestPaint(); }
    }

    // Geometry only animates while the studio is open. A short edit-session
    // ticker keeps bridges and necks attached while layouts settle without
    // imposing a permanent render cost on the shell.
    Timer {
        interval: 16
        repeat: true
        running: root.visible
        onTriggered: root.requestPaint()
    }
    Connections {
        target: Settings
        function onBarIslandSpacingChanged() { root.requestPaint(); }
        function onBarPositionChanged() { root.requestPaint(); }
    }

    function roundedRect(ctx, x, y, w, h, r) {
        const rr = Math.max(1, Math.min(r, w / 2, h / 2));
        ctx.moveTo(x + rr, y);
        ctx.lineTo(x + w - rr, y);
        ctx.quadraticCurveTo(x + w, y, x + w, y + rr);
        ctx.lineTo(x + w, y + h - rr);
        ctx.quadraticCurveTo(x + w, y + h, x + w - rr, y + h);
        ctx.lineTo(x + rr, y + h);
        ctx.quadraticCurveTo(x, y + h, x, y + h - rr);
        ctx.lineTo(x, y + rr);
        ctx.quadraticCurveTo(x, y, x + rr, y);
        ctx.closePath();
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (!visible)
            return;

        const rects = bar.islandRects();
        const speed = Math.min(26, Math.sqrt(ShellState.dragVelocityX * ShellState.dragVelocityX
            + ShellState.dragVelocityY * ShellState.dragVelocityY) * 0.16);
        const bridgeInset = Math.max(3, 6 - speed * 0.1);
        ctx.fillStyle = fillColor.toString();
        ctx.beginPath();

        for (let i = 0; i < rects.length; ++i) {
            const rect = rects[i];
            roundedRect(ctx, rect.x, rect.y, rect.width, rect.height, Math.min(14, rect.height / 2));

            // Each droplet has a neck continuing beyond the monitor edge.
            if (bar.effectivePosition === "top")
                ctx.rect(rect.x + Math.min(18, rect.width * 0.22), 0, Math.max(2, rect.width - Math.min(36, rect.width * 0.44)), rect.y + 5);
            else if (bar.effectivePosition === "bottom")
                ctx.rect(rect.x + Math.min(18, rect.width * 0.22), rect.y + rect.height - 5, Math.max(2, rect.width - Math.min(36, rect.width * 0.44)), height - rect.y - rect.height + 5);
            else if (bar.effectivePosition === "left")
                ctx.rect(0, rect.y + Math.min(18, rect.height * 0.22), rect.x + 5, Math.max(2, rect.height - Math.min(36, rect.height * 0.44)));
            else
                ctx.rect(rect.x + rect.width - 5, rect.y + Math.min(18, rect.height * 0.22), width - rect.x - rect.width + 5, Math.max(2, rect.height - Math.min(36, rect.height * 0.44)));

            // Nearby droplets share matter instead of showing seams.
            if (i + 1 < rects.length) {
                const next = rects[i + 1];
                if (!bar.isVertical) {
                    const gap = next.x - (rect.x + rect.width);
                    if (gap >= 0 && gap <= Settings.barIslandSpacing + 18)
                        ctx.rect(rect.x + rect.width - 3, Math.max(rect.y, next.y) + bridgeInset,
                            gap + 6, Math.max(2, Math.min(rect.height, next.height) - bridgeInset * 2));
                } else {
                    const gap = next.y - (rect.y + rect.height);
                    if (gap >= 0 && gap <= Settings.barIslandSpacing + 18)
                        ctx.rect(Math.max(rect.x, next.x) + bridgeInset, rect.y + rect.height - 3,
                            Math.max(2, Math.min(rect.width, next.width) - bridgeInset * 2), gap + 6);
                }
            }
        }

        ctx.fill();
    }
}
