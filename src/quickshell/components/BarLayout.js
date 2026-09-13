.pragma library

var zones = ["start", "center", "end"];
var islands = ["launcher", "workspaces", "media", "window_title", "clock", "system_stats", "status", "tray", "controls"];

function normalize(value, fallback) {
    var source = value;
    try { if (typeof source === "string") source = JSON.parse(source); }
    catch (_) { source = fallback; }
    if (!source || typeof source !== "object" || Array.isArray(source)) source = fallback;
    var result = {start: [], center: [], end: []};
    var seen = [];
    zones.forEach(function(zone) {
        var entries = Array.isArray(source[zone]) ? source[zone] : fallback[zone];
        entries.forEach(function(id) {
            if (islands.indexOf(id) < 0 || seen.indexOf(id) >= 0) return;
            result[zone].push(id);
            seen.push(id);
        });
    });
    return result;
}

function locate(layout, id) {
    for (var i = 0; i < zones.length; ++i) {
        var zone = zones[i];
        var index = layout[zone].indexOf(id);
        if (index >= 0) return {zone: zone, index: index};
    }
    return null;
}

// Always return a new layout. A stale selection cannot insert a duplicate.
function transfer(layout, fromZone, toZone, id, targetIndex) {
    var result = normalize(layout, {start: [], center: [], end: []});
    if (zones.indexOf(fromZone) < 0 || zones.indexOf(toZone) < 0) return result;
    var index = result[fromZone].indexOf(id);
    if (index < 0) return result;
    result[fromZone].splice(index, 1);
    var destination = result[toZone];
    var at = Number.isInteger(targetIndex) ? Math.max(0, Math.min(destination.length, targetIndex)) : destination.length;
    destination.splice(at, 0, id);
    return result;
}

function addIsland(layout, zone, id, targetIndex) {
    var result = normalize(layout, {start: [], center: [], end: []});
    if (zones.indexOf(zone) < 0 || islands.indexOf(id) < 0) return result;
    for (var i = 0; i < zones.length; ++i) {
        var idx = result[zones[i]].indexOf(id);
        if (idx >= 0) result[zones[i]].splice(idx, 1);
    }
    var destination = result[zone];
    var at = Number.isInteger(targetIndex) ? Math.max(0, Math.min(destination.length, targetIndex)) : destination.length;
    destination.splice(at, 0, id);
    return result;
}

function removeIsland(layout, id) {
    var result = normalize(layout, {start: [], center: [], end: []});
    for (var i = 0; i < zones.length; ++i) {
        var idx = result[zones[i]].indexOf(id);
        if (idx >= 0) result[zones[i]].splice(idx, 1);
    }
    return result;
}
