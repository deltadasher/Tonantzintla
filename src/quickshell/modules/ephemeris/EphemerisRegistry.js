.pragma library

// Widget contract v1: the host and command palette share this local catalog.
var apiVersion = 1;
var catalog = [
    {id: "apps", title: "Blackhole command palette", code: "APP", width: 680, height: 760, placement: "left", source: "widgets/catalog/LauncherWidget.qml"},
    {id: "tools", title: "Field tools", code: "FLD", width: 900, height: 860, source: "widgets/catalog/ToolsWidget.qml"},
    {id: "walls", title: "Parallax library", code: "WAL", width: 1480, height: 860, placement: "horizon", source: "widgets/desktop/WallpaperWidget.qml"},
    {id: "clipboard", title: "Clipboard core", code: "CLP", width: 820, height: 670, source: "widgets/productivity/ClipboardWidget.qml"},
    {id: "notifications", title: "Transit signals", code: "SIG", width: 470, height: 760, placement: "right", source: "widgets/productivity/NotificationsWidget.qml"},
    {id: "settings", title: "Observatory settings", code: "CFG", width: 1050, height: 720, source: "widgets/system/SettingsWidget.qml"},
    {id: "calendar", title: "Celestial calendar", code: "CAL", width: 1480, height: 740, source: "widgets/productivity/CalendarWidget.qml"},
    {id: "capture", title: "Optics bay", code: "OPT", width: 1080, height: 650, source: "widgets/desktop/CaptureWidget.qml"},
    {id: "media", title: "Resonance console", code: "MPR", width: 1040, height: 680, placement: "left", source: "widgets/media/MediaWidget.qml"},
    {id: "network", title: "Link array", code: "NET", width: 820, height: 650, placement: "right", source: "widgets/system/NetworkWidget.qml"},
    {id: "audio", title: "Acoustic routing", code: "AUD", width: 920, height: 700, placement: "right", source: "widgets/system/AudioWidget.qml"},
    {id: "workspaces", title: "Workspace constellation", code: "NIR", width: 1120, height: 690, source: "widgets/desktop/WorkspaceWidget.qml"},
    {id: "battery", title: "Reactor telemetry", code: "PWR", width: 780, height: 590, placement: "right", source: "widgets/system/BatteryWidget.qml"},
    {id: "focus", title: "Focus orbit", code: "FCS", width: 900, height: 650, source: "widgets/productivity/FocusWidget.qml"},
    {id: "system", title: "Observatory telemetry", code: "SYS", width: 1060, height: 660, source: "widgets/system/SystemWidget.qml"},
    {id: "guide", title: "Tonantzintla flight manual", code: "GDE", width: 720, height: 900, placement: "left", source: "widgets/catalog/GuideWidget.qml"},
    {id: "quickstats", title: "Local constellation", code: "TEL", width: 680, height: 620, source: "../quickactions/TelemetryAction.qml"}
];

function widgets() { return catalog.slice(); }
function entry(name) {
    for (var i = 0; i < catalog.length; ++i)
        if (catalog[i].id === name) return catalog[i];
    return catalog[0];
}
function normalize(name) { return entry(name).id; }
function sourceFor(name) { return entry(name).source; }
function clamp(value, minimum, maximum) {
    return Math.max(Math.min(minimum, maximum), Math.min(maximum, value));
}
function getLayout(name, screenWidth, screenHeight, topClearance) {
    var spec = entry(name);
    var margin = Math.min(16, Math.max(0, screenWidth / 8));
    var usableTop = Math.min(Math.max(margin, topClearance || 72), Math.max(0, screenHeight - 1));
    var usableHeight = Math.max(1, screenHeight - usableTop - margin);
    var usableWidth = Math.max(1, screenWidth - margin * 2);
    var width = Math.min(spec.width, usableWidth);
    var height = Math.min(spec.height, usableHeight);
    var placement = spec.placement || "center";
    if (placement === "horizon") { width = usableWidth; height = usableHeight; }
    var x = Math.round((screenWidth - width) / 2);
    var y = usableTop + Math.round((usableHeight - height) / 2);
    if (placement === "left" || placement === "horizon") { x = margin; y = usableTop; }
    if (placement === "right") { x = screenWidth - width - margin; y = usableTop; }
    return { name: spec.id, x: x, y: y, width: width, height: height,
        title: spec.title, code: "EPH/" + spec.code, placement: placement };
}
