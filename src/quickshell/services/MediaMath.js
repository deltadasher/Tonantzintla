.pragma library

function duration(value) { return isFinite(value) ? Math.max(0, Number(value)) : 0; }
function absoluteSeek(length, fraction) {
    return duration(length) > 0 && isFinite(fraction)
        ? Math.max(0, Math.min(length, fraction * length)) : null;
}
function relativeSeek(length, position, seconds) {
    return duration(length) > 0 && isFinite(position) && isFinite(seconds)
        ? Math.max(0, Math.min(length, position + seconds)) : null;
}
