.pragma library

function rgb(hex) {
    return [1, 3, 5].map(function(i) { return parseInt(hex.slice(i, i + 2), 16) / 255; });
}
function brightness(v) { return .299 * v[0] + .587 * v[1] + .114 * v[2]; }
function recolor(svg, identity, original, target) {
    if (!/^#[0-9a-f]{6}$/i.test(original) || !/^#[0-9a-f]{6}$/i.test(target)) return svg;
    const base = brightness(rgb(original));
    const tint = rgb(target);
    const tintBrightness = brightness(tint);
    // Only paint attributes change. Geometry, alpha and the original files stay intact.
    return svg.replace(/\b(fill|stroke|color)="(#[0-9a-f]{6})"/gi, function(all, role, color) {
        if (identity === "wabi-sabi" && color.toLowerCase() === "#000000") return all;
        const delta = brightness(rgb(color)) - base;
        const amount = delta > 0 ? delta / Math.max(.001, 1 - base) : -delta / Math.max(.001, base);
        let shade = delta > 0 ? 1 : 0;
        // At white/black, keep secondary shapes visible instead of flattening them.
        if (delta > 0 && tintBrightness > .85) shade = 0;
        if (delta < 0 && tintBrightness < .15) shade = 1;
        const result = tint.map(function(v) {
            return Math.round(255 * (v * (1 - amount) + shade * amount)).toString(16).padStart(2, "0");
        }).join("");
        return role + '="#' + result + '"';
    });
}
