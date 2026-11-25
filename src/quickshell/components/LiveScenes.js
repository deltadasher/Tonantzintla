.pragma library

// Catalog of the live wallpapers the shell draws itself. A live wallpaper is an
// ordinary Parallax entry whose `path` is its bundled still (used for the orbit,
// palette and optics) plus a `liveId` naming the scene in components/live/.
// Every setting is an integer slider so one themed control covers all of them.
var scenes = [
    { id: "snow", name: "Snowfall", component: "SnowScene.qml", props: [
        { name: "density", label: "Snowfall", from: 50, to: 1200, step: 10, value: 350, suffix: "" },
        { name: "wind", label: "Wind", from: -5, to: 5, step: 1, value: 1, suffix: "" }
    ] },
    { id: "life", name: "Life", component: "LifeScene.qml", props: [
        { name: "cell", label: "Cell size", from: 4, to: 24, step: 1, value: 9, suffix: " px" },
        { name: "speed", label: "Generations", from: 1, to: 30, step: 1, value: 12, suffix: " /s" }
    ] },
    { id: "flow", name: "Flow field", component: "FlowScene.qml", props: [
        { name: "count", label: "Particles", from: 200, to: 3000, step: 100, value: 1200, suffix: "" },
        { name: "pace", label: "Pace", from: 1, to: 10, step: 1, value: 4, suffix: "" }
    ] },
    { id: "procmon", name: "System monitor", component: "ProcmonScene.qml", props: [
        { name: "scale", label: "Text size", from: 80, to: 160, step: 5, value: 100, suffix: " %" }
    ] },
    { id: "deepfield", name: "Deep field", component: "DeepFieldScene.qml", props: [
        { name: "stars", label: "Stars", from: 100, to: 1200, step: 50, value: 600, suffix: "" },
        { name: "drift", label: "Drift", from: 0, to: 10, step: 1, value: 3, suffix: "" }
    ] },
    { id: "constellation", name: "Constellations", component: "ConstellationScene.qml", props: [
        { name: "count", label: "Stars", from: 30, to: 160, step: 10, value: 90, suffix: "" },
        { name: "reach", label: "Reach", from: 40, to: 140, step: 10, value: 90, suffix: "" }
    ] },
    { id: "aurora", name: "Aurora", component: "AuroraScene.qml", props: [
        { name: "glow", label: "Glow", from: 20, to: 100, step: 5, value: 60, suffix: " %" },
        { name: "pace", label: "Pace", from: 1, to: 10, step: 1, value: 4, suffix: "" }
    ] },
    { id: "orrery", name: "Orrery", component: "OrreryScene.qml", props: [
        { name: "bodies", label: "Bodies", from: 3, to: 14, step: 1, value: 8, suffix: "" },
        { name: "pace", label: "Pace", from: 1, to: 10, step: 1, value: 4, suffix: "" }
    ] }
];

function find(id) {
    for (var i = 0; i < scenes.length; ++i)
        if (scenes[i].id === id) return scenes[i];
    return null;
}

function stillPath(root, id) { return root + "/" + id + ".png"; }

function entries(root) {
    return scenes.map(function(scene) {
        var still = stillPath(root, scene.id);
        return { path: still, preview: still, name: scene.name, source: "Live", kind: "live", liveId: scene.id };
    });
}

function idForPath(root, path) {
    var value = String(path || "");
    for (var i = 0; i < scenes.length; ++i)
        if (stillPath(root, scenes[i].id) === value) return scenes[i].id;
    return "";
}

// Defaults overlaid with the user's saved values, clamped to each slider's range.
function values(scene, saved) {
    var result = {};
    if (!scene) return result;
    var own = saved && saved[scene.id] ? saved[scene.id] : {};
    scene.props.forEach(function(prop) {
        var value = Number(own[prop.name]);
        result[prop.name] = isFinite(value) && own[prop.name] !== undefined && own[prop.name] !== null
            ? Math.max(prop.from, Math.min(prop.to, value)) : prop.value;
    });
    return result;
}

function withValue(saved, id, name, value) {
    var next = JSON.parse(JSON.stringify(saved || {}));
    if (!next[id]) next[id] = {};
    next[id][name] = value;
    return next;
}

function without(saved, id) {
    var next = JSON.parse(JSON.stringify(saved || {}));
    delete next[id];
    return next;
}
