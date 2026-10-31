.pragma library

// Dark exact accents need light surfaces; pale accents need dark surfaces.
// Without an explicit color, the caller supplies the current color-based mode.
function resolve(preference, seed, exactAccent, fallback) {
    if (preference === "light" || preference === "dark") return preference;
    if (/^#[0-9a-fA-F]{6}$/.test(String(exactAccent || ""))) seed = exactAccent;
    if (!/^#[0-9a-fA-F]{6}$/.test(String(seed || ""))) return fallback === "light" ? "light" : "dark";
    var red = parseInt(seed.slice(1, 3), 16) / 255;
    var green = parseInt(seed.slice(3, 5), 16) / 255;
    var blue = parseInt(seed.slice(5, 7), 16) / 255;
    return red * 0.299 + green * 0.587 + blue * 0.114 >= 0.5 ? "dark" : "light";
}

// Use the actual displayed accent, including intermediate animation frames.
// Choosing the stronger black/white contrast always provides at least 4.58:1.
function foreground(color) {
    if (!/^#[0-9a-fA-F]{6}$/.test(String(color || ""))) return "#ffffff";
    var channels = [1, 3, 5].map(function(offset) {
        var channel = parseInt(color.slice(offset, offset + 2), 16) / 255;
        return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
    });
    var luminance = channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
    var whiteContrast = 1.05 / (luminance + 0.05);
    var blackContrast = (luminance + 0.05) / 0.05;
    return blackContrast >= whiteContrast ? "#000000" : "#ffffff";
}
