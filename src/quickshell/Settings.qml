pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool debug: Quickshell.env("TONANTZINTLA_DEBUG") === "1"
    property bool persistenceReady: false

    // Every persisted setting is declared exactly once, on the JsonAdapter
    // below. These aliases keep the public Settings.<name> surface stable;
    // writes flow into the adapter, which debounces a save to disk.
    property alias compact: settingsAdapter.compact
    property alias motion: settingsAdapter.motion
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

    readonly property string clockFormat: showSeconds ? "HH:mm:ss" : "HH:mm"
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
        }
    }
}
