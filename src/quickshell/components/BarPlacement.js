.pragma library

var edges = ["top", "right", "bottom", "left"];
var zones = ["start", "center", "end"];

function parse(raw) {
    var value = raw;
    try { if (typeof value === "string") value = JSON.parse(value || "{}"); }
    catch (_) { value = {}; }
    return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function output(raw, outputName) {
    var all = parse(raw);
    var value = all[outputName];
    return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function validPlacement(value) {
    return value && typeof value === "object" && !Array.isArray(value)
        && (!value.edge || edges.indexOf(value.edge) >= 0)
        && (!value.zone || zones.indexOf(value.zone) >= 0);
}

function layoutFor(baseLayout, primaryEdge, targetEdge, raw, outputName) {
    var result = {start: [], center: [], end: []};
    if (edges.indexOf(primaryEdge) < 0 || edges.indexOf(targetEdge) < 0) return result;
    var placements = output(raw, outputName);
    var sequence = 0;
    var buckets = {start: [], center: [], end: []};

    zones.forEach(function(baseZone) {
        var ids = Array.isArray(baseLayout[baseZone]) ? baseLayout[baseZone] : [];
        ids.forEach(function(id, index) {
            var entry = validPlacement(placements[id]) ? placements[id] : {};
            var edge = entry.edge || primaryEdge;
            var zone = zones.indexOf(entry.zone) >= 0 ? entry.zone : baseZone;
            if (edge !== targetEdge) {
                sequence++;
                return;
            }
            var order = Number(entry.order);
            buckets[zone].push({
                id: id,
                order: Number.isFinite(order) ? order : index,
                sequence: sequence++
            });
        });
    });

    zones.forEach(function(zone) {
        buckets[zone].sort(function(a, b) {
            return a.order === b.order ? a.sequence - b.sequence : a.order - b.order;
        });
        result[zone] = buckets[zone].map(function(entry) { return entry.id; });
    });
    return result;
}

function place(raw, outputName, islandId, edge, zone, orderedIds) {
    var all = parse(raw);
    if (!outputName || !islandId || edges.indexOf(edge) < 0 || zones.indexOf(zone) < 0)
        return all;
    var placements = output(all, outputName);
    var ordered = Array.isArray(orderedIds) ? orderedIds : [islandId];
    ordered.forEach(function(id, index) {
        var existing = validPlacement(placements[id]) ? placements[id] : {};
        var next = {zone: zone, order: index};
        if (existing.edge) next.edge = existing.edge;
        if (id === islandId) next.edge = edge;
        placements[id] = next;
    });
    all[outputName] = placements;
    return all;
}

function clear(raw, outputName, islandId) {
    var all = parse(raw);
    if (!all[outputName]) return all;
    if (islandId) delete all[outputName][islandId];
    else delete all[outputName];
    if (all[outputName] && Object.keys(all[outputName]).length === 0)
        delete all[outputName];
    return all;
}
