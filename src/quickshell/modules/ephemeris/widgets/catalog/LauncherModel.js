.pragma library

function stableHash(value) {
    let hash = 2166136261;
    const text = String(value || "");
    for (let index = 0; index < text.length; index++) {
        hash ^= text.charCodeAt(index);
        hash = Math.imul(hash, 16777619);
    }
    return hash >>> 0;
}

function applications(values) {
    const seen = Object.create(null);
    return values.filter(function(app) {
        const name = String(app.name || "").trim();
        const id = String(app.id || name);
        if (!name || !String(app.command || "").trim() || /^about(?:\s|$)/i.test(name) || seen[id])
            return false;
        seen[id] = true;
        return true;
    }).sort(function(first, second) {
        const difference = stableHash(first.id || first.name) - stableHash(second.id || second.name);
        return difference || String(first.name).localeCompare(String(second.name));
    }).map(function(app) {
        return { id: "app:" + (app.id || app.name), appId: app.id || app.name,
            kind: "app", name: app.name, detail: app.genericName || app.comment || app.id || "Application",
            keywords: [app.name, app.genericName, app.comment, app.id].join(" "), app: app,
            enabled: true };
    });
}

function surfaceCommands(widgets) {
    const aliases = { walls: "wallpaper wallpapers parallax background library", calendar: "calendar weather forecast sundial earth helio",
        media: "resonance music lyrics equalizer pitch pitcher", audio: "volume microphone output mixer pipewire routing",
        network: "wifi wi-fi bluetooth ethernet", battery: "battery power energy", system: "cpu memory temperature system monitor",
        guide: "manual help keyboard bindings shortcuts", capture: "screenshot recording optics", notifications: "alerts history",
        focus: "focus concentration", workspaces: "windows workspace overview", clipboard: "copy paste history" };
    return widgets.filter(function(widget) { return widget.id !== "apps"; }).map(function(widget) {
        return { id: "surface:" + widget.id, kind: "surface", target: widget.id,
            name: widget.title, detail: "Open " + (widget.title || widget.id),
            keywords: [widget.id, widget.title, aliases[widget.id] || ""].join(" "), enabled: true };
    });
}

function searchText(value) {
    return String(value || "").toLowerCase().replace(/\s+/g, " ").trim();
}

function wordPrefixes(text, query) {
    const words = text.split(/[\s._\-/]+/);
    return query.split(" ").every(function(part) {
        return words.some(function(word) { return word.indexOf(part) === 0; });
    });
}

function nameScore(entry, needle) {
    const name = searchText(entry.name);
    if (name === needle) return 0;
    if (name.indexOf(needle) === 0) return 1;
    if (wordPrefixes(name, needle)) return 2;
    if (needle.length >= 3 && name.indexOf(needle) >= 0) return 3;
    return -1;
}

function matches(entry, needle) {
    needle = searchText(needle);
    if (nameScore(entry, needle) >= 0) return true;
    // Metadata is a fallback, not a bag of scattered matching letters.
    return needle.length >= 3 && wordPrefixes(searchText(
        [entry.detail, entry.keywords || ""].join(" ")), needle);
}

function astronomicalFact(needle) {
    const facts = {
        "c": { name: "Speed of Light (c)", value: "299,792,458 m/s", detail: "Universal physical constant in vacuum" },
        "speed of light": { name: "Speed of Light (c)", value: "299,792,458 m/s", detail: "Universal physical constant in vacuum" },
        "au": { name: "Astronomical Unit (1 AU)", value: "149,597,870,700 m", detail: "~149.6 million km · mean Earth-Sun distance" },
        "astronomical unit": { name: "Astronomical Unit (1 AU)", value: "149,597,870,700 m", detail: "~149.6 million km · mean Earth-Sun distance" },
        "ly": { name: "Light Year (1 ly)", value: "9.4607 × 10¹² km", detail: "Distance traversed by light in one Julian year" },
        "light year": { name: "Light Year (1 ly)", value: "9.4607 × 10¹² km", detail: "Distance traversed by light in one Julian year" },
        "parsec": { name: "Parsec (1 pc)", value: "3.0857 × 10¹³ km", detail: "~3.2616 light years · parallax of one arcsecond" },
        "solar mass": { name: "Solar Mass (M☉)", value: "1.9884 × 10³⁰ kg", detail: "~333,000 Earth masses" },
        "earth radius": { name: "Earth Radius (R⊕)", value: "6,371 km", detail: "Mean volumetric radius of Earth" },
        "moon distance": { name: "Moon Distance", value: "384,400 km", detail: "Semi-major axis of the Moon's orbit" }
    };
    const key = needle.trim().toLowerCase();
    if (facts[key]) {
        const item = facts[key];
        return {
            id: "astro:" + key,
            kind: "astro",
            name: item.name + " = " + item.value,
            detail: item.detail,
            result: item.value,
            enabled: true
        };
    }
    return null;
}

function evaluateMath(needle) {
    const trimmed = String(needle || "").trim();
    if (!trimmed || trimmed.length > 50) return null;
    if (!/^[0-9\.\s\+\-\*\/\%\(\)\^]+$/.test(trimmed))
        return null;
    if (!/[0-9]/.test(trimmed) || !/[\+\-\*\/\%\^]/.test(trimmed))
        return null;
    try {
        const sanitized = trimmed.replace(/\^/g, "**");
        const fn = new Function('"use strict"; return (' + sanitized + ')');
        const val = fn();
        if (typeof val === "number" && isFinite(val)) {
            const formatted = Number.isInteger(val) ? String(val) : String(parseFloat(val.toFixed(6)));
            return {
                id: "calc:" + trimmed,
                kind: "calc",
                name: "= " + formatted,
                detail: trimmed + " · press Enter to copy",
                result: formatted,
                enabled: true
            };
        }
    } catch (err) {
        return null;
    }
    return null;
}

function terminalCommand(query) {
    const trimmed = String(query || "").trim();
    if (trimmed.startsWith("!") || trimmed.startsWith("$ ")) {
        const cmd = trimmed.replace(/^[!\$]\s*/, "").trim();
        if (cmd.length > 0) {
            return {
                id: "cmd:" + cmd,
                kind: "terminal_cmd",
                name: "Run in terminal: " + cmd,
                detail: "Execute in configured terminal emulator",
                cmd: cmd,
                enabled: true
            };
        }
    }
    return null;
}

function filter(entries, query, category, favorites, enableCalc) {
    let needle = searchText(query);
    const commandsOnly = needle.charAt(0) === ">";
    if (commandsOnly)
        needle = needle.substring(1).trim();
    const saved = favorites || [];
    const eligible = entries.filter(function(entry) {
        if (commandsOnly ? entry.kind === "app"
            : category === "apps" ? entry.kind !== "app"
            : category === "actions" ? entry.kind === "app"
            : category === "saved" ? entry.kind !== "app" || saved.indexOf(entry.appId) < 0 : false)
            return false;
        return true;
    });
    // Keep the discovery order for empty searches and equal-strength matches.
    // Once a name matches, unrelated metadata hits cannot crowd it out.
    const named = needle ? eligible.map(function(entry, index) {
        return {entry: entry, index: index, score: nameScore(entry, needle)};
    }).filter(function(item) { return item.score >= 0; }) : [];
    named.sort(function(a, b) { return a.score - b.score || a.index - b.index; });
    const matched = !needle ? eligible : named.length
        ? named.map(function(item) { return item.entry; })
        : eligible.filter(function(entry) { return matches(entry, needle); });

    if (!commandsOnly && category !== "saved" && needle) {
        const special = [];
        const cmd = terminalCommand(query);
        if (cmd) special.push(cmd);
        if (enableCalc !== false) {
            const math = evaluateMath(needle);
            if (math) special.push(math);
            const astro = !named.length && needle.length > 2 ? astronomicalFact(needle) : null;
            if (astro) special.push(astro);
        }
        if (special.length > 0)
            return special.concat(matched);
    }

    return matched;
}

function selectedId(entries, currentId) {
    if (entries.some(function(entry) { return entry.id === currentId; }))
        return currentId;
    const available = entries.find(function(entry) { return entry.enabled !== false; });
    return available ? available.id : (entries.length ? entries[0].id : "");
}

function moveSelection(entries, currentId, delta) {
    if (!entries.length)
        return "";
    let index = entries.findIndex(function(entry) { return entry.id === currentId; });
    if (index < 0)
        index = delta > 0 ? -1 : 0;
    return entries[(index + delta + entries.length) % entries.length].id;
}
