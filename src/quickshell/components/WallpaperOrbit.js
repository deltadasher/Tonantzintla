.pragma library

function key(entry) {
    var value = String(entry && (entry.path || entry.remoteUrl || entry.preview) || "");
    if (value.indexOf("file://") === 0) {
        try { return decodeURIComponent(value.slice(7)); } catch (_) { return value.slice(7); }
    }
    return value;
}

function current(library, path, kind) {
    if (!path) return null;
    var identity = key({path: path});
    var found = (library || []).find(function(entry) { return key(entry) === identity; });
    var entry = Object.assign({}, found || {
        path: path, name: identity.split("/").pop() || "Current wallpaper",
        kind: kind || "image", source: "Current"
    });
    if (!entry.preview && entry.kind !== "video") entry.preview = path;
    return entry;
}

function sample(entries, active, limit, random) {
    var rng = random || Math.random;
    var seen = Object.create(null);
    var activeKey = key(active);
    if (activeKey) seen[activeKey] = true;
    var choices = (entries || []).filter(function(entry) {
        var identity = key(entry);
        if (!identity || seen[identity]) return false;
        seen[identity] = true;
        return true;
    });
    // Shuffle entries themselves: moving an offset through a sorted library
    // always preserves the same neighbors and is not a randomized selection.
    for (var i = choices.length - 1; i > 0; --i) {
        var j = Math.floor(rng() * (i + 1));
        var temporary = choices[i]; choices[i] = choices[j]; choices[j] = temporary;
    }
    var result = activeKey ? [active] : [];
    return result.concat(choices.slice(0, Math.max(0, limit - result.length)));
}
