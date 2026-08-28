import QtQuick
import "../.."

Canvas {
    id: root

    readonly property var layout: parent.layout
    readonly property real reveal: parent.reveal
    readonly property color tone: parent.tone
    readonly property string tab: parent.tab

    readonly property real sourceWidth: tab === "media" ? 132
        : tab === "calendar" ? 154 : 48
    readonly property real sourceX: {
        if (tab === "calendar")
            return Math.round((width - sourceWidth) / 2);
        if (tab === "notifications" || tab === "network" || tab === "audio"
                || tab === "battery" || tab === "settings" || tab === "tools")
            return width - sourceWidth - Math.max(10, Settings.barMargin);
        if (tab === "media")
            return 248;
        if (tab === "workspaces")
            return 160;
        if (tab === "walls")
            return 72;
        if (tab === "apps")
            return 42;
        return Math.max(10, Settings.barMargin);
    }
    readonly property real sourceY: Settings.barMode === "docked"
        ? 2 : Math.max(4, Settings.barMargin)
    readonly property real sourceHeight: Settings.compact ? 34 : Theme.barHeight

    antialiasing: true

    function mix(from, to, amount) {
        return from + (to - from) * amount;
    }

    function rgba(color, alpha) {
        return "rgba(" + Math.round(color.r * 255) + ","
            + Math.round(color.g * 255) + ","
            + Math.round(color.b * 255) + "," + alpha + ")";
    }

    function roundedRect(ctx, x, y, width, height, radius) {
        const r = Math.min(radius, width / 2, height / 2);
        ctx.beginPath();
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
        if (root.tab === "walls")
            return;

        const eased = 1 - Math.pow(1 - Math.max(0, Math.min(1, root.reveal)), 4);
        const x = mix(root.sourceX, root.layout.x, eased);
        const y = mix(root.sourceY, root.layout.y, eased);
        const w = mix(root.sourceWidth, root.layout.width, eased);
        const h = mix(root.sourceHeight, root.layout.height, eased);
        const radius = mix(root.sourceHeight / 2, 26, eased);
        const fill = rgba(Theme.mantle, 0.985);

        // The neck is deliberately short-lived: it makes the surface feel as
        // though it escaped Aperture without leaving a permanent ornament.
        const neck = Math.sin(Math.min(1, root.reveal / 0.82) * Math.PI);
        if (neck > 0.02) {
            const sourceCx = root.sourceX + root.sourceWidth / 2;
            const sourceCy = root.sourceY + root.sourceHeight / 2;
            const targetCx = x + Math.min(w * 0.24, 180);
            const targetCy = y + Math.min(h * 0.18, 96);
            const spread = mix(root.sourceHeight * 0.22, 42, eased) * neck;
            ctx.fillStyle = fill;
            ctx.beginPath();
            ctx.moveTo(sourceCx - spread, sourceCy);
            ctx.bezierCurveTo(sourceCx, sourceCy + spread * 2,
                targetCx - spread * 2.4, targetCy, targetCx, targetCy + spread);
            ctx.bezierCurveTo(targetCx + spread * 1.5, targetCy,
                sourceCx, sourceCy - spread * 2, sourceCx - spread, sourceCy);
            ctx.fill();
        }

        ctx.fillStyle = fill;
        roundedRect(ctx, x, y, w, h, radius);
        ctx.fill();

        const pulse = Math.max(0, 1 - Math.abs(root.reveal - 0.58) * 2.3);
        if (pulse > 0) {
            ctx.fillStyle = rgba(root.tone, pulse * 0.055);
            ctx.beginPath();
            ctx.arc(x + w * 0.14, y + h * 0.16,
                Math.max(28, Math.min(w, h) * 0.18), 0, Math.PI * 2);
            ctx.fill();
        }
    }

    Connections {
        target: root
        function onRevealChanged() { root.requestPaint(); }
        function onLayoutChanged() { root.requestPaint(); }
        function onToneChanged() { root.requestPaint(); }
        function onTabChanged() { root.requestPaint(); }
    }
    Connections {
        target: Theme
        function onMantleChanged() { root.requestPaint(); }
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()
}
