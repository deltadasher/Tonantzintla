import QtQuick
import "../.."

// Conway's Game of Life on a wrapping grid. The board is painted one pixel per
// cell and scaled up, so a full screen costs a few thousand fills per generation.
// Moving the pointer seeds cells; a click drops a larger burst.
Item {
    id: scene
    property var values: ({})
    property bool running: true
    property point pointer: Qt.point(-1, -1)
    property bool pointerActive: false

    readonly property int cell: Math.max(3, Math.round(Number(values.cell) || 9))
    readonly property int speed: Math.max(1, Math.round(Number(values.speed) || 12))
    readonly property int cols: Math.max(8, Math.ceil(width / cell))
    readonly property int rows: Math.max(8, Math.ceil(height / cell))
    property var cur: null
    property var next: null
    property var age: null
    property int stagnant: 0
    property int lastPopulation: -1

    function reset() {
        const size = cols * rows;
        const board = new Uint8Array(size);
        for (let i = 0; i < size; ++i) board[i] = Math.random() < 0.18 ? 1 : 0;
        cur = board; next = new Uint8Array(size); age = new Uint16Array(size);
        stagnant = 0; lastPopulation = -1;
        view.requestPaint();
    }

    function sprinkle(cx, cy, radius, chance) {
        if (!cur) return;
        for (let dy = -radius; dy <= radius; ++dy)
            for (let dx = -radius; dx <= radius; ++dx)
                if (dx * dx + dy * dy <= radius * radius && Math.random() < chance)
                    cur[((cy + dy + rows) % rows) * cols + (cx + dx + cols) % cols] = 1;
    }

    function step() {
        if (!cur || cur.length !== cols * rows) { reset(); return; }
        const a = cur, b = next, ages = age, w = cols, h = rows;
        let population = 0;
        for (let y = 0; y < h; ++y) {
            const up = ((y - 1 + h) % h) * w, mid = y * w, down = ((y + 1) % h) * w;
            for (let x = 0; x < w; ++x) {
                const l = (x - 1 + w) % w, r = (x + 1) % w;
                const n = a[up + l] + a[up + x] + a[up + r] + a[mid + l] + a[mid + r] + a[down + l] + a[down + x] + a[down + r];
                const i = mid + x, alive = n === 3 || (n === 2 && a[i]) ? 1 : 0;
                b[i] = alive;
                ages[i] = alive ? Math.min(ages[i] + 1, 400) : 0;
                population += alive;
            }
        }
        cur = b; next = a;
        // Once the board settles into still lifes and blinkers, stir it again.
        stagnant = Math.abs(population - lastPopulation) <= 2 ? stagnant + 1 : 0;
        lastPopulation = population;
        if (stagnant > 90 || population < cur.length * 0.01) {
            for (let k = 0; k < 6; ++k)
                sprinkle(Math.floor(Math.random() * w), Math.floor(Math.random() * h), 7, 0.4);
            stagnant = 0;
        }
    }

    function pulse(x, y) {
        sprinkle(Math.floor(x / cell), Math.floor(y / cell), 10, 0.45);
        view.requestPaint();
    }
    onPointerChanged: if (pointerActive && running) sprinkle(Math.floor(pointer.x / cell), Math.floor(pointer.y / cell), 2, 0.5)
    onColsChanged: reset()
    onRowsChanged: reset()
    Component.onCompleted: reset()

    Rectangle { anchors.fill: parent; color: Theme.void_ }

    Canvas {
        id: view
        width: scene.cols; height: scene.rows
        scale: scene.cell; transformOrigin: Item.TopLeft
        smooth: false; antialiasing: false
        readonly property var tones: [
            String(Qt.lighter(Theme.accent, 1.45)), String(Theme.accent), String(Theme.cyan),
            String(Theme.muted), String(Qt.darker(Theme.muted, 1.9))
        ]
        onTonesChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.fillStyle = String(Theme.void_);
            ctx.fillRect(0, 0, width, height);
            const board = scene.cur, ages = scene.age, w = scene.cols;
            if (!board) return;
            // Bucket by age so the fill style changes five times, not per cell.
            const buckets = [[], [], [], [], []];
            for (let i = 0; i < board.length; ++i) {
                if (!board[i]) continue;
                const a = ages[i];
                buckets[a < 2 ? 0 : a < 6 ? 1 : a < 20 ? 2 : a < 80 ? 3 : 4].push(i);
            }
            for (let b = 0; b < 5; ++b) {
                ctx.fillStyle = tones[b];
                const cells = buckets[b];
                for (let k = 0; k < cells.length; ++k)
                    ctx.fillRect(cells[k] % w, Math.floor(cells[k] / w), 1, 1);
            }
        }
    }

    Timer {
        interval: Math.round(1000 / scene.speed); repeat: true
        running: scene.running && scene.visible
        onTriggered: { scene.step(); view.requestPaint(); }
    }
}
