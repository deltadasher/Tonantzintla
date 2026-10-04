.pragma library

function key(id) {
    return String(id || "").replace(/\.desktop$/i, "").toLowerCase();
}

function iconFor(entry, raw) {
    let overrides;
    try { overrides = JSON.parse(raw || "{}"); } catch (_) { overrides = {}; }
    const value = overrides && overrides[key(entry.appId)];
    return typeof value === "string" && value.trim() ? value.trim() : entry.icon;
}

function pins(raw) {
    let list;
    try { list = JSON.parse(raw || "[]"); } catch (_) { return []; }
    if (!Array.isArray(list)) return [];
    const seen = Object.create(null);
    return list.filter(function(id) {
        if (typeof id !== "string" || !key(id) || seen[key(id)]) return false;
        seen[key(id)] = true;
        return true;
    });
}

function entries(apps, windows, saved, showRunning) {
    const groups = Object.create(null);
    const byId = Object.create(null);
    const aliases = Object.create(null);
    apps.forEach(function(app) {
        if (!app.id || !app.name) return;
        byId[key(app.id)] = app;
        if (app.startupClass) aliases[key(app.startupClass)] = key(app.id);
    });
    const order = [];
    function add(id, pinned) {
        const k = key(id);
        if (!groups[k]) {
            const app = byId[k];
            groups[k] = { id: k, appId: app ? app.id : id, app: app || null,
                name: app ? app.name : String(id), icon: app ? app.icon : "",
                pinned: pinned, windows: [] };
            order.push(k);
        }
        return groups[k];
    }
    saved.forEach(function(id) { add(id, true); });
    // Stable groups: focus changes must not reorder the buttons under a pointer.
    windows.slice().sort(function(a, b) { return a.id - b.id; }).forEach(function(win) {
        if (!win.app_id) return;
        const id = aliases[key(win.app_id)] || key(win.app_id);
        if (!showRunning && !groups[id]) return;
        add(id, false).windows.push(win.id);
    });
    return order.map(function(id) { return groups[id]; });
}

function nextWindow(ids, focused) {
    if (!ids.length) return -1;
    return ids[(ids.indexOf(focused) + 1) % ids.length];
}

function movePin(raw, id, delta) {
    const list = pins(raw);
    const index = list.findIndex(function(value) { return key(value) === key(id); });
    const target = index + delta;
    if (index >= 0 && target >= 0 && target < list.length) {
        const value = list.splice(index, 1)[0];
        list.splice(target, 0, value);
    }
    return JSON.stringify(list);
}
