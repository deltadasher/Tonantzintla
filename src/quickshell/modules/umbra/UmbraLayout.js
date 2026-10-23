.pragma library

var keys = ["clock", "media", "weather", "battery", "keyboard"];
var defaults = {
    clock: {x: .045, y: .29, w: .44, h: .23, visible: true},
    media: {x: .71, y: .85, w: .245, h: .10, visible: true},
    weather: {x: .076, y: .45, w: .35, h: .045, visible: true},
    battery: {x: .45, y: .76, w: .045, h: .065, visible: true},
    keyboard: {x: .045, y: .77, w: .36, h: .05, visible: false}
};
function number(value, fallback, low, high) {
    return Math.max(low, Math.min(high, typeof value === "number" && isFinite(value) ? value : fallback));
}
function normalize(value) {
    const result = {};
    for (const key of keys) {
        const base = defaults[key];
        const item = value && value[key] && typeof value[key] === "object" ? value[key] : {};
        const w = number(item.w, base.w, .035, .8), h = number(item.h, base.h, .035, .65);
        result[key] = {x: number(item.x, base.x, 0, 1-w), y: number(item.y, base.y, 0, 1-h),
            w: w, h: h, opacity: number(item.opacity, 1, 0, 1),
            rotation: ((Math.round(number(item.rotation, 0, -36000, 36000) / 90) * 90) % 360 + 360) % 360,
            visible: typeof item.visible === "boolean" ? item.visible : base.visible};
    }
    return result;
}
function update(layout, key, patch) {
    const next = normalize(layout);
    if (keys.indexOf(key) < 0) return next;
    for (const field of ["x", "y", "w", "h", "visible", "opacity", "rotation"])
        if (patch[field] !== undefined) next[key][field] = patch[field];
    return normalize(next);
}
function push(history, state) { return history.concat([normalize(state)]).slice(-100); }

// Stored rectangles are the *rotated bounding box*. Presentation swaps its inner
// dimensions on quarter turns, so every output can clamp the complete footprint.
function rotate(layout, key, width, height) {
    const next = normalize(layout), r = next[key];
    if (!r || width <= 0 || height <= 0) return next;
    const w = r.h * height / width, h = r.w * width / height;
    const scale = Math.min(1, .8 / w, .65 / h);
    return update(next, key, {x: r.x + (r.w-w*scale)/2, y: r.y+(r.h-h*scale)/2,
        w: w*scale, h: h*scale, rotation: (r.rotation+90)%360});
}
function snap(layout, key, x, y, width, height, grid) {
    const state = normalize(layout), r = state[key];
    if (!r || width <= 0 || height <= 0) return {rect:r,guideX:-1,guideY:-1};
    if (grid) { x = Math.round(x*width/20)*20/width; y = Math.round(y*height/20)*20/height; }
    let gx = -1, gy = -1, bestX = 8/width, bestY = 8/height;
    for (const axis of ["x", "y"]) {
        const size = axis === "x" ? "w" : "h", position = axis === "x" ? x : y;
        const guides = [0, .5, 1];
        for (const sibling of keys) {
            if (sibling === key || !state[sibling].visible) continue;
            const other = state[sibling];
            guides.push(other[axis], other[axis]+other[size]/2, other[axis]+other[size]);
        }
        for (const guide of guides) for (const offset of [0, r[size]/2, r[size]]) {
            const delta = guide-(position+offset);
            if (axis === "x" && Math.abs(delta) < bestX - .0000001) { bestX=Math.abs(delta); gx=guide; x=guide-offset; }
            if (axis === "y" && Math.abs(delta) < bestY - .0000001) { bestY=Math.abs(delta); gy=guide; y=guide-offset; }
        }
    }
    const rect = update(state,key,{x:x,y:y})[key];
    return {rect:rect,guideX:Math.abs(rect.x-x)<.000001?gx:-1,guideY:Math.abs(rect.y-y)<.000001?gy:-1};
}
function resize(rect, edge, dx, dy, width, height, grid) {
    let left=rect.x, top=rect.y, right=left+rect.w, bottom=top+rect.h;
    function position(value, extent) { return grid && extent>0 ? Math.round(value*extent/20)*20/extent : value; }
    if (edge.indexOf("left")>=0) left=Math.max(0,Math.min(right-.035,position(left+dx,width)));
    if (edge.indexOf("right")>=0) right=Math.min(1,Math.max(left+.035,position(right+dx,width)));
    if (edge.indexOf("top")>=0) top=Math.max(0,Math.min(bottom-.035,position(top+dy,height)));
    if (edge.indexOf("bottom")>=0) bottom=Math.min(1,Math.max(top+.035,position(bottom+dy,height)));
    if (right-left>.8) { if(edge.indexOf("left")>=0) left=right-.8; else right=left+.8; }
    if (bottom-top>.65) { if(edge.indexOf("top")>=0) top=bottom-.65; else bottom=top+.65; }
    return {x:left,y:top,w:right-left,h:bottom-top};
}
