.pragma library

var roles = ["accent", "cyan", "rose", "success", "warning", "danger"];
function hex(value) {
    return typeof value === "string" && /^#[0-9a-f]{6}$/i.test(value.trim()) ? value.trim().toLowerCase() : "";
}
function sanitize(value) {
    var clean = {};
    if (!value || typeof value !== "object" || Array.isArray(value)) return clean;
    roles.forEach(function(role) { var color = hex(value[role]); if (color) clean[role] = color; });
    return clean;
}
function luminance(color) {
    var value = hex(color);
    if (!value) return NaN;
    var channels = [1, 3, 5].map(function(offset) {
        var channel = parseInt(value.slice(offset, offset + 2), 16) / 255;
        return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
    });
    return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
}
function contrast(first, second) {
    var a = luminance(first), b = luminance(second);
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}
function readable(color, backing) {
    var surfaces = Array.isArray(backing) ? backing : [backing];
    return !!hex(color) && surfaces.length > 0 && surfaces.every(function(surface) {
        return contrast(color, surface) >= 4.5;
    });
}
function edit(current, role, value, backing) {
    var colors = sanitize(current);
    if (roles.indexOf(role) < 0) return {ok: false, colors: colors, message: "Choose a color channel."};
    if (value === "") { delete colors[role]; return {ok: true, colors: colors, message: "Channel uses its theme color."}; }
    var color = hex(value);
    if (!color) return {ok: false, colors: colors, message: "Use an opaque color such as #a99cff."};
    if (!readable(color, backing)) return {ok: false, colors: colors, message: "Choose a lighter color for readable text on instrument surfaces."};
    colors[role] = color;
    return {ok: true, colors: colors, message: "Channel applied to the open interface."};
}
function resolve(current, role, fallback, backing) {
    var color = sanitize(current)[role];
    return readable(color, backing) ? color : fallback;
}
