.pragma library
var entries = [
    {section:"umbra-layout", label:"Lock layout", terms:"umbra clock layout editor grid snap alignment resize rotation opacity undo redo background video wallpaper fingerprint battery keyboard"},
    {section:"optics", label:"Control effects", terms:"glass lens frosted refraction dispersion finish roundness corner radius opacity transparency control family aperture dock instruments umbra"},
    {section:"appearance", label:"Appearance", terms:"logo identity custom colors button style theme accent colour color font typography motion animation reduced stars gravity material compact liquid glass frost refraction light dark automatic"},
    {section:"launcher", label:"Panels", terms:"bar finish glass workspace pills dots track matrix rounding corners rim aperture bar layout position dock scope indicators neighbor hover hide exclusive islands clock faces telemetry arc trace density launcher width rows command palette calculator app descriptions osd vertical horizontal feedback capslock numlock airplane position preview"},
    {section:"umbra", label:"Lock screen", terms:"umbra password black hole idle timeout lock wallpaper"},
    {section:"system", label:"System", terms:"weather location units terminal browser file manager notifications sound volume right click artwork placement"},
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
