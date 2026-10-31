.pragma library

// Button shapes, icons and password lines for the identity lock and login
// screens. Same language as the scenes: flat fills, rounded joins, no text
// glyphs that a font might lack. Each painter is pure; hosts repaint on change.

function rgba(c, alpha) {
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
        + Math.round(c.b * 255) + "," + (alpha === undefined ? c.a : alpha) + ")";
}

// ---------------------------------------------------------------- button shapes
// Paths are the approved marks' outlines in their 128-unit viewBox. bounds are
// the painted bounds after transform; glyph is where an icon sits inside.
var SHAPES = {
    circle: { paths: [["c", 64, 64, 58]], bounds: [6, 6, 116, 116], glyph: [64, 64, .42] },
    shard: { paths: ["M21 40 35 25Q37 23 40 23H88Q91 23 93 25L108 41Q110 43 108 46L67 101Q64 105 61 101L20 46Q18 43 21 40Z"],
             transform: [-10, 10, 45], bounds: [23.4, 23.6, 81, 81], glyph: [60, 66, .3] },
    shell: { paths: ["M48 98C30 86 13 66 14 53 14 42 23 37 30 42 27 26 43 19 51 29 51 10 77 10 77 29 85 19 101 26 98 42 105 37 114 42 114 53 115 66 98 86 80 98L82 105Q84 108 80 109Q64 115 48 109Q44 108 46 105Z"],
             bounds: [11.7, 12.5, 104.6, 101.8], glyph: [64, 58, .34] },
    flame: { paths: ["M69 11C72 35 98 43 103 66 110 95 91 115 65 115 36 115 18 96 23 71 26 57 37 48 39 37 47 43 49 53 48 61 62 49 67 32 69 11Z"],
             bounds: [19.9, 8.8, 86.9, 108.5], glyph: [64, 84, .3] },
    sun: { paths: ["rays", ["c", 64, 64, 28]], bounds: [6.4, 6.4, 115.3, 115.3], glyph: [64, 64, .26] },
    leaf: { paths: ["M104 18Q108 17 108 21C109 56 97 82 73 91 61 95 50 93 42 88L28 105Q26 108 23 105L20 102Q17 100 20 97L35 80C23 62 28 43 47 31 63 21 82 20 104 18Z"],
            bounds: [16.3, 15.6, 94, 93.1], glyph: [70, 54, .3] },
    hexagon: { paths: ["M60 14Q64 12 68 14L107 37Q111 39 111 44L111 86Q111 90 107 92L68 114Q64 116 60 114L21 92Q17 90 17 86L17 44Q17 39 21 37Z"],
               bounds: [14.8, 10.8, 98.5, 106.5], glyph: [64, 64, .36] },
    drop: { paths: ["M62 16Q65 10 68 16C80 36 104 56 104 78 104 100 88 116 65 116 42 116 25 101 25 78 25 56 53 34 62 16Z"],
            bounds: [22.8, 10.8, 83.5, 107.5], glyph: [64, 82, .32] },
    planet: { paths: [["e", 64, 64, 57, 18], ["c", 64, 64, 36]], transform: [0, 0, -24],
              bounds: [9.2, 26.8, 109.8, 74.5], glyph: [64, 64, .26] },
    star: { paths: ["M64 4L82 46L124 64L82 82L64 124L46 82L4 64L46 46Z"], bounds: [4, 4, 120, 120], glyph: [64, 64, .26] },
    rosette: { paths: [["c", 64, 30, 26], ["c", 93, 47, 26], ["c", 93, 81, 26], ["c", 64, 98, 26],
                       ["c", 35, 81, 26], ["c", 35, 47, 26], ["c", 64, 64, 36]],
               bounds: [9, 4, 110, 120], glyph: [64, 64, .34] },
    halfMoon: { paths: ["M38 8A56 56 0 0 1 38 120Z"], bounds: [38, 8, 56, 112], glyph: [58, 64, .3] },
    cloud: { paths: ["M32 98C18 98 9 89 11 77 13 65 22 59 33 61 32 41 46 27 64 29 79 30 89 41 91 54 106 52 118 63 117 77 116 90 106 98 93 98Z"],
             bounds: [8.4, 26.6, 110.9, 73.7], glyph: [64, 72, .3] },
    seal: { paths: ["M36 12L92 12Q116 12 116 36L116 92Q116 116 92 116L36 116Q12 116 12 92L12 36Q12 12 36 12Z"],
            bounds: [12, 12, 104, 104], glyph: [64, 64, .38] }
};

function fit(shape, size) {
    const b = SHAPES[shape].bounds, pad = size * .06;
    const k = (size - 2 * pad) / Math.max(b[2], b[3]);
    return { k: k, x: pad + ((size - 2 * pad) - b[2] * k) / 2 - b[0] * k,
             y: pad + ((size - 2 * pad) - b[3] * k) / 2 - b[1] * k };
}
// Where an icon belongs inside a shape painted at this size: [x, y, radius].
function glyph(shape, size) {
    const s = SHAPES[shape] || SHAPES.circle, f = fit(shape in SHAPES ? shape : "circle", size);
    return [f.x + s.glyph[0] * f.k, f.y + s.glyph[1] * f.k, size * s.glyph[2]];
}
function paintShape(c, shape, size, fill) {
    if (!(shape in SHAPES)) shape = "circle";
    const s = SHAPES[shape], f = fit(shape, size);
    c.save();
    c.translate(f.x, f.y);
    c.scale(f.k, f.k);
    if (s.transform) {
        c.translate(s.transform[0], s.transform[1]);
        c.translate(64, 64); c.rotate(s.transform[2] * Math.PI / 180); c.translate(-64, -64);
    }
    c.fillStyle = fill; c.strokeStyle = fill;
    c.lineJoin = "round"; c.lineWidth = 2.5;
    for (let i = 0; i < s.paths.length; i++) {
        const p = s.paths[i];
        c.beginPath();
        if (p === "rays") {
            for (let r = 0; r < 8; r++) {
                c.save(); c.translate(64, 64); c.rotate(r * Math.PI / 4); c.translate(-64, -64);
                c.beginPath(); c.path = "M59 12Q64 5 69 12L68 42L60 42Z"; c.fill(); c.stroke();
                c.restore();
            }
            continue;
        }
        if (typeof p === "string") c.path = p;
        else if (p[0] === "c") c.ellipse(p[1] - p[3], p[2] - p[3], p[3] * 2, p[3] * 2);
        else c.ellipse(p[1] - p[3], p[2] - p[4], p[3] * 2, p[4] * 2);
        c.fill(); c.stroke();
    }
    c.restore();
}

// ---------------------------------------------------------------- icons
function paintIcon(c, icon, x, y, r, color) {
    c.save();
    c.strokeStyle = color; c.fillStyle = color;
    c.lineCap = "round"; c.lineJoin = "round"; c.lineWidth = Math.max(1.5, r * .24);
    c.beginPath();
    if (icon === "enter") {
        c.moveTo(x - r * .62, y); c.lineTo(x + r * .58, y);
        c.moveTo(x + r * .08, y - r * .5); c.lineTo(x + r * .6, y); c.lineTo(x + r * .08, y + r * .5);
        c.stroke();
    } else if (icon === "busy") {
        for (let i = -1; i <= 1; i++) { c.moveTo(x + i * r * .5 + r * .12, y); c.arc(x + i * r * .5, y, r * .12, 0, Math.PI * 2); }
        c.fill();
    } else if (icon === "power") {
        c.arc(x, y + r * .06, r * .62, -Math.PI * .32, Math.PI * 1.32);
        c.moveTo(x, y - r * .78); c.lineTo(x, y - r * .08);
        c.stroke();
    } else if (icon === "restart") {
        c.arc(x, y, r * .62, -Math.PI * .4, Math.PI * 1.35);
        c.stroke();
        const a = -Math.PI * .4, tx = x + r * .62 * Math.cos(a), ty = y + r * .62 * Math.sin(a);
        c.beginPath();
        c.moveTo(tx - r * .42, ty - r * .16); c.lineTo(tx, ty); c.lineTo(tx - r * .12, ty + r * .4);
        c.stroke();
    } else if (icon === "sleep") {
        c.path = "M" + (x + r * .3) + " " + (y - r * .66)
            + "A" + (r * .7) + " " + (r * .7) + " 0 1 0 " + (x + r * .64) + " " + (y + r * .3)
            + "A" + (r * .58) + " " + (r * .58) + " 0 0 1 " + (x + r * .3) + " " + (y - r * .66) + "Z";
        c.fill();
    }
    c.restore();
}

// ---------------------------------------------------------------- password lines
// Deterministic jitter, so a glyph never moves as more are typed.
function hash(i, salt) { const v = Math.sin((i + 1) * 12.9898 + salt * 78.233) * 43758.5453; return v - Math.floor(v); }

var LEAF = "M104 18Q108 17 108 21C109 56 97 82 73 91 61 95 50 93 42 88L28 105Q26 108 23 105L20 102Q17 100 20 97L35 80C23 62 28 43 47 31 63 21 82 20 104 18Z";
var DROP = "M62 16Q65 10 68 16C80 36 104 56 104 78 104 100 88 116 65 116 42 116 25 101 25 78 25 56 53 34 62 16Z";

// count: characters typed. colors: { track, glyph, newest } as CSS strings.
function paintEntry(c, kind, cap, count, W, H, colors) {
    const n = Math.min(count, cap), pad = Math.max(6, H * .1);
    const x0 = pad, span = W - pad * 2, step = span / cap;
    const cx = function(i) { return x0 + step * (i + .5); };
    const tone = function(i) { return i === n - 1 ? colors.newest : colors.glyph; };
    c.lineCap = "round"; c.lineJoin = "round";
    function line(points, color, width) {
        c.beginPath(); c.moveTo(points[0][0], points[0][1]);
        for (let i = 1; i < points.length; i++) c.lineTo(points[i][0], points[i][1]);
        c.strokeStyle = color; c.lineWidth = width; c.stroke();
    }
    function fillPath(d, color, soft) {
        c.beginPath(); c.path = d; c.fillStyle = color; c.fill();
        if (soft) { c.strokeStyle = color; c.lineWidth = soft; c.stroke(); }
    }
    function dot(x, y, r, color) { c.beginPath(); c.ellipse(x - r, y - r, r * 2, r * 2); c.fillStyle = color; c.fill(); }
    function mark(d, x, y, scale, deg, ox, oy, color) {
        c.save(); c.translate(x, y); c.rotate(deg * Math.PI / 180); c.scale(scale, scale); c.translate(-ox, -oy);
        c.beginPath(); c.path = d; c.fillStyle = color; c.fill();
        c.strokeStyle = color; c.lineWidth = 2.5; c.stroke(); c.restore();
    }
    const thin = Math.max(1.5, H * .025);

    if (kind === "orbit") {
        // The original Umbra trajectory: a curve, lit as far as the password reaches.
        const p = function(t) {
            const u = 1 - t;
            return [u*u*u*W*.035 + 3*u*u*t*W*.27 + 3*u*t*t*W*.68 + t*t*t*W*.94,
                    u*u*u*H*.72 + 3*u*u*t*H*.03 + 3*u*t*t*H*.98 + t*t*t*H*.27];
        };
        const curve = function(until) { const pts = []; for (let s = 0; s <= 100 * until; s++) pts.push(p(s / 100)); return pts; };
        line(curve(1), colors.track, Math.max(1.5, H * .006));
        if (n > 0) line(curve(n / cap), colors.glyph, Math.max(2, H * .012));
        for (let i = 0; i < n; i++) { const q = p(cap > 1 ? i / (cap - 1) : 0); dot(q[0], q[1], Math.max(3.5, H * .023) * (i === n - 1 ? 1.18 : 1), tone(i)); }
    } else if (kind === "gems") {
        const base = H * .8;
        line([[x0, base], [x0 + span, base]], colors.track, thin);
        for (let i = 0; i < n; i++) {
            const s = Math.min(step * .42, H * .2) * (i % 3 === 1 ? 1.18 : 1), y = base - s * 1.25;
            fillPath("M" + cx(i) + " " + (y - s) + "L" + (cx(i) + s * .62) + " " + (y - s * .35) + "L" + cx(i) + " " + (base - thin)
                     + "L" + (cx(i) - s * .62) + " " + (y - s * .35) + "Z", tone(i), thin);
        }
    } else if (kind === "pearls") {
        const wave = function(x) { return H * .62 + Math.sin((x - x0) / step * Math.PI) * H * .1; };
        const pts = []; for (let x = x0; x <= x0 + span; x += 3) pts.push([x, wave(x)]);
        line(pts, colors.track, thin * 1.4);
        for (let i = 0; i < n; i++) { const r = Math.min(step * .36, H * .12); dot(cx(i), wave(cx(i)) - r * 1.2, r, tone(i)); }
    } else if (kind === "flames") {
        const base = H * .82;
        line([[x0, base], [x0 + span, base]], colors.track, H * .09);
        for (let i = 0; i < n; i++) {
            const h = H * (i % 2 ? .4 : .54), w = Math.min(step * .5, h * .36), x = cx(i), b = base - H * .05;
            fillPath("M" + x + " " + (b - h) + "C" + (x + w * 1.1) + " " + (b - h * .45) + " " + (x + w) + " " + b + " " + x + " " + b
                     + "C" + (x - w) + " " + b + " " + (x - w * 1.1) + " " + (b - h * .45) + " " + x + " " + (b - h) + "Z", tone(i), thin);
        }
    } else if (kind === "rays") {
        // A sunrise: rays rise from the horizon, tallest in the middle of the line.
        const base = H * .88;
        line([[x0, base], [x0 + span, base]], colors.track, thin);
        for (let i = 0; i < n; i++) {
            const h = H * (.18 + .5 * Math.sin(Math.PI * (i + .5) / cap));
            line([[cx(i), base - thin * 2], [cx(i), base - h]], tone(i), Math.min(step * .42, H * .07));
        }
    } else if (kind === "vine") {
        const y = function(x) { return H * .58 + Math.sin((x - x0) / span * Math.PI * 3) * H * .12; };
        const grow = function(until) { const pts = []; for (let x = x0; x <= until; x += 3) pts.push([x, y(x)]); return pts; };
        line(grow(x0 + span), colors.track, thin);
        if (n > 0) line(grow(cx(n - 1)), colors.glyph, thin * 1.6);
        for (let i = 0; i < n; i++) {
            const up = i % 2 === 0, k = Math.min(step * 1.1, H * .4) / 120;
            mark(LEAF, cx(i), y(cx(i)), k, up ? -20 : 110, 21.5, 103.5, tone(i));
        }
    } else if (kind === "cubes") {
        const base = H * .82;
        line([[x0, base], [x0 + span, base]], colors.track, thin);
        for (let i = 0; i < n; i++) {
            const s = Math.min(step * .74, H * .34), r = s * .24;
            c.save(); c.translate(cx(i), base - s * .55 - thin); c.rotate((i % 2 ? 7 : -6) * Math.PI / 180);
            fillPath("M" + (-s/2 + r) + " " + (-s/2) + "L" + (s/2 - r) + " " + (-s/2) + "Q" + (s/2) + " " + (-s/2) + " " + (s/2) + " " + (-s/2 + r)
                     + "L" + (s/2) + " " + (s/2 - r) + "Q" + (s/2) + " " + (s/2) + " " + (s/2 - r) + " " + (s/2)
                     + "L" + (-s/2 + r) + " " + (s/2) + "Q" + (-s/2) + " " + (s/2) + " " + (-s/2) + " " + (s/2 - r)
                     + "L" + (-s/2) + " " + (-s/2 + r) + "Q" + (-s/2) + " " + (-s/2) + " " + (-s/2 + r) + " " + (-s/2) + "Z", tone(i), 0);
            c.restore();
        }
    } else if (kind === "drops") {
        const top = H * .2;
        line([[x0, top], [x0 + span, top]], colors.track, thin * 1.4);
        for (let i = 0; i < n; i++) {
            const k = Math.min(step * .95, H * .3) / 107.5, fall = H * (.08 + .22 * hash(i, 3));
            mark(DROP, cx(i), top + fall, k, 0, 64, 10, tone(i));
        }
    } else if (kind === "moons") {
        // Moons fill a tilted ring around a quiet planet.
        const ox = W / 2, oy = H * .52, rx = span * .46, ry = H * .3;
        dot(ox, oy, H * .16, colors.track);
        const ring = []; for (let a = 0; a <= 64; a++) ring.push([ox + rx * Math.cos(a / 64 * Math.PI * 2), oy + ry * Math.sin(a / 64 * Math.PI * 2)]);
        line(ring, colors.track, thin);
        for (let i = 0; i < n; i++) {
            const a = Math.PI + (i + .5) / cap * Math.PI * 2, front = Math.sin(a) > 0;
            dot(ox + rx * Math.cos(a), oy + ry * Math.sin(a), H * (front ? .075 : .055), tone(i));
        }
    } else if (kind === "constellation") {
        const sy = function(i) { return H * (.22 + .56 * hash(i, 7)); };
        for (let i = 1; i < n; i++) line([[cx(i - 1), sy(i - 1)], [cx(i), sy(i)]], colors.track, thin);
        for (let i = 0; i < n; i++) {
            const r = H * (.08 + .05 * hash(i, 11)), x = cx(i), y = sy(i), q = r * .3;
            fillPath("M" + x + " " + (y - r) + "L" + (x + q) + " " + (y - q) + "L" + (x + r) + " " + y + "L" + (x + q) + " " + (y + q)
                     + "L" + x + " " + (y + r) + "L" + (x - q) + " " + (y + q) + "L" + (x - r) + " " + y + "L" + (x - q) + " " + (y - q) + "Z", tone(i), 0);
        }
    } else if (kind === "flurry") {
        const bank = function(x) { return H * .86 + Math.sin((x - x0) / span * Math.PI * 4) * H * .03; };
        const pts = []; for (let x = x0; x <= x0 + span; x += 3) pts.push([x, bank(x)]);
        line(pts, colors.track, H * .06);
        for (let i = 0; i < n; i++) {
            // The snowflake mark's crystal: six arms, each with a small V near its tip.
            const r = Math.min(step * .44, H * .17), x = cx(i), y = H * (i % 2 ? .5 : .3);
            c.beginPath();
            for (let a = 0; a < 6; a++) {
                const t = a * Math.PI / 3 - Math.PI / 2, ux = Math.cos(t), uy = Math.sin(t);
                c.moveTo(x, y); c.lineTo(x + r * ux, y + r * uy);
                const bx = x + r * .62 * ux, by = y + r * .62 * uy;
                c.moveTo(bx - r * .3 * (ux * .5 - uy * .87), by - r * .3 * (uy * .5 + ux * .87)); c.lineTo(bx, by);
                c.lineTo(bx - r * .3 * (ux * .5 + uy * .87), by - r * .3 * (uy * .5 - ux * .87));
            }
            c.strokeStyle = tone(i); c.lineWidth = Math.max(1.5, r * .2); c.stroke();
        }
    } else if (kind === "phases") {
        // Each character is the next phase of the moon.
        for (let i = 0; i < n; i++) {
            const r = Math.min(step * .4, H * .2), x = cx(i), y = H * .55, p = ((i + 1) % 8) / 8;
            dot(x, y, r, colors.track);
            if (p === 0) continue;
            const k = Math.cos(2 * Math.PI * p), side = p <= .5 ? 1 : -1;
            c.beginPath();
            for (let j = 0; j <= 20; j++) { const a = Math.PI * j / 20; c.lineTo(x + side * r * Math.sin(a), y - r * Math.cos(a)); }
            for (let j = 20; j >= 0; j--) { const a = Math.PI * j / 20; c.lineTo(x + side * k * r * Math.sin(a), y - r * Math.cos(a)); }
            c.closePath(); c.fillStyle = tone(i); c.fill();
        }
    } else if (kind === "rain") {
        const puddle = H * .9;
        line([[x0, puddle], [x0 + span, puddle]], colors.track, thin);
        for (let i = 0; i < n; i++) {
            const y = H * (.12 + .38 * hash(i, 5)), x = cx(i);
            line([[x + H * .06, y], [x - H * .06, y + H * .28]], tone(i), Math.max(2, H * .06));
        }
    } else if (kind === "brush") {
        // One brush stroke lengthens with every character and ends in a full nib dot.
        const y = function(x) { return H * .56 + Math.sin((x - x0) / span * Math.PI * 2) * H * .1; };
        line([[x0, H * .86], [x0 + span, H * .86]], colors.track, thin);
        if (n > 0) {
            const end = x0 + (span - H * .12) * n / cap, upper = [], lower = [];  // room for the nib
            for (let x = x0; x <= end; x += 3) {
                const t = (x - x0) / Math.max(1, end - x0), w = H * (.03 + .11 * Math.sin(Math.PI * Math.min(1, t * 1.1)));
                upper.push([x, y(x) - w]); lower.push([x, y(x) + w * .7]);
            }
            c.beginPath(); c.moveTo(upper[0][0], upper[0][1]);
            for (let i = 1; i < upper.length; i++) c.lineTo(upper[i][0], upper[i][1]);
            for (let i = lower.length - 1; i >= 0; i--) c.lineTo(lower[i][0], lower[i][1]);
            c.closePath(); c.fillStyle = colors.glyph; c.fill();
            dot(end, y(end), H * .1, colors.newest);
            for (let i = 0; i < Math.min(3, n); i++)
                dot(Math.max(x0, end - H * (.2 + .3 * hash(n - i, 2))), y(end) + H * (hash(n + i, 9) - .5) * .5, H * .025, colors.glyph);
        }
    }
}
