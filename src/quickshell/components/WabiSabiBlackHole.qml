// Tonantzintla's project mark: one imperfect gravitational stream folding around
// a displaced void. Runtime surfaces import this exact silhouette so the logo
// does not drift into a generic ringed black hole.
import QtQuick
import "../.."

Item {
    id: root

    property color diskColor: Theme.accent
    property color horizonColor: "#000000"

    implicitWidth: 300
    implicitHeight: 156

    Canvas {
        id: glyph
        anchors.fill: parent
        antialiasing: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: root
            function onDiskColorChanged() { glyph.requestPaint(); }
            function onHorizonColorChanged() { glyph.requestPaint(); }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const cx = width * 0.50;
            const cy = height * 0.43;
            const unit = Math.min(width / 360, height / 270);

            ctx.save();
            ctx.translate(cx, cy);
            ctx.fillStyle = root.diskColor.toString();

            // One gravitationally warped stream climbs over the horizon,
            // pinches at the right edge, and returns across the foreground.
            ctx.beginPath();
            ctx.moveTo(-151 * unit, 59 * unit);
            ctx.bezierCurveTo(-119 * unit, 33 * unit,
                -91 * unit, 5 * unit,
                -75 * unit, -37 * unit);
            ctx.bezierCurveTo(-54 * unit, -91 * unit,
                5 * unit, -109 * unit,
                57 * unit, -78 * unit);
            ctx.bezierCurveTo(84 * unit, -62 * unit,
                92 * unit, -35 * unit,
                112 * unit, -24 * unit);
            ctx.bezierCurveTo(130 * unit, -14 * unit,
                156 * unit, -19 * unit,
                164 * unit, -6 * unit);
            ctx.bezierCurveTo(175 * unit, 13 * unit,
                142 * unit, 33 * unit,
                113 * unit, 48 * unit);
            ctx.bezierCurveTo(58 * unit, 76 * unit,
                -9 * unit, 93 * unit,
                -74 * unit, 98 * unit);
            ctx.bezierCurveTo(-120 * unit, 101 * unit,
                -167 * unit, 92 * unit,
                -168 * unit, 75 * unit);
            ctx.bezierCurveTo(-169 * unit, 68 * unit,
                -160 * unit, 63 * unit,
                -151 * unit, 59 * unit);
            ctx.closePath();
            ctx.fill();

            ctx.fillStyle = root.horizonColor.toString();
            ctx.beginPath();
            ctx.moveTo(-49 * unit, -56 * unit);
            ctx.bezierCurveTo(-16 * unit, -77 * unit,
                34 * unit, -72 * unit,
                62 * unit, -43 * unit);
            ctx.bezierCurveTo(82 * unit, -21 * unit,
                83 * unit, 12 * unit,
                68 * unit, 39 * unit);
            ctx.bezierCurveTo(49 * unit, 72 * unit,
                5 * unit, 82 * unit,
                -37 * unit, 73 * unit);
            ctx.bezierCurveTo(-69 * unit, 66 * unit,
                -79 * unit, 36 * unit,
                -75 * unit, 5 * unit);
            ctx.bezierCurveTo(-72 * unit, -24 * unit,
                -63 * unit, -47 * unit,
                -49 * unit, -56 * unit);
            ctx.closePath();
            ctx.fill();

            ctx.fillStyle = root.diskColor.toString();
            ctx.beginPath();
            ctx.moveTo(-160 * unit, 68 * unit);
            ctx.bezierCurveTo(-90 * unit, 90 * unit,
                0 * unit, 82 * unit,
                81 * unit, 51 * unit);
            ctx.bezierCurveTo(113 * unit, 39 * unit,
                141 * unit, 25 * unit,
                161 * unit, 7 * unit);
            ctx.bezierCurveTo(145 * unit, 36 * unit,
                112 * unit, 56 * unit,
                76 * unit, 71 * unit);
            ctx.bezierCurveTo(-4 * unit, 104 * unit,
                -98 * unit, 112 * unit,
                -160 * unit, 88 * unit);
            ctx.bezierCurveTo(-171 * unit, 83 * unit,
                -171 * unit, 74 * unit,
                -160 * unit, 68 * unit);
            ctx.closePath();
            ctx.fill();

            // Detached lower lens: crude today, useful identity tomorrow.
            ctx.beginPath();
            ctx.moveTo(-21 * unit, 112 * unit);
            ctx.bezierCurveTo(16 * unit, 132 * unit,
                59 * unit, 129 * unit,
                86 * unit, 96 * unit);
            ctx.bezierCurveTo(73 * unit, 133 * unit,
                27 * unit, 151 * unit,
                -35 * unit, 120 * unit);
            ctx.closePath();
            ctx.fill();
            ctx.restore();
        }
    }
}
