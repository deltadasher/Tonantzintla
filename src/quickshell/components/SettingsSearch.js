.pragma library
var entries = [
    {section:"appearance", label:"Appearance", terms:"theme accent colour color font typography motion animation reduced stars transparency compact"},
    {section:"launcher", label:"Panels", terms:"aperture bar layout position dock islands launcher command palette calculator app descriptions"},
    {section:"umbra", label:"Lock screen", terms:"umbra password black hole idle timeout lock wallpaper"},
    {section:"system", label:"System", terms:"weather location units terminal browser file manager notifications sound"},
    {section:"niri", label:"Niri settings", terms:"monitor display scale output cursor mouse pointer theme hide typing"},
    {section:"extensions", label:"Features", terms:"extensions plugins capability clipboard media resonance parallax tray telemetry screenshots authentication polkit"}
];
function search(query) {
    const words = String(query || "").toLowerCase().trim().split(/\s+/).filter(Boolean);
    return entries.filter(function(entry) {
        const haystack = (entry.label + " " + entry.terms).toLowerCase();
        return words.every(function(word) { return haystack.indexOf(word) >= 0; });
    });
}
