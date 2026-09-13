pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "components/BarLayout.js" as BarLayout
import "components/BarPlacement.js" as BarPlacement

QtObject {
    id: root

    property bool debug: Quickshell.env("TONANTZINTLA_DEBUG") === "1"
    property bool persistenceReady: false
    property int layoutRevision: 0

    // Every persisted setting is declared exactly once, on the JsonAdapter
    // below. These aliases keep the public Settings.<name> surface stable;
    // writes flow into the adapter, which debounces a save to disk.
    property alias compact: settingsAdapter.compact
    property alias motion: settingsAdapter.motion
    property alias barIconMotion: settingsAdapter.barIconMotion
    property alias osdVolume: settingsAdapter.osdVolume
    property alias osdMicrophone: settingsAdapter.osdMicrophone
    property alias osdBrightness: settingsAdapter.osdBrightness
    property alias osdDuration: settingsAdapter.osdDuration
    property alias joinedSurfaces: settingsAdapter.joinedSurfaces
    property alias animateStars: settingsAdapter.animateStars
    property alias atmosphereStyle: settingsAdapter.atmosphereStyle
    property alias adaptivePalette: settingsAdapter.adaptivePalette
    property alias motionStyle: settingsAdapter.motionStyle
    property alias accentName: settingsAdapter.accentName
    property alias typographyProfile: settingsAdapter.typographyProfile
    property alias fontText: settingsAdapter.fontText
    property alias fontDisplay: settingsAdapter.fontDisplay
    property alias fontMono: settingsAdapter.fontMono
    property alias fontIcon: settingsAdapter.fontIcon
    property alias barMode: settingsAdapter.barMode
    property alias barMargin: settingsAdapter.barMargin
    property alias barOpacity: settingsAdapter.barOpacity
    property alias quickActionsEnabled: settingsAdapter.quickActionsEnabled
    property alias quickActionsEdge: settingsAdapter.quickActionsEdge
    property alias umbraMotion: settingsAdapter.umbraMotion
    property alias idleLockEnabled: settingsAdapter.idleLockEnabled
    property alias idleLockMinutes: settingsAdapter.idleLockMinutes
    property alias umbraUseWallpaper: settingsAdapter.umbraUseWallpaper
    property alias umbraBlurWallpaper: settingsAdapter.umbraBlurWallpaper
    property alias umbraShowMedia: settingsAdapter.umbraShowMedia
    property alias umbraShowWeather: settingsAdapter.umbraShowWeather
    property alias umbraPamService: settingsAdapter.umbraPamService
    property alias showLauncherButton: settingsAdapter.showLauncherButton
    property alias showSettingsButton: settingsAdapter.showSettingsButton
    property alias showWorkspaces: settingsAdapter.showWorkspaces
    property alias showFocusedWindow: settingsAdapter.showFocusedWindow
    property alias showSystemStats: settingsAdapter.showSystemStats
    property alias showAudio: settingsAdapter.showAudio
    property alias showMedia: settingsAdapter.showMedia
    property alias showMediaProgress: settingsAdapter.showMediaProgress
    property alias showMediaTime: settingsAdapter.showMediaTime
    property alias showTray: settingsAdapter.showTray
    property alias showNetworkLabel: settingsAdapter.showNetworkLabel
    property alias showBluetooth: settingsAdapter.showBluetooth
    property alias showBrightness: settingsAdapter.showBrightness
    property alias showBattery: settingsAdapter.showBattery
    property alias showMicrophone: settingsAdapter.showMicrophone
    property alias showSeconds: settingsAdapter.showSeconds
    property alias showDate: settingsAdapter.showDate
    property alias doNotDisturb: settingsAdapter.doNotDisturb
    property alias launcherMaxResults: settingsAdapter.launcherMaxResults
    property alias showAppDescriptions: settingsAdapter.showAppDescriptions
    property alias wallpaperColumns: settingsAdapter.wallpaperColumns
    property alias wallpaperPath: settingsAdapter.wallpaperPath
    property alias wallpaperKind: settingsAdapter.wallpaperKind
    property alias wallpaperOutputs: settingsAdapter.wallpaperOutputs
    property alias wallpaperTransition: settingsAdapter.wallpaperTransition
    property alias weatherEnabled: settingsAdapter.weatherEnabled
    property alias weatherLocation: settingsAdapter.weatherLocation
    property alias temperatureUnit: settingsAdapter.temperatureUnit
    property alias terminal: settingsAdapter.terminal
    property alias browser: settingsAdapter.browser
    property alias fileManager: settingsAdapter.fileManager
    property alias dateFormat: settingsAdapter.dateFormat

    property alias barPosition: settingsAdapter.barPosition
    property alias barHeightProfile: settingsAdapter.barHeightProfile
    property alias clock12h: settingsAdapter.clock12h
    property alias showBatteryPercent: settingsAdapter.showBatteryPercent
    property alias ephemerisStyle: settingsAdapter.ephemerisStyle
    property alias motionSpeedProfile: settingsAdapter.motionSpeedProfile
    property alias defaultLaunchTab: settingsAdapter.defaultLaunchTab
    property alias showTabApps: settingsAdapter.showTabApps
    property alias showTabMedia: settingsAdapter.showTabMedia
    property alias showTabCalendar: settingsAdapter.showTabCalendar
    property alias showTabWalls: settingsAdapter.showTabWalls
    property alias showTabClipboard: settingsAdapter.showTabClipboard
    property alias showTabCapture: settingsAdapter.showTabCapture
    property alias notificationPosition: settingsAdapter.notificationPosition
    property alias enableCalculator: settingsAdapter.enableCalculator
    property alias barLayoutHorizontal: settingsAdapter.barLayoutHorizontal
    property alias barLayoutVertical: settingsAdapter.barLayoutVertical
    property alias barOutputOverrides: settingsAdapter.barOutputOverrides
    property alias barIslandSpacing: settingsAdapter.barIslandSpacing
    property alias barIslandPlacements: settingsAdapter.barIslandPlacements
    property alias barThicknessPreset: settingsAdapter.barThicknessPreset

    readonly property var defaultLayoutHorizontal: ({
        "start": ["launcher", "workspaces", "media", "window_title"],
        "center": ["clock"],
        "end": ["system_stats", "status", "tray", "controls"]
    })

    readonly property var defaultLayoutVertical: ({
        "start": ["launcher", "workspaces"],
        "center": ["clock"],
        "end": ["system_stats", "status", "tray", "controls"]
    })

    readonly property var activeLayoutHorizontal: {
        return getBarLayout(false);
    }

    readonly property var activeLayoutVertical: {
        return getBarLayout(true);
    }

    function getBarLayout(isVertical) {
        const raw = isVertical ? barLayoutVertical : barLayoutHorizontal;
        const fallback = isVertical ? defaultLayoutVertical : defaultLayoutHorizontal;
        return BarLayout.normalize(raw, fallback);
    }

    function saveBarLayout(isVertical, layout) {
        const jsonStr = JSON.stringify(BarLayout.normalize(layout,
            isVertical ? defaultLayoutVertical : defaultLayoutHorizontal));
        if (isVertical) {
            barLayoutVertical = jsonStr;
        } else {
            barLayoutHorizontal = jsonStr;
        }
        layoutRevision++;
    }

    function resetBarLayout(isVertical) {
        if (isVertical) {
            barLayoutVertical = "";
        } else {
            barLayoutHorizontal = "";
        }
    }

    function moveIsland(isVertical, zoneName, fromIndex, toIndex) {
        const layout = getBarLayout(isVertical);
        const zone = layout[zoneName];
        if (!zone || fromIndex < 0 || fromIndex >= zone.length || toIndex < 0 || toIndex >= zone.length)
            return;
        const item = zone.splice(fromIndex, 1)[0];
        zone.splice(toIndex, 0, item);
        saveBarLayout(isVertical, layout);
    }

    function transferIsland(isVertical, fromZone, toZone, islandId, targetIndex) {
        const layout = getBarLayout(isVertical);
        saveBarLayout(isVertical, BarLayout.transfer(layout, fromZone, toZone, islandId, targetIndex));
    }

    function addIslandToZone(isVertical, zone, islandId, targetIndex) {
        const layout = getBarLayout(isVertical);
        saveBarLayout(isVertical, BarLayout.addIsland(layout, zone, islandId, targetIndex));
    }

    function removeIslandFromLayout(isVertical, islandId) {
        const layout = getBarLayout(isVertical);
        saveBarLayout(isVertical, BarLayout.removeIsland(layout, islandId));
    }

    function getEffectiveBarPosition(outputName) {
        if (!outputName) return barPosition;
        try {
            const overrides = JSON.parse(barOutputOverrides || "{}");
            if (overrides[outputName] && overrides[outputName].barPosition)
                return overrides[outputName].barPosition;
        } catch (_) {}
        return barPosition;
    }

    function getEffectiveBarLayout(outputName, isVertical) {
        if (outputName) {
            try {
                const overrides = JSON.parse(barOutputOverrides || "{}");
                if (overrides[outputName]) {
                    const key = isVertical ? "barLayoutVertical" : "barLayoutHorizontal";
                    if (overrides[outputName][key]) {
                        const fallback = isVertical ? defaultLayoutVertical : defaultLayoutHorizontal;
                        return BarLayout.normalize(overrides[outputName][key], fallback);
                    }
                }
            } catch (_) {}
        }
        return getBarLayout(isVertical);
    }

    function getEdgeBarLayout(outputName, edge) {
        const primaryEdge = getEffectiveBarPosition(outputName);
        const primaryVertical = primaryEdge === "left" || primaryEdge === "right";
        const base = getEffectiveBarLayout(outputName, primaryVertical);
        return BarPlacement.layoutFor(base, primaryEdge, edge,
            barIslandPlacements, outputName);
    }

    function edgeHasIslands(outputName, edge) {
        const layout = getEdgeBarLayout(outputName, edge);
        return layout.start.length + layout.center.length + layout.end.length > 0;
    }

    function getIslandPlacement(outputName, islandId) {
        const placements = BarPlacement.output(barIslandPlacements, outputName);
        return placements[islandId] || null;
    }

    function placeIsland(outputName, islandId, edge, zone, orderedIds) {
        let next = barIslandPlacements;
        const screens = Quickshell.screens;
        if (screens && screens.length > 0) {
            for (let i = 0; i < screens.length; ++i)
                next = JSON.stringify(BarPlacement.place(next, screens[i].name, islandId, edge, zone, orderedIds));
        } else {
            next = JSON.stringify(BarPlacement.place(next, outputName, islandId, edge, zone, orderedIds));
        }
        barIslandPlacements = next;
        layoutRevision++;
    }

    function clearIslandPlacement(outputName, islandId) {
        let next = barIslandPlacements;
        const screens = Quickshell.screens;
        if (screens && screens.length > 0) {
            for (let i = 0; i < screens.length; ++i)
                next = JSON.stringify(BarPlacement.clear(next, screens[i].name, islandId));
        } else {
            next = JSON.stringify(BarPlacement.clear(next, outputName, islandId));
        }
        barIslandPlacements = next;
        layoutRevision++;
    }

    function setOutputOverride(outputName, key, value) {
        if (!outputName) return;
        let overrides = {};
        try { overrides = JSON.parse(barOutputOverrides || "{}"); } catch (_) {}
        if (!overrides[outputName]) overrides[outputName] = {};
        overrides[outputName][key] = value;
        barOutputOverrides = JSON.stringify(overrides);
    }

    function clearOutputOverrides(outputName) {
        if (!outputName) return;
        let overrides = {};
        try { overrides = JSON.parse(barOutputOverrides || "{}"); } catch (_) {}
        delete overrides[outputName];
        barOutputOverrides = JSON.stringify(overrides);
    }

    readonly property string clockFormat: clock12h
        ? (showSeconds ? "hh:mm:ss AP" : "hh:mm AP")
        : (showSeconds ? "HH:mm:ss" : "HH:mm")
    readonly property string configRoot: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME") || "";
        const home = Quickshell.env("HOME") || "/tmp";
        return (xdg.length > 0 ? xdg : home + "/.config")
            + "/tonantzintla";
    }
    readonly property string configPath: configRoot + "/settings.json"

    function applyBarPreset(name) {
        if (name === "minimal") {
            showSystemStats = false;
            showNetworkLabel = false;
            showBluetooth = false;
            showBrightness = false;
            showBattery = true;
            showMicrophone = false;
            showTray = false;
            showDate = false;
        } else if (name === "telemetry") {
            showSystemStats = true;
            showNetworkLabel = true;
            showBluetooth = true;
            showBrightness = true;
            showBattery = true;
            showMicrophone = true;
            showTray = true;
            showDate = true;
        } else {
            showSystemStats = true;
            showNetworkLabel = true;
            showBluetooth = true;
            showBrightness = false;
            showBattery = true;
            showMicrophone = true;
            showTray = true;
            showDate = true;
        }
    }

    function applyDesktopPreset(name) {
        if (name === "serpantinum") {
            accentName = "violet";
            barPosition = "top";
            barMode = "capsules";
            barHeightProfile = "nominal";
            ephemerisStyle = "deck";
            motionSpeedProfile = "fluid";
            applyTypographyPreset("serpantinum");
            applyBarLayoutPreset({start: ["launcher", "workspaces", "media", "window_title"], center: ["clock"], end: ["system_stats", "status", "tray", "controls"]});
        } else if (name === "caelestia") {
            accentName = "cyan";
            barPosition = "left";
            barMode = "capsules";
            barHeightProfile = "compact";
            ephemerisStyle = "spotlight";
            motionSpeedProfile = "snappy";
            applyTypographyPreset("readable");
            applyBarLayoutPreset({start: ["launcher", "workspaces"], center: ["clock"], end: ["status", "tray", "controls"]});
        } else if (name === "solaris") {
            accentName = "amber";
            barPosition = "bottom";
            barMode = "docked";
            barHeightProfile = "nominal";
            ephemerisStyle = "spotlight";
            motionSpeedProfile = "fluid";
            clock12h = false;
            applyBarLayoutPreset({start: ["launcher", "workspaces", "media"], center: ["clock"], end: ["system_stats", "status", "tray", "controls"]});
        } else if (name === "cyberpunk") {
            accentName = "rose";
            barPosition = "right";
            barMode = "capsules";
            barHeightProfile = "compact";
            ephemerisStyle = "spotlight";
            motionSpeedProfile = "instant";
            applyTypographyPreset("serpantinum");
            applyBarLayoutPreset({start: ["launcher", "workspaces"], center: ["clock", "media"], end: ["status", "tray", "controls"]});
        } else if (name === "minimalist") {
            accentName = "silver";
            barPosition = "top";
            barMode = "floating";
            barHeightProfile = "compact";
            ephemerisStyle = "spotlight";
            motionSpeedProfile = "snappy";
            applyBarPreset("minimal");
            applyBarLayoutPreset({start: ["launcher"], center: ["clock"], end: ["status"]});
        }
    }

    function applyBarLayoutPreset(layout) {
        barLayoutHorizontal = JSON.stringify(BarLayout.normalize(layout, defaultLayoutHorizontal));
        barLayoutVertical = JSON.stringify(BarLayout.normalize(layout, defaultLayoutVertical));
        barIslandPlacements = "";
        barOutputOverrides = "";
    }

    function migrateLegacyPersonalDefaults() {
        if (settingsAdapter.universalProfileVersion >= 1)
            return;
        // Before 1.0 these values described the original development machine.
        // Clear only exact legacy defaults; explicit user choices survive.
        if (terminal === "terminology")
            terminal = "";
        if (browser === "firefox")
            browser = "";
        if (fileManager === "nautilus")
            fileManager = "";
        if (weatherLocation === "Oslo, Norway")
            weatherLocation = "";
        settingsAdapter.universalProfileVersion = 1;
    }

    function applyTypographyPreset(name) {
        typographyProfile = name;
        if (name === "readable") {
            fontText = "Noto Sans";
            fontDisplay = "JetBrains Mono";
            fontMono = "JetBrains Mono";
            fontIcon = "Iosevka Nerd Font";
        } else if (name === "system") {
            fontText = "sans-serif";
            fontDisplay = "sans-serif";
            fontMono = "monospace";
            fontIcon = "Iosevka Nerd Font";
        } else {
            // Serpantinum's visual voice is overwhelmingly JetBrains Mono,
            // with Iosevka Nerd Font reserved for symbolic glyphs.
            fontText = "JetBrains Mono";
            fontDisplay = "JetBrains Mono";
            fontMono = "JetBrains Mono";
            fontIcon = "Iosevka Nerd Font";
        }
    }

    property Timer saveTimer: Timer {
        interval: 220
        onTriggered: root.settingsFile.writeAdapter()
    }

    property Process ensureDirectory: Process {
        command: ["mkdir", "-p", root.configRoot]
        running: true
        onRunningChanged: {
            if (!running)
                root.settingsFile.reload();
        }
    }

    property FileView settingsFile: FileView {
        path: root.configPath
        watchChanges: true
        printErrors: root.debug
        onLoaded: {
            root.persistenceReady = true;
            root.migrateLegacyPersonalDefaults();
        }
        onFileChanged: reload()
        onAdapterUpdated: {
            if (root.persistenceReady)
                root.saveTimer.restart();
        }
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound && !root.ensureDirectory.running) {
                root.persistenceReady = true;
                root.migrateLegacyPersonalDefaults();
                writeAdapter();
            }
        }

        // qmllint disable unresolved-type
        adapter: JsonAdapter {
            id: settingsAdapter
            property bool compact: false
            property bool motion: true
            property bool barIconMotion: true
            property bool osdVolume: true
            property bool osdMicrophone: true
            property bool osdBrightness: true
            property int osdDuration: 1450
            property bool joinedSurfaces: false
            property bool animateStars: true
            property string atmosphereStyle: "nominal"
            property bool adaptivePalette: false
            property string motionStyle: "rise"
            property string accentName: "violet"
            property string typographyProfile: "serpantinum"
            property int universalProfileVersion: 0
            property string fontText: "JetBrains Mono"
            property string fontDisplay: "JetBrains Mono"
            property string fontMono: "JetBrains Mono"
            property string fontIcon: "Iosevka Nerd Font"
            property string barMode: "capsules"
            property int barMargin: 12
            property real barOpacity: 0.94
            property bool quickActionsEnabled: true
            property string quickActionsEdge: "right"
            property bool umbraMotion: true
            property bool idleLockEnabled: true
            property int idleLockMinutes: 5
            property bool umbraUseWallpaper: true
            property bool umbraBlurWallpaper: true
            property bool umbraShowMedia: true
            property bool umbraShowWeather: true
            property string umbraPamService: "login"
            property bool showLauncherButton: true
            property bool showSettingsButton: true
            property bool showWorkspaces: true
            property bool showFocusedWindow: true
            property bool showSystemStats: true
            property bool showAudio: true
            property bool showMedia: true
            property bool showMediaProgress: true
            property bool showMediaTime: true
            property bool showTray: true
            property bool showNetworkLabel: true
            property bool showBluetooth: true
            property bool showBrightness: true
            property bool showBattery: true
            property bool showMicrophone: true
            property bool showSeconds: true
            property bool showDate: true
            property bool doNotDisturb: false
            property int launcherMaxResults: 80
            property bool showAppDescriptions: true
            property int wallpaperColumns: 3
            property string wallpaperPath: ""
            property string wallpaperKind: "image"
            property string wallpaperOutputs: "all"
            property string wallpaperTransition: "any"
            property bool weatherEnabled: true
            property string weatherLocation: ""
            property string temperatureUnit: "celsius"
            property string terminal: ""
            property string browser: ""
            property string fileManager: ""
            property string dateFormat: "yyyy · MM · dd"
            property string barPosition: "top"
            property string barHeightProfile: "nominal"
            property bool clock12h: false
            property bool showBatteryPercent: false
            property string ephemerisStyle: "spotlight"
            property string motionSpeedProfile: "fluid"
            property string defaultLaunchTab: "apps"
            property bool showTabApps: true
            property bool showTabMedia: true
            property bool showTabCalendar: true
            property bool showTabWalls: true
            property bool showTabClipboard: true
            property bool showTabCapture: true
            property string notificationPosition: "top-right"
            property bool enableCalculator: true
            property string barLayoutHorizontal: ""
            property string barLayoutVertical: ""
            property string barOutputOverrides: ""
            property int barIslandSpacing: 4
            property string barIslandPlacements: ""
            property string barThicknessPreset: "nominal"
        }
    }
}
