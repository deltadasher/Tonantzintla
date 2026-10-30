.pragma library

// Session-only, immutable edit history. No settings, timers or disk ownership.
function create() { return { past: [], future: [] }; }
function copy(value) { return JSON.parse(JSON.stringify(value)); }
function equal(a, b) { return JSON.stringify(a) === JSON.stringify(b); }
function record(history, before, after) {
    if (equal(before, after)) return history;
    var past = history.past;
    if (past.length && !equal(past[past.length - 1].after, before)) past = [];
    return { past: past.concat([{ before: copy(before), after: copy(after) }]).slice(-50), future: [] };
}
function undo(history, current) {
    if (!history.past.length) return { history: history, state: null };
    var entry = history.past[history.past.length - 1];
    if (!equal(current, entry.after)) return { history: create(), state: null };
    return { history: { past: history.past.slice(0, -1), future: history.future.concat([entry]) }, state: copy(entry.before) };
}
function redo(history, current) {
    if (!history.future.length) return { history: history, state: null };
    var entry = history.future[history.future.length - 1];
    if (!equal(current, entry.before)) return { history: create(), state: null };
    return { history: { past: history.past.concat([entry]), future: history.future.slice(0, -1) }, state: copy(entry.after) };
}
