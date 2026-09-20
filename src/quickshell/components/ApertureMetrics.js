.pragma library

// Shared by Aperture's real surface and the panels that must clear it.
function bodyThickness(edge, compact, profile, normalHeight) {
    const vertical = edge === "left" || edge === "right";
    if (compact) return vertical ? 42 : 36;
    if (profile === "tall" || profile === "spacious") return vertical ? 54 : 52;
    return vertical ? 48 : normalHeight;
}
function shellMargin(mode, margin) { return mode === "docked" ? 0 : margin; }
function clearance(edge, occupied, compact, profile, normalHeight, mode, margin) {
    if (!occupied) return 16;
    return bodyThickness(edge, compact, profile, normalHeight)
        + shellMargin(mode, margin) * 2 + 8;
}
