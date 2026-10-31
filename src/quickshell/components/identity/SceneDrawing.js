.pragma library

// Identity scenes, drawn in the same language as the approved marks: flat
// fills, one hue (two where the mark itself has two), softly rounded corners,
// chunky weights and no interior detail lines. The real SVG mark is always the
// hero; everything here is the world around it.
//
// A scene is a stack of layers on a 1000-unit artboard. Each layer is painted
// once into its own cached Canvas and only moved afterwards (translate, rotate,
// scale, opacity) by one shared clock, so motion never repaints.
// All painted geometry, including motion, stays within 80..920.

var LOOP = 120;          // seconds; every period below divides it evenly
var SOFT = 8;            // corner softening, matching the marks' 2.5/128 stroke at hero size

function approvedAccent(id) {
    const colors = { "ruby": "#D11E40", "seashell": "#EE927F", "fire": "#C44F28", "wabi-sabi": "#E9B872", "sun": "#EAC64B", "leaf": "#467B50", "ice-cube": "#83DAD9", "water-droplet": "#438FCA", "ringed-planet": "#9874CD", "night-sky": "#493961", "snowflake": "#FFFFFF", "moon": "#C8CDD3", "cloud": "#515861", "ink": "#000000" };
    return colors[id] || colors["wabi-sabi"];
}
function background(id, light) {
    const lightColors = { ruby: "#F5EBED", seashell: "#FAEEE7", fire: "#F6EDE5", "wabi-sabi": "#F4EFE5", sun: "#F6F0DB", leaf: "#EAF0E7", "ice-cube": "#E9F4F3", "water-droplet": "#E9F0F6", "ringed-planet": "#F0ECF6", "night-sky": "#EDEAF2", snowflake: "#E7EEF2", moon: "#EEF0F2", cloud: "#E9ECEF", ink: "#F0EEE9" };
    const darkColors = { ruby: "#25151D", seashell: "#211F29", fire: "#231A18", "wabi-sabi": "#16191C", sun: "#22251E", leaf: "#0E1B15", "ice-cube": "#142A32", "water-droplet": "#132533", "ringed-planet": "#211C32", "night-sky": "#1C1929", snowflake: "#202B38", moon: "#1D2430", cloud: "#202A33", ink: "#272727" };
    return (light ? lightColors : darkColors)[id] || (light ? "#F4EFE5" : "#16191C");
}
function color(c) { return typeof c === "string" ? Qt.color(c) : c; }
function mix(a, b, weight) {
    a = color(a); b = color(b);
    return Qt.rgba(a.r * (1-weight) + b.r * weight, a.g * (1-weight) + b.g * weight, a.b * (1-weight) + b.b * weight, 1);
}
function luminance(c) {
    c = color(c);
    function channel(v) { return v <= .04045 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4); }
    return .2126 * channel(c.r) + .7152 * channel(c.g) + .0722 * channel(c.b);
}
function contrast(a,b) { const x = luminance(a), y = luminance(b); return (Math.max(x,y)+.05)/(Math.min(x,y)+.05); }
function readableAccent(a, bg, fg) {
    for (let i = 0; i <= 20; i++) { const candidate = mix(a, fg, i/20); if (contrast(candidate,bg) >= 4.5) return candidate; }
    return fg;
}

// Painted bounds of each approved mark in its 128-unit viewBox (mirrors ThemeIdentities.js).
var BOUNDS = {
    ruby: [23.375,23.625,81,81], seashell: [11.6875,12.5,104.625,101.75],
    fire: [19.875,8.75,86.875,108.5], "wabi-sabi": [8.3125,22.6875,110.75,76.5],
    sun: [6.375,6.375,115.25,115.25], leaf: [16.3125,15.5625,94,93.125],
    "ice-cube": [14.75,10.75,98.5,106.5], "water-droplet": [22.75,10.75,83.5,107.5],
    "ringed-planet": [9.1875,26.75,109.8125,74.5], "night-sky": [12.8125,12.75,103.4375,102.5],
    snowflake: [16.6875,10,94.625,108], moon: [24.8125,12.75,77,102.5],
    cloud: [8.4375,26.5625,110.875,73.6875], ink: [24.75,9.75,78.5,107.5]
};
// The square box that places a mark's painted centre at (cx, cy) with the given painted width or height.
function fit(id, cx, cy, size, byHeight) {
    const b = BOUNDS[id];
    const s = size * 128 / (byHeight ? b[3] : b[2]);
    return [cx - (b[0] + b[2]/2) * s/128, cy - (b[1] + b[3]/2) * s/128, s, s];
}

// Exact outlines from the approved marks, for quieter echoes inside a scene.
var MARK = {
    leaf: "M104 18Q108 17 108 21C109 56 97 82 73 91 61 95 50 93 42 88L28 105Q26 108 23 105L20 102Q17 100 20 97L35 80C23 62 28 43 47 31 63 21 82 20 104 18Z",
    ice: "M60 14Q64 12 68 14L107 37Q111 39 111 44V86Q111 90 107 92L68 114Q64 116 60 114L21 92Q17 90 17 86V44Q17 39 21 37Z",
    cloud: "M32 98C18 98 9 89 11 77 13 65 22 59 33 61 32 41 46 27 64 29 79 30 89 41 91 54 106 52 118 63 117 77 116 90 106 98 93 98Z"
};

// ---------------------------------------------------------------- geometry
function n(v) { return Math.round(v * 10) / 10; }
function pt(x, y) { return n(x) + " " + n(y); }
function ell(cx, cy, rx, ry) {
    return "M" + pt(cx-rx, cy) + "A" + rx + " " + ry + " 0 1 0 " + pt(cx+rx, cy)
         + "A" + rx + " " + ry + " 0 1 0 " + pt(cx-rx, cy) + "Z";
}
function circ(cx, cy, r) { return ell(cx, cy, r, r); }
function rr(x, y, w, h, r) {
    return "M" + pt(x+r, y) + "L" + pt(x+w-r, y) + "Q" + pt(x+w, y) + " " + pt(x+w, y+r)
         + "L" + pt(x+w, y+h-r) + "Q" + pt(x+w, y+h) + " " + pt(x+w-r, y+h)
         + "L" + pt(x+r, y+h) + "Q" + pt(x, y+h) + " " + pt(x, y+h-r)
         + "L" + pt(x, y+r) + "Q" + pt(x, y) + " " + pt(x+r, y) + "Z";
}
function poly(points) {
    let d = "";
    for (let i = 0; i < points.length; i++) d += (i ? "L" : "M") + pt(points[i][0], points[i][1]);
    return d + "Z";
}
function rotated(points, cx, cy, deg) {
    const a = deg * Math.PI / 180, c = Math.cos(a), s = Math.sin(a);
    return points.map(function(p) { return [cx + p[0]*c - p[1]*s, cy + p[0]*s + p[1]*c]; });
}
// Four-point star, the same proportions as the Night sky mark's star.
function star(cx, cy, r) {
    const i = r * .31;
    return poly([[cx,cy-r],[cx+i,cy-i],[cx+r,cy],[cx+i,cy+i],[cx,cy+r],[cx-i,cy+i],[cx-r,cy],[cx-i,cy-i]]);
}
// A row of round crests, like the seashell's lobes, sitting on a solid band.
function scallop(x0, y, r, count, depth) {
    let d = "M" + pt(x0, y + depth) + "L" + pt(x0, y);
    for (let i = 0; i < count; i++) d += "A" + r + " " + r + " 0 0 1 " + pt(x0 + (i+1)*2*r, y);
    return d + "L" + pt(x0 + count*2*r, y + depth) + "Z";
}
// A gem crystal: a column with a pointed cap, standing on (x, y) and leaning by deg.
function crystal(x, y, w, h, deg) {
    return poly(rotated([[-w/2,0],[w/2,0],[w/2,-h+w*.55],[0,-h],[-w/2,-h+w*.55]], x, y, deg));
}
// A plain tree: one softened triangle on a short trunk.
function fir(x, y, w, h) { return poly([[x, y-h], [x+w/2, y], [x-w/2, y]]); }

// ---------------------------------------------------------------- painting kit
function kit(c) {
    c.lineCap = "round"; c.lineJoin = "round";
    const k = {
        fill: function(d, col) {
            c.beginPath(); c.path = d;
            c.fillStyle = col; c.fill();
            c.strokeStyle = col; c.lineWidth = SOFT; c.stroke();
        },
        line: function(d, col, width) {
            c.beginPath(); c.path = d;
            c.strokeStyle = col; c.lineWidth = width; c.stroke();
        },
        // An outline from an approved mark, placed by its own 128-unit coordinates.
        echo: function(d, x, y, scale, deg, col, ox, oy) {
            c.save(); c.translate(x, y); c.rotate(deg * Math.PI / 180); c.scale(scale, scale);
            c.translate(-ox, -oy);
            c.beginPath(); c.path = d;
            c.fillStyle = col; c.fill();
            c.strokeStyle = col; c.lineWidth = SOFT / scale; c.stroke();
            c.restore();
        }
    };
    return k;
}
// Tones are mixed toward the scene, never lit: "far" sinks into the background,
// "deep" is always darker than the accent and "pale" always lighter, in both modes.
function palette(accent, bg, fg, light) {
    const a = color(accent), p = color(bg), f = color(fg);
    const darkBase = light ? f : mix(p, "#000000", .35);
    const paleBase = light ? mix(p, "#FFFFFF", .6) : f;
    return {
        a: a, p: p, f: f, light: light,
        far: function(k) { return mix(a, p, k); },
        deep: function(k) { return mix(a, darkBase, k); },
        pale: function(k) { return mix(a, paleBase, k); },
        ground: function(k) { return mix(p, light ? f : "#000000", k); },   // the background's own hue
        lift: function(k) { return mix(p, light ? "#FFFFFF" : f, k); },
        pick: function(lightValue, darkValue) { return light ? lightValue : darkValue; }
    };
}

// ---------------------------------------------------------------- scenes
// layer: { name, box: [x, y, w, h], motion, origin: [x, y], rotate, logo }
// Motion keys (periods in seconds, phases in turns):
//   bob/drift [dx, dy, period, phase]    rock [deg, period, phase]    spin [period, direction]
//   breathe [sx, sy, period, phase]      pulse [minOpacity, period, phase]
//   twinkle [period, phase, minScale]    rise [dx, dy, period, phase]
//   ripple [fromScale, toScale, period, phase]    orbit [rx, ry, tiltDeg, period, phase]
var SCENES = {};

SCENES.ruby = {
    // A ruby lifted out of its geode: quiet crystal columns, the mark hovering above.
    layers: function() { return [
        { name: "rock", box: [160, 620, 690, 190] },
        { name: "columns", box: [300, 400, 490, 390] },
        { name: "logo", logo: true, box: fit("ruby", 528, 288, 280), origin: [528, 288],
          motion: { bob: [0, 16, 12, 0], rock: [3, 24, .25] } },
        { name: "spark1", box: [738, 196, 70, 70], motion: { twinkle: [6, 0, .45] } },
        { name: "spark2", box: [262, 330, 56, 56], motion: { twinkle: [8, .4, .45] } },
        { name: "spark3", box: [782, 470, 48, 48], motion: { twinkle: [10, .7, .45] } }
    ]; },
    draw: {
        rock: function(k, P) {
            k.fill("M190 780C196 724 254 694 326 700C376 652 470 640 520 682C584 640 690 652 724 704C792 700 826 736 826 780Z", P.far(.76));
        },
        columns: function(k, P) {
            k.fill(crystal(560, 742, 118, 290, 9), P.far(.42));
            k.fill(crystal(426, 758, 92, 200, -17), P.far(.56));
            k.fill(crystal(684, 760, 80, 170, 23), P.far(.56));
        },
        spark1: function(k, P) { k.fill(star(773, 231, 28), P.pale(.3)); },
        spark2: function(k, P) { k.fill(star(290, 358, 20), P.pale(.3)); },
        spark3: function(k, P) { k.fill(star(806, 494, 16), P.pale(.3)); }
    }
};

SCENES.seashell = {
    // A shell resting on a sandbar; behind it the sea is three chunky
    // serpentine swells that slide past each other like a slow tide.
    layers: function() { return [
        { name: "far", box: [210, 430, 580, 80], motion: { drift: [-14, 0, 15, .5] } },
        { name: "middle", box: [160, 500, 680, 80], motion: { drift: [18, 0, 12, 0] } },
        { name: "near", box: [110, 572, 780, 80], motion: { drift: [-22, 0, 10, .3] } },
        { name: "sand", box: [130, 660, 740, 190] },
        { name: "logo", logo: true, box: fit("seashell", 500, 566, 300), origin: [500, 712],
          motion: { rock: [2.2, 12, 0] } }
    ]; },
    draw: {
        far: function(k, P) { k.line(swell(232, 470, 536, 268, 7), P.pick(P.deep(.36), P.far(.66)), 22); },
        middle: function(k, P) { k.line(swell(180, 540, 640, 320, 8), P.pick(P.deep(.24), P.far(.56)), 24); },
        near: function(k, P) { k.line(swell(134, 612, 732, 366, 9), P.pick(P.deep(.12), P.far(.46)), 26); },
        sand: function(k, P) {
            k.fill("M150 806C214 718 370 684 500 684C630 684 786 718 850 806Q856 836 820 836L180 836Q144 836 150 806Z", P.pick(P.pale(.62), P.far(.78)));
        }
    }
};
// A smooth horizontal wave line starting at (x, y) and running for length.
function swell(x, y, length, wavelength, amplitude) {
    const q = wavelength / 4, count = Math.round(length / (wavelength / 2));
    let d = "M" + pt(x, y);
    for (let i = 0; i < count; i++) {
        const sign = i % 2 ? 1 : -1;
        d += "Q" + pt(x + q * (2*i + 1), y + sign * amplitude * 2) + " " + pt(x + q * (2*i + 2), y);
    }
    return d;
}

SCENES.fire = {
    // The approved flame is the fire: it stands on two crossed logs inside a ring
    // of stones, with embers drifting up and its light breathing on the ground.
    layers: function() { return [
        { name: "glow", box: [150, 650, 700, 170], origin: [500, 735], motion: { pulse: [.55, 6, 0], breathe: [.04, .04, 6, 0] } },
        { name: "backStones", box: [210, 660, 580, 80] },
        { name: "logs", box: [270, 590, 460, 170] },
        { name: "logo", logo: true, box: fit("fire", 500, 530, 360, true), origin: [500, 708],
          motion: { rock: [2.5, 6, 0], breathe: [.02, .035, 6, .25] } },
        { name: "frontStones", box: [196, 720, 608, 108] },
        { name: "ember1", box: [440, 330, 40, 40], motion: { rise: [-30, -190, 6, 0] } },
        { name: "ember2", box: [540, 360, 34, 34], motion: { rise: [40, -200, 8, .45] } },
        { name: "ember3", box: [486, 300, 28, 28], motion: { rise: [-10, -170, 10, .75] } }
    ]; },
    draw: {
        glow: function(k, P) { k.fill(ell(500, 735, 330, 72), P.far(.8)); },
        backStones: function(k, P) {
            const c = P.pick(P.far(.42), P.far(.6));
            k.fill(ell(262, 704, 40, 24), c); k.fill(ell(368, 690, 46, 24), c);
            k.fill(ell(632, 690, 46, 24), c); k.fill(ell(738, 704, 40, 24), c);
        },
        logs: function(k, P) {
            k.line("M318 718L672 640", P.deep(.42), 52);
            k.line("M328 640L682 718", P.deep(.3), 52);
        },
        frontStones: function(k, P) {
            const c = P.pick(P.far(.34), P.far(.52));
            k.fill(ell(250, 760, 44, 26), c); k.fill(ell(370, 782, 52, 28), c);
            k.fill(ell(500, 790, 54, 28), c); k.fill(ell(630, 782, 52, 28), c);
            k.fill(ell(750, 760, 44, 26), c);
        },
        ember1: function(k, P) { k.fill(star(460, 350, 12), "#EF9560"); },
        ember2: function(k, P) { k.fill(circ(557, 377, 9), "#EF9560"); },
        ember3: function(k, P) { k.fill(circ(500, 314, 7), P.pale(.2)); }
    }
};

SCENES["wabi-sabi"] = {
    // The original black hole over a dark horizon; its reflection breaks into
    // a few shimmering bars on the water below.
    layers: function() { return [
        { name: "horizon", box: [130, 586, 740, 36] },
        { name: "glint1", box: [310, 620, 380, 44], origin: [500, 642], motion: { breathe: [.1, 0, 8, 0], drift: [8, 0, 12, 0] } },
        { name: "glint2", box: [370, 666, 260, 40], origin: [500, 686], motion: { breathe: [.14, 0, 6, .4], drift: [-10, 0, 10, .2] } },
        { name: "glint3", box: [410, 708, 180, 40], origin: [500, 728], motion: { breathe: [.12, 0, 10, .7], drift: [6, 0, 15, .5] } },
        { name: "glint4", box: [446, 748, 108, 36], origin: [500, 766], motion: { breathe: [.18, 0, 5, .1] } },
        { name: "logo", logo: true, box: fit("wabi-sabi", 500, 380, 540), origin: [500, 380],
          motion: { bob: [0, 12, 15, 0], rock: [1.6, 30, .25] } }
    ]; },
    draw: {
        horizon: function(k, P) { k.line("M150 604L850 604", P.pick(P.deep(.55), P.far(.62)), 10); },
        glint1: function(k, P) { k.line("M336 642L664 642", P.a, 22); },
        glint2: function(k, P) { k.line("M394 686L606 686", P.far(.3), 20); },
        glint3: function(k, P) { k.line("M432 728L568 728", P.far(.48), 18); },
        glint4: function(k, P) { k.line("M466 766L534 766", P.far(.64), 16); }
    }
};

SCENES.sun = {
    // A slow-turning sun over two dunes. Far land sinks into the sky.
    layers: function() { return [
        { name: "farDune", box: [100, 500, 800, 320] },
        { name: "logo", logo: true, box: fit("sun", 500, 330, 330), origin: [500, 330],
          motion: { spin: [120, 1], bob: [0, 10, 15, 0] } },
        { name: "nearDune", box: [100, 640, 800, 190] }
    ]; },
    draw: {
        farDune: function(k, P) {
            k.fill("M112 806C160 700 270 604 380 592C470 582 540 630 610 616C690 600 740 584 792 608C848 636 880 730 888 806Z", P.pick(P.far(.6), P.far(.7)));
        },
        nearDune: function(k, P) {
            k.fill("M112 812C176 726 302 668 432 676C560 684 640 734 730 716C800 702 852 700 886 744Q890 780 888 812Z", P.pick(P.deep(.3), P.far(.42)));
        }
    }
};

SCENES.leaf = {
    // A trailing plant on a wall shelf. The approved leaf grows straight out of
    // the pot; three serpentine vines spill over the rim and shelf at different
    // lengths, each swaying on its own, and one loose leaf drifts down past them.
    layers: function() { return [
        { name: "shelf", box: [236, 508, 528, 120] },
        { name: "crown", box: [300, 196, 240, 236] },
        { name: "logo", logo: true, box: pin("leaf", 21.5, 103.5, 512, 404, 216), origin: [512, 404], rotate: -20,
          motion: { rock: [3, 12, 0] } },
        { name: "pot", box: [386, 382, 228, 146] },
        { name: "leftVine", box: [196, 384, 290, 410], origin: [424, 400], motion: { rock: [2.6, 10, .1] } },
        { name: "rightVine", box: [530, 384, 300, 476], origin: [578, 400], motion: { rock: [2, 15, .6] } },
        { name: "middleVine", box: [350, 390, 220, 500], origin: [466, 406], motion: { rock: [1.6, 12, .35] } },
        { name: "falling", box: [610, 560, 80, 80], origin: [650, 600],
          motion: { rise: [40, 230, 15, .2], rock: [24, 5, 0] } }
    ]; },
    draw: {
        shelf: function(k, P) {
            const wood = P.pick(P.deep(.56), P.far(.5)), bracket = P.pick(P.deep(.64), P.far(.6));
            k.fill(rr(254, 520, 492, 26, 12), wood);
            k.fill(poly([[316, 546], [360, 546], [316, 606]]), bracket);
            k.fill(poly([[640, 546], [684, 546], [684, 606]]), bracket);
        },
        crown: function(k, P) {
            k.echo(MARK.leaf, 494, 410, 1.22, -82, P.pick(P.far(.34), P.far(.26)), 21.5, 103.5);
        },
        pot: function(k, P) {
            k.fill("M410 414L590 414L567 512Q565 520 556 520L444 520Q435 520 433 512Z", P.pick(P.far(.5), P.far(.46)));
            k.fill(rr(394, 390, 212, 34, 12), P.pick(P.far(.38), P.far(.36)));
        },
        leftVine: function(k, P) {
            vine(k, P, [[424, 400], [392, 404], [362, 450], [358, 520], [354, 600], [296, 636], [304, 716]],
                 [[0, .45, 1, .78, .24], [0, .92, -1, .74, .4], [1, .4, 1, .76, .28], [1, .78, -1, .7, .44], [1, 1, 1, .6, .32]]);
        },
        middleVine: function(k, P) {
            vine(k, P, [[466, 406], [458, 452], [474, 500], [460, 562], [444, 636], [490, 690], [474, 790]],
                 [[0, .7, -1, .7, .3], [1, .22, 1, .74, .22], [1, .58, -1, .68, .4], [1, .92, 1, .62, .3]]);
        },
        rightVine: function(k, P) {
            vine(k, P, [[578, 400], [614, 404], [642, 462], [636, 540], [630, 630], [704, 668], [702, 752]],
                 [[0, .42, -1, .8, .26], [0, .9, 1, .76, .42], [1, .34, -1, .78, .24], [1, .7, 1, .72, .4]]);
            // A tendril curls off the end of the longest vine.
            k.line("M702 752C700 792 676 812 654 800C634 788 644 762 664 770", P.deep(.42), 9);
        },
        falling: function(k, P) { k.echo(MARK.leaf, 650, 600, .52, 30, P.far(.3), 64, 64); }
    }
};
// The square box that pins a point of a mark (in its 128-unit viewBox) to (x, y) at a painted width.
function pin(id, ax, ay, x, y, size) {
    const s = size * 128 / BOUNDS[id][2];
    return [x - ax * s/128, y - ay * s/128, s, s];
}
// A chunky stem through cubic segments, with leaves from the mark's outline
// set along it: [segment, t, side, scale, tone].
function vine(k, P, points, leaves) {
    let d = "M" + pt(points[0][0], points[0][1]);
    for (let i = 1; i + 2 < points.length; i += 3)
        d += "C" + pt(points[i][0], points[i][1]) + " " + pt(points[i+1][0], points[i+1][1]) + " " + pt(points[i+2][0], points[i+2][1]);
    k.line(d, P.deep(.42), 11);
    for (let j = 0; j < leaves.length; j++) {
        const l = leaves[j], b = l[0] * 3, t = l[1], u = 1 - t;
        const p0 = points[b], p1 = points[b+1], p2 = points[b+2], p3 = points[b+3];
        const x = u*u*u*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t*t*t*p3[0];
        const y = u*u*u*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t*t*t*p3[1];
        const dx = 3*u*u*(p1[0]-p0[0]) + 6*u*t*(p2[0]-p1[0]) + 3*t*t*(p3[0]-p2[0]);
        const dy = 3*u*u*(p1[1]-p0[1]) + 6*u*t*(p2[1]-p1[1]) + 3*t*t*(p3[1]-p2[1]);
        // The mark's leaf points 45 degrees up-right from its stem; turn it off the vine.
        const heading = Math.atan2(dy, dx) * 180 / Math.PI + l[2] * 68;
        // Dark mode lifts the vine leaves a little so they don't sink into the wall.
        k.echo(MARK.leaf, x, y, l[3], heading + 45, P.far(P.light ? l[4] : l[4] * .7), 21.5, 103.5);
    }
}

SCENES["ice-cube"] = {
    // An ice cube floating in a glass; a second cube rests below and bubbles rise.
    layers: function() { return [
        { name: "glass", box: [266, 210, 468, 640] },
        { name: "sunk", box: [470, 560, 200, 200], origin: [570, 660], motion: { bob: [0, 6, 10, .3], rock: [3, 20, 0] } },
        { name: "bubble1", box: [372, 760, 36, 36], motion: { rise: [6, -250, 6, 0] } },
        { name: "bubble2", box: [584, 770, 30, 30], motion: { rise: [-8, -210, 8, .5] } },
        { name: "bubble3", box: [450, 760, 26, 26], motion: { rise: [4, -260, 10, .25] } },
        { name: "logo", logo: true, box: fit("ice-cube", 470, 478, 250, true), origin: [470, 478], rotate: -8,
          motion: { bob: [0, 10, 8, 0], rock: [4, 20, .25] } },
        { name: "straw", box: [520, 210, 220, 560] }
    ]; },
    draw: {
        glass: function(k, P) {
            k.fill("M286 300L714 300L690 790Q686 832 646 832L354 832Q314 832 310 790Z", P.far(.78));
            k.fill("M308 480L692 480L673 784Q670 814 640 814L360 814Q330 814 327 784Z", P.pick(P.deep(.46), P.far(.55)));
            k.fill(rr(276, 286, 448, 28, 14), P.far(.62));
        },
        sunk: function(k, P) { k.echo(MARK.ice, 570, 660, 1.25, 14, P.pick(P.deep(.25), P.far(.3)), 64, 64); },
        bubble1: function(k, P) { k.fill(circ(390, 778, 12), P.pale(.45)); },
        bubble2: function(k, P) { k.fill(circ(599, 785, 9), P.pale(.45)); },
        bubble3: function(k, P) { k.fill(circ(463, 773, 7), P.pale(.45)); },
        straw: function(k, P) { k.line("M560 740L702 236", P.pick(P.deep(.18), P.far(.36)), 26); }
    }
};

SCENES["water-droplet"] = {
    // A drop hangs above a still pond; the last one's rings are still spreading.
    layers: function() { return [
        { name: "pond", box: [100, 570, 800, 260] },
        { name: "ring1", box: [150, 590, 600, 200], origin: [450, 690], motion: { ripple: [.25, 1, 8, 0] } },
        { name: "ring2", box: [150, 590, 600, 200], origin: [450, 690], motion: { ripple: [.25, 1, 8, .5] } },
        { name: "reeds", box: [700, 380, 160, 340], origin: [770, 704], motion: { rock: [2.5, 12, 0] } },
        { name: "logo", logo: true, box: fit("water-droplet", 450, 330, 270, true), origin: [450, 330],
          motion: { bob: [0, 16, 8, 0] } }
    ]; },
    draw: {
        pond: function(k, P) { k.fill(ell(500, 700, 380, 118), P.far(.74)); },
        ring1: function(k, P) { k.line(ell(450, 690, 290, 88), P.far(.42), 12); },
        ring2: function(k, P) { k.line(ell(450, 690, 290, 88), P.far(.42), 12); },
        reeds: function(k, P) {
            k.fill("M752 704Q744 560 772 404Q790 560 784 704Z", P.deep(.34));
            k.fill("M780 704Q800 600 838 500Q822 610 806 704Z", P.far(.42));
            k.fill("M730 704Q716 630 718 560Q742 630 756 704Z", P.far(.56));
        }
    }
};

SCENES["ringed-planet"] = {
    // The planet turns slowly inside a wider orbit; a small moon travels around
    // it, passing behind the planet on the far side.
    layers: function() { return [
        { name: "star1", box: [148, 168, 64, 64], motion: { twinkle: [6, 0, .4] } },
        { name: "star2", box: [736, 146, 56, 56], motion: { twinkle: [8, .35, .4] } },
        { name: "star3", box: [800, 626, 48, 48], motion: { twinkle: [10, .7, .4] } },
        { name: "star4", box: [226, 690, 40, 40], motion: { twinkle: [12, .2, .4] } },
        { name: "orbitBack", box: [100, 180, 800, 500] },
        { name: "logo", logo: true, box: fit("ringed-planet", 510, 430, 470), origin: [510, 430],
          motion: { rock: [3, 20, 0], bob: [0, 8, 10, .25] } },
        { name: "orbitFront", box: [100, 180, 800, 500] },
        { name: "moon", box: [484, 404, 52, 52], orbit: true, motion: { orbit: [400, 168, -24, 40, 0] } }
    ]; },
    draw: {
        star1: function(k, P) { k.fill(star(180, 200, 24), P.pick(P.far(.45), P.pale(.35))); },
        star2: function(k, P) { k.fill(star(764, 174, 20), P.pick(P.far(.45), P.pale(.35))); },
        star3: function(k, P) { k.fill(star(824, 650, 16), P.pick(P.far(.45), P.pale(.35))); },
        star4: function(k, P) { k.fill(star(246, 710, 13), P.pick(P.far(.45), P.pale(.35))); },
        orbitBack: function(k, P) { k.line(orbitPath(510, 430, 400, 168, -24, Math.PI, 2*Math.PI), P.far(.68), 10); },
        orbitFront: function(k, P) { k.line(orbitPath(510, 430, 400, 168, -24, 0, Math.PI), P.far(.68), 10); },
        moon: function(k, P) { k.fill(circ(510, 430, 18), P.pale(.35)); }
    }
};
function orbitPath(cx, cy, rx, ry, tilt, from, to) {
    const a = tilt * Math.PI / 180, c = Math.cos(a), s = Math.sin(a);
    let d = "";
    for (let i = 0; i <= 48; i++) {
        const t = from + (to - from) * i / 48, ex = rx * Math.cos(t), ey = ry * Math.sin(t);
        d += (i ? "L" : "M") + pt(cx + ex*c - ey*s, cy + ex*s + ey*c);
    }
    return d;
}

SCENES["night-sky"] = {
    // Tonantzintla is an observatory. A small open dome watches a galaxy turn
    // slowly behind the mark; its pale core keeps the dark mark legible.
    layers: function() { return [
        { name: "arms", box: [140, 90, 680, 680], origin: [480, 430], motion: { spin: [120, 1] } },
        { name: "core", box: [312, 262, 336, 336] },
        { name: "star1", box: [756, 150, 48, 48], motion: { twinkle: [8, 0, .4] } },
        { name: "star2", box: [812, 472, 40, 40], motion: { twinkle: [6, .5, .4] } },
        { name: "star3", box: [146, 590, 34, 34], motion: { twinkle: [10, .25, .4] } },
        { name: "ground", box: [92, 590, 816, 260] },
        { name: "logo", logo: true, box: fit("night-sky", 480, 430, 214), origin: [480, 430],
          motion: { bob: [0, 8, 12, 0], rock: [2.5, 24, .25] } }
    ]; },
    draw: {
        arms: function(k, P) {
            const arm = P.pick(P.far(.8), P.pale(.3));
            k.fill(spiralArm(480, 430, 120, 330, .62, 200, 46, 6), arm);
            k.fill(spiralArm(480, 430, 120, 330, .62, 20, 46, 6), arm);
        },
        core: function(k, P) {
            k.fill(circ(480, 430, 160), P.pick(P.far(.9), P.pale(.42)));
            k.fill(circ(480, 430, 120), P.pick(P.lift(.7), P.pale(.62)));
        },
        star1: function(k, P) { k.fill(star(780, 174, 18), P.pick(P.far(.35), P.pale(.55))); },
        star2: function(k, P) { k.fill(star(832, 492, 14), P.pick(P.far(.35), P.pale(.55))); },
        star3: function(k, P) { k.fill(star(163, 607, 12), P.pick(P.far(.35), P.pale(.55))); },
        ground: function(k, P) {
            k.fill("M100 836C200 760 380 730 520 730C680 730 820 760 900 836Z", P.pick(P.far(.7), mix(P.p, "#000000", .3)));
            const dome = P.pick(P.far(.4), P.far(.5)), drum = P.pick(P.far(.56), P.far(.64));
            k.fill(rr(646, 690, 160, 78, 10), drum);
            k.fill("M632 696A94 94 0 0 1 820 696Z", dome);
            // The open shutter, turned toward the galaxy.
            k.line("M704 690L730 620", P.pick(P.deep(.25), mix(P.p, "#000000", .35)), 20);
        }
    }
};
// One tapered arm of a face-on spiral, growing from r0 to r1 over the given turns.
function spiralArm(cx, cy, r0, r1, turns, startDeg, w0, w1) {
    const outer = [], inner = [];
    for (let i = 0; i <= 36; i++) {
        const t = i / 36, r = r0 * Math.pow(r1 / r0, t), w = w0 + (w1 - w0) * t;
        const a = (startDeg * Math.PI / 180) + turns * 2 * Math.PI * t;
        outer.push([cx + (r + w) * Math.cos(a), cy + (r + w) * Math.sin(a)]);
        inner.push([cx + (r - w) * Math.cos(a), cy + (r - w) * Math.sin(a)]);
    }
    return poly(outer.concat(inner.reverse()));
}

SCENES.snowflake = {
    // The snowflake turns slowly in front of a dark stand of firs while
    // smaller snow falls on either side.
    layers: function() { return [
        { name: "backFirs", box: [110, 300, 780, 490] },
        { name: "frontFirs", box: [100, 430, 800, 380] },
        { name: "bank", box: [96, 730, 808, 120] },
        { name: "flake1", box: [178, 150, 32, 32], motion: { rise: [16, 330, 12, 0] } },
        { name: "flake2", box: [776, 170, 28, 28], motion: { rise: [-14, 300, 15, .4] } },
        { name: "flake3", box: [258, 120, 24, 24], motion: { rise: [10, 360, 20, .7] } },
        { name: "flake4", box: [700, 120, 22, 22], motion: { rise: [-8, 340, 10, .2] } },
        { name: "logo", logo: true, box: fit("snowflake", 500, 388, 280, true), origin: [500, 388],
          motion: { spin: [60, 1], bob: [0, 10, 12, 0] } }
    ]; },
    draw: {
        backFirs: function(k, P) {
            const c = P.pick(mix(P.p, "#3A4E63", .48), P.ground(.28));
            k.fill(fir(250, 760, 180, 360), c); k.fill(fir(420, 760, 200, 440), c);
            k.fill(fir(596, 760, 200, 420), c); k.fill(fir(760, 760, 170, 320), c);
        },
        frontFirs: function(k, P) {
            const c = P.pick(mix(P.p, "#2C3E52", .74), P.ground(.5));
            k.fill(fir(170, 770, 120, 210), c); k.fill(fir(340, 770, 150, 300), c);
            k.fill(fir(520, 770, 160, 320), c); k.fill(fir(690, 770, 150, 270), c);
            k.fill(fir(840, 770, 100, 190), c);
        },
        bank: function(k, P) {
            k.fill("M104 800C160 750 300 736 420 750C540 764 640 738 760 742C840 745 890 770 896 800Q896 836 860 836L140 836Q104 836 104 800Z", P.pick(P.lift(.85), P.lift(.2)));
        },
        flake1: function(k, P) { k.fill(circ(194, 166, 10), P.pick(P.lift(1), P.lift(.85))); },
        flake2: function(k, P) { k.fill(circ(790, 184, 8), P.pick(P.lift(1), P.lift(.85))); },
        flake3: function(k, P) { k.fill(circ(270, 132, 6), P.pick(P.lift(1), P.lift(.85))); },
        flake4: function(k, P) { k.fill(circ(711, 131, 6), P.pick(P.lift(1), P.lift(.85))); }
    }
};

SCENES.moon = {
    // The moon through an arched window at night; the tied curtain moves a little.
    layers: function() { return [
        { name: "window", box: [240, 160, 520, 660] },
        { name: "star1", box: [586, 590, 44, 44], motion: { twinkle: [8, 0, .4] } },
        { name: "star2", box: [376, 640, 36, 36], motion: { twinkle: [10, .5, .4] } },
        { name: "star3", box: [612, 300, 30, 30], motion: { twinkle: [6, .3, .4] } },
        { name: "logo", logo: true, box: fit("moon", 480, 404, 236, true), origin: [480, 404],
          motion: { bob: [0, 8, 15, 0], rock: [3, 30, .25] } },
        { name: "mullion", box: [276, 540, 448, 240] },
        { name: "curtain", box: [226, 170, 170, 630], origin: [250, 180], motion: { rock: [1.4, 12, 0] } }
    ]; },
    draw: {
        window: function(k, P) {
            k.fill("M270 780L270 410A230 230 0 0 1 730 410L730 780Z", P.pick(P.ground(.16), P.lift(.1)));
            k.fill("M300 760L300 412A200 200 0 0 1 700 412L700 760Z", P.pick(P.ground(.72), P.ground(.42)));
            k.fill(rr(248, 772, 504, 34, 12), P.pick(P.ground(.24), P.lift(.16)));
        },
        star1: function(k, P) { k.fill(star(608, 612, 16), P.pale(.2)); },
        star2: function(k, P) { k.fill(star(394, 658, 12), P.pale(.2)); },
        star3: function(k, P) { k.fill(star(627, 315, 10), P.pale(.2)); },
        mullion: function(k, P) {
            const frame = P.pick(P.ground(.16), P.lift(.1));
            k.fill(rr(296, 552, 408, 22, 8), frame);
            k.fill(rr(489, 560, 22, 204, 8), frame);
        },
        curtain: function(k, P) {
            const cloth = P.pick(P.ground(.3), P.lift(.22));
            k.fill("M236 180L362 180Q372 330 304 470Q376 610 352 786L236 786Z", cloth);
            k.fill(rr(234, 458, 84, 22, 10), P.pick(P.ground(.46), P.lift(.36)));
        }
    }
};

SCENES.cloud = {
    // A drifting rain cloud; three pale arcs rise from behind it.
    layers: function() { return [
        { name: "arcs", box: [100, 380, 520, 370] },
        { name: "rain1", box: [500, 680, 40, 60], motion: { rise: [-14, 110, 5, 0] } },
        { name: "rain2", box: [600, 680, 40, 60], motion: { rise: [-14, 110, 5, .35] } },
        { name: "rain3", box: [700, 680, 40, 60], motion: { rise: [-14, 110, 5, .7] } },
        { name: "rain4", box: [650, 664, 40, 60], motion: { rise: [-14, 120, 6, .15] } },
        { name: "logo", logo: true, box: fit("cloud", 600, 540, 420), origin: [600, 540],
          motion: { drift: [24, 0, 20, 0], bob: [0, 7, 10, .25] } }
    ]; },
    draw: {
        arcs: function(k, P) {
            // Three plain bands, each paler than the cloud in both modes.
            k.line(arcPath(440, 720, 300, 302), P.pale(.28), 42);
            k.line(arcPath(440, 720, 250, 304), P.pale(.5), 42);
            k.line(arcPath(440, 720, 200, 306), P.pale(.72), 42);
        },
        rain1: function(k, P) { k.line("M528 692L518 724", P.pick(P.far(.2), P.pale(.4)), 12); },
        rain2: function(k, P) { k.line("M628 692L618 724", P.pick(P.far(.2), P.pale(.4)), 12); },
        rain3: function(k, P) { k.line("M728 692L718 724", P.pick(P.far(.2), P.pale(.4)), 12); },
        rain4: function(k, P) { k.line("M678 676L668 708", P.pick(P.far(.2), P.pale(.4)), 12); }
    }
};
// An arc rising from its left foot, clockwise over the top, ending at endDeg.
function arcPath(cx, cy, r, endDeg) {
    const e = endDeg * Math.PI / 180;
    return "M" + pt(cx - r, cy) + "A" + r + " " + r + " 0 0 1 " + pt(cx + r*Math.cos(e), cy + r*Math.sin(e));
}

SCENES.ink = {
    // The pen-nib drop over a sheet of paper, a single serpentine brush stroke
    // and the small blot it keeps feeding.
    layers: function() { return [
        { name: "paper", box: [130, 200, 740, 660] },
        { name: "stroke", box: [200, 420, 520, 360] },
        { name: "blot", box: [586, 610, 168, 80], origin: [670, 650], motion: { breathe: [.07, .07, 10, .5] } },
        { name: "logo", logo: true, box: fit("ink", 670, 410, 250, true), origin: [670, 410],
          motion: { bob: [0, 14, 10, 0], rock: [2, 20, .25] } }
    ]; },
    draw: {
        paper: function(k, P) {
            const sheet = rotated([[-300,-250],[300,-250],[300,250],[-300,250]], 500, 520, -5);
            k.fill(poly(sheet.map(function(p) { return [p[0]+14, p[1]+16]; })), P.pick(P.ground(.12), mix(P.p, "#000000", .45)));
            k.fill(poly(sheet), P.pick(P.lift(.7), mix(P.f, P.p, .08)));
        },
        stroke: function(k, P) {
            const ink = P.pick("#000000", "#111111");
            k.fill("M236 724C300 690 330 610 404 590C470 572 500 640 560 628C610 618 640 548 692 520C650 580 620 650 560 662C498 676 470 618 412 632C356 646 320 712 236 724Z", ink);
            k.fill(circ(270, 650, 9), ink); k.fill(circ(704, 488, 7), ink); k.fill(circ(318, 752, 6), ink);
        },
        blot: function(k, P) { k.fill(ell(670, 650, 64, 20), P.pick("#000000", "#111111")); }
    }
};

function scene(id) { return SCENES[id] || SCENES["wabi-sabi"]; }
function layers(id) { return scene(id).layers(); }
function markPlacement(id) {
    const list = layers(id);
    for (let i = 0; i < list.length; i++) if (list[i].logo) return { x: list[i].box[0], y: list[i].box[1], size: list[i].box[2] };
    return { x: 250, y: 250, size: 500 };
}

// Paints one cached layer in artboard units; the caller has already mapped its box.
function paintLayer(c, id, name, accent, bg, fg, light) {
    const draw = scene(id).draw[name];
    if (!draw) return;
    draw(kit(c), palette(accent, bg, fg, light));
}
// Every scenery layer at rest on one artboard (marks are separate SVG images).
function paint(c, id, accent, bg, fg, light) {
    const list = layers(id);
    for (let i = 0; i < list.length; i++) {
        if (list[i].logo) continue;
        c.save(); paintLayer(c, id, list[i].name, accent, bg, fg, light); c.restore();
    }
}

// ---------------------------------------------------------------- motion
var REST = { x: 0, y: 0, r: 0, sx: 1, sy: 1, o: 1, front: 0 };
function pose(m, t) {
    if (!m) return REST;
    let x = 0, y = 0, r = 0, sx = 1, sy = 1, o = 1, front = 0;
    function wave(period, phase) { return Math.sin(2 * Math.PI * (t / period + (phase || 0))); }
    function progress(period, phase) { const p = t / period + (phase || 0); return p - Math.floor(p); }
    if (m.bob) { const v = wave(m.bob[2], m.bob[3]); x += m.bob[0] * v; y += m.bob[1] * v; }
    if (m.drift) { const v = wave(m.drift[2], m.drift[3]); x += m.drift[0] * v; y += m.drift[1] * v; }
    if (m.rock) r += m.rock[0] * wave(m.rock[1], m.rock[2]);
    if (m.spin) r += 360 * (t / m.spin[0]) * (m.spin[1] || 1);
    if (m.breathe) { const v = wave(m.breathe[2], m.breathe[3]); sx *= 1 + m.breathe[0] * v; sy *= 1 + m.breathe[1] * v; }
    if (m.pulse) o *= m.pulse[0] + (1 - m.pulse[0]) * (.5 + .5 * wave(m.pulse[1], m.pulse[2]));
    if (m.twinkle) {
        const v = .5 + .5 * wave(m.twinkle[0], m.twinkle[1]), s = m.twinkle[2] + (1 - m.twinkle[2]) * v;
        sx *= s; sy *= s; o *= .3 + .7 * v;
    }
    if (m.rise) {
        const p = progress(m.rise[2], m.rise[3]);
        x += m.rise[0] * p; y += m.rise[1] * p; o *= Math.sin(Math.PI * p);
    }
    if (m.ripple) {
        const p = progress(m.ripple[2], m.ripple[3]), s = m.ripple[0] + (m.ripple[1] - m.ripple[0]) * p;
        sx *= s; sy *= s; o *= (1 - p) * Math.min(1, p * 6);
    }
    if (m.orbit) {
        const q = 2 * Math.PI * (t / m.orbit[3] + (m.orbit[4] || 0));
        const a = m.orbit[2] * Math.PI / 180, ex = m.orbit[0] * Math.cos(q), ey = m.orbit[1] * Math.sin(q);
        x += ex * Math.cos(a) - ey * Math.sin(a); y += ex * Math.sin(a) + ey * Math.cos(a);
        front = Math.sin(q) >= 0 ? 1 : -1;
    }
    return { x: x, y: y, r: r, sx: sx, sy: sy, o: o, front: front };
}
