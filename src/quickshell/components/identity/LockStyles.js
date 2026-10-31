.pragma library

// Each identity's voice on the lock and login screens: its typefaces, its
// password line, the shape and place of its buttons, and how the login screen
// offers user and session choices. Shared by Umbra and the SDDM greeter, so it
// uses no shell state. Families are tried in order and fall back to the
// system sans-serif; install/features.toml lists the packages that provide them.
//
// type: { families, style, weight, italic, tracking (em), caps: "upper" | "lower" }
// entry: the password line drawn by ControlDrawing.paintEntry, cap = glyphs shown
// button: shape from ControlDrawing, place: end | under | underEnd | start | over
// chooser: captions | chips | sentence | stacked | brackets
// actions: bottomRight | bottomLeft | bottomCenter | topRight | formRow

var STYLES = {
    "wabi-sabi": {
        // The original Umbra voice, unchanged.
        clock: { families: ["JetBrains Mono"], weight: 300, tracking: -.04 },
        date: { families: ["JetBrains Mono"], weight: 400, tracking: .11, caps: "upper", format: "dddd, MMMM dd" },
        label: { families: ["JetBrains Mono"], weight: 500, tracking: .04 },
        entry: { kind: "orbit", cap: 32 },
        button: { shape: "circle", place: "end" },
        chooser: "captions", actions: "bottomRight"
    },
    ruby: {
        // A jeweller's card: Palatino, quiet italics and spaced capitals.
        clock: { families: ["P052", "Palatino", "Noto Serif"], weight: 400, tracking: -.01 },
        date: { families: ["P052", "Palatino", "Noto Serif"], weight: 400, italic: true, tracking: .02, format: "dddd · d MMMM" },
        label: { families: ["P052", "Palatino", "Noto Serif"], weight: 400, tracking: .14, caps: "upper" },
        entry: { kind: "gems", cap: 24 },
        button: { shape: "shard", place: "end" },
        chooser: "sentence", actions: "bottomLeft"
    },
    seashell: {
        // Soft, rounded and lowercase, like a beach-hut sign.
        clock: { families: ["Rubik", "Noto Sans"], weight: 300, tracking: -.02 },
        date: { families: ["Rubik", "Noto Sans"], weight: 500, tracking: .02, caps: "lower", format: "dddd d MMMM" },
        label: { families: ["Rubik", "Noto Sans"], weight: 400, tracking: .01, caps: "lower" },
        entry: { kind: "pearls", cap: 24 },
        button: { shape: "shell", place: "under" },
        chooser: "chips", actions: "bottomCenter"
    },
    fire: {
        // Tall, heavy, condensed letters that stand like flames.
        clock: { families: ["Noto Sans"], style: "ExtraCondensed Black", weight: 900, tracking: 0 },
        date: { families: ["Noto Sans"], style: "Condensed SemiBold", weight: 600, tracking: .08, caps: "upper", format: "ddd d MMM" },
        label: { families: ["Noto Sans"], style: "Condensed Medium", weight: 500, tracking: .06, caps: "upper" },
        entry: { kind: "flames", cap: 24 },
        button: { shape: "flame", place: "end" },
        chooser: "stacked", actions: "formRow"
    },
    sun: {
        // Warm seventies Bookman, light and italic in the details.
        clock: { families: ["URW Bookman", "Bookman", "Noto Serif"], style: "Light", weight: 300, tracking: -.02 },
        date: { families: ["URW Bookman", "Bookman", "Noto Serif"], style: "Light Italic", weight: 300, italic: true, tracking: .01, format: "dddd, MMMM d" },
        label: { families: ["URW Bookman", "Bookman", "Noto Serif"], style: "Demi", weight: 600, tracking: .03 },
        entry: { kind: "rays", cap: 28 },
        button: { shape: "sun", place: "underEnd" },
        chooser: "sentence", actions: "topRight"
    },
    leaf: {
        // A gardener's notebook: light serif italics.
        clock: { families: ["Noto Serif"], style: "Light Italic", weight: 300, italic: true, tracking: -.02 },
        date: { families: ["Noto Serif"], style: "Italic", weight: 400, italic: true, tracking: .01, format: "d MMMM, dddd" },
        label: { families: ["Noto Serif"], style: "Italic", weight: 400, italic: true, tracking: .01 },
        entry: { kind: "vine", cap: 20 },
        button: { shape: "leaf", place: "end" },
        chooser: "chips", actions: "bottomLeft"
    },
    "ice-cube": {
        // Square, bold monospace: every character its own cube.
        clock: { families: ["Hack", "DejaVu Sans Mono"], weight: 700, tracking: -.06 },
        date: { families: ["Hack", "DejaVu Sans Mono"], weight: 400, tracking: .06, caps: "upper", format: "ddd dd.MM" },
        label: { families: ["Hack", "DejaVu Sans Mono"], weight: 400, tracking: 0 },
        entry: { kind: "cubes", cap: 22 },
        button: { shape: "hexagon", place: "start" },
        chooser: "brackets", actions: "bottomRight"
    },
    "water-droplet": {
        // A clean, fluid sans in its thinnest weight.
        clock: { families: ["Adwaita Sans", "Inter", "Noto Sans"], weight: 200, tracking: -.03 },
        date: { families: ["Adwaita Sans", "Inter", "Noto Sans"], weight: 500, tracking: .01, format: "dddd d MMMM" },
        label: { families: ["Adwaita Sans", "Inter", "Noto Sans"], weight: 400, tracking: .01 },
        entry: { kind: "drops", cap: 22 },
        button: { shape: "drop", place: "under" },
        chooser: "stacked", actions: "bottomCenter"
    },
    "ringed-planet": {
        // Space-age geometric capitals with generous spacing.
        clock: { families: ["URW Gothic", "Avant Garde", "Noto Sans"], style: "Book", weight: 400, tracking: .02 },
        date: { families: ["URW Gothic", "Avant Garde", "Noto Sans"], style: "Demi", weight: 600, tracking: .22, caps: "upper", format: "ddd · dd MMM yyyy" },
        label: { families: ["URW Gothic", "Avant Garde", "Noto Sans"], style: "Book", weight: 400, tracking: .12, caps: "upper" },
        entry: { kind: "moons", cap: 24 },
        button: { shape: "planet", place: "end" },
        chooser: "chips", actions: "topRight"
    },
    "night-sky": {
        // The observatory log: narrow monospace and ISO dates.
        clock: { families: ["Iosevka Nerd Font", "Iosevka", "JetBrains Mono"], weight: 300, tracking: .02 },
        date: { families: ["Iosevka Nerd Font", "Iosevka", "JetBrains Mono"], weight: 400, tracking: .1, caps: "upper", format: "yyyy-MM-dd · ddd" },
        label: { families: ["Iosevka Nerd Font", "Iosevka", "JetBrains Mono"], weight: 400, tracking: .06 },
        entry: { kind: "constellation", cap: 20 },
        button: { shape: "star", place: "over" },
        chooser: "brackets", actions: "topRight"
    },
    snowflake: {
        // Thin, tall, widely spaced capitals, cold and quiet.
        clock: { families: ["Noto Sans"], style: "Condensed Thin", weight: 100, tracking: .02 },
        date: { families: ["Noto Sans"], style: "Condensed Light", weight: 300, tracking: .3, caps: "upper", format: "dddd d MMMM" },
        label: { families: ["Noto Sans"], style: "Condensed Light", weight: 300, tracking: .16, caps: "upper" },
        entry: { kind: "flurry", cap: 20 },
        button: { shape: "rosette", place: "under" },
        chooser: "stacked", actions: "bottomRight"
    },
    moon: {
        // A bedtime storybook in Century Schoolbook.
        clock: { families: ["C059", "Century Schoolbook", "Noto Serif"], style: "Roman", weight: 400, tracking: -.01 },
        date: { families: ["C059", "Century Schoolbook", "Noto Serif"], style: "Italic", weight: 400, italic: true, tracking: .01, format: "dddd, MMMM d" },
        label: { families: ["C059", "Century Schoolbook", "Noto Serif"], style: "Italic", weight: 400, italic: true, tracking: .01, caps: "lower" },
        entry: { kind: "phases", cap: 20 },
        button: { shape: "halfMoon", place: "end" },
        chooser: "sentence", actions: "formRow"
    },
    cloud: {
        // A Swiss weather report: bold Helvetica numbers, plain captions.
        clock: { families: ["Nimbus Sans", "Helvetica", "Noto Sans"], style: "Bold", weight: 700, tracking: -.04 },
        date: { families: ["Nimbus Sans", "Helvetica", "Noto Sans"], style: "Bold", weight: 700, tracking: .04, caps: "upper", format: "ddd d MMM" },
        label: { families: ["Nimbus Sans", "Helvetica", "Noto Sans"], style: "Regular", weight: 400, tracking: .01 },
        entry: { kind: "rain", cap: 28 },
        button: { shape: "cloud", place: "underEnd" },
        chooser: "chips", actions: "bottomLeft"
    },
    ink: {
        // Calligraphy: Zapf Chancery throughout.
        clock: { families: ["Z003", "Zapf Chancery", "Noto Serif"], style: "Medium Italic", weight: 500, italic: true, tracking: 0 },
        date: { families: ["Z003", "Zapf Chancery", "Noto Serif"], style: "Medium Italic", weight: 500, italic: true, tracking: .02, format: "dddd, d MMMM" },
        label: { families: ["Z003", "Zapf Chancery", "Noto Serif"], style: "Medium Italic", weight: 500, italic: true, tracking: .02 },
        entry: { kind: "brush", cap: 24 },
        button: { shape: "seal", place: "end" },
        chooser: "sentence", actions: "bottomCenter"
    }
};

function style(id) { return STYLES[id] || STYLES["wabi-sabi"]; }

var resolved = ({});
// The first installed family in a list. A style name is only applied to the
// family it was written for, never to a fallback (see styleName).
function family(list) {
    const key = list.join("|");
    if (resolved[key] !== undefined) return resolved[key];
    // Qt tags a family with its foundry when two provide it: "Nimbus Sans [UKWN]".
    const installed = Qt.fontFamilies().map(function(name) { return name.replace(/ \[[^\]]*\]$/, ""); });
    let found = "";
    for (let i = 0; i < list.length && !found; i++)
        if (installed.indexOf(list[i]) !== -1) found = list[i];
    // Nothing installed: let Fontconfig substitute for the first choice.
    resolved[key] = found || list[0];
    return resolved[key];
}
function installed(type) { return family(type.families) === type.families[0]; }
// The style name only applies to the intended family; fallbacks use weight and italic.
function styleName(type) { return type.style && installed(type) ? type.style : ""; }
function date(type, when) { return Qt.formatDateTime(when, type.format || "dddd, MMMM d"); }
