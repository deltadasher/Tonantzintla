.pragma library

// Schema: niri-ipc Event::KeyboardLayoutsChanged / KeyboardLayoutSwitched.
// A single bounded snapshot, fed by the existing compositor event socket.
function empty() { return {names: [], currentIndex: -1}; }
function validIndex(value, names) {
    return typeof value === "number" && isFinite(value) && Math.floor(value) === value
        && value >= 0 && value < names.length ? value : -1;
}
function apply(state, message) {
    if (!message || typeof message !== "object") return state;
    if (message.KeyboardLayoutsChanged !== undefined) {
        const configuration = message.KeyboardLayoutsChanged && message.KeyboardLayoutsChanged.keyboard_layouts;
        if (!configuration || !Array.isArray(configuration.names)) return empty();
        // Keep indices intact, including any malformed/missing names.
        const names = configuration.names.slice(0, 256).map(function(name) {
            return typeof name === "string" ? name.slice(0, 128) : "";
        });
        return {names: names, currentIndex: validIndex(configuration.current_idx, names)};
    }
    if (message.KeyboardLayoutSwitched !== undefined) {
        const event = message.KeyboardLayoutSwitched;
        return {names: state.names, currentIndex: validIndex(event && event.idx, state.names)};
    }
    return state;
}
function currentName(state) {
    const index = validIndex(state.currentIndex, state.names);
    return index >= 0 ? state.names[index] : "";
}
