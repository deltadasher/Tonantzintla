.pragma library
.import "ThemeIdentities.js" as Data

var identities = Data.identities;
function validColor(value) { return /^#[0-9a-f]{6}$/i.test(String(value || "")); }
function get(id) {
    for (var i = 0; i < identities.length; ++i)
        if (identities[i].id === id) return identities[i];
    return identities[3]; // The original mark is the safe default.
}
function sourceColor(exact, seed, fallback) {
    return validColor(exact) ? String(exact).toLowerCase()
        : validColor(seed) ? String(seed).toLowerCase()
        : validColor(fallback) ? String(fallback).toLowerCase() : "#e9b872";
}
function channels(value) {
    return [1, 3, 5].map(function(i) { return parseInt(value.slice(i, i + 2), 16) / 255; });
}
// Oklab distances group colors perceptually; neutral marks are kept out of
// saturated colors so a pale coral doesn't unexpectedly become a grey moon.
function lab(value) {
    var rgb = channels(value).map(function(x) { return x <= .04045 ? x / 12.92 : Math.pow((x + .055) / 1.055, 2.4); });
    var l = Math.cbrt(.4122214708*rgb[0] + .5363325363*rgb[1] + .0514459929*rgb[2]);
    var m = Math.cbrt(.2119034982*rgb[0] + .6806995451*rgb[1] + .1073969566*rgb[2]);
    var s = Math.cbrt(.0883024619*rgb[0] + .2817188376*rgb[1] + .6299787005*rgb[2]);
    return [.2104542553*l + .793617785*m - .0040720468*s,
            1.9779984951*l - 2.428592205*m + .4505937099*s,
            .0259040371*l + .7827717662*m - .808675766*s];
}
function match(value) {
    if (!validColor(value)) return get("wabi-sabi");
    value = String(value).toLowerCase();
    for (var i = 0; i < identities.length; ++i)
        if (identities[i].color.toLowerCase() === value) return identities[i];
    var rgb = channels(value), high = Math.max.apply(null, rgb), low = Math.min.apply(null, rgb);
    if (high - low < .10) {
        var brightness = .299*rgb[0] + .587*rgb[1] + .114*rgb[2];
        return get(brightness < .14 ? "ink" : brightness < .58 ? "cloud" : brightness < .91 ? "moon" : "snowflake");
    }
    var target = lab(value), closest = identities[3], distance = Infinity;
    for (var j = 0; j < 10; ++j) {
        var candidate = lab(identities[j].color);
        var d = .35*Math.pow(target[0]-candidate[0], 2) + Math.pow(target[1]-candidate[1], 2) + Math.pow(target[2]-candidate[2], 2);
        if (d < distance) { distance = d; closest = identities[j]; }
    }
    return closest;
}
function resolve(selection, color) { return selection === "auto" ? match(color) : get(selection); }
function recommendedMode(selection, color) { return resolve(selection, color).light ? "light" : "dark"; }
