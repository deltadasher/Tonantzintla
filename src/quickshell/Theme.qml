pragma Singleton

import QtQuick
import "components/ThemeMode.js" as ThemeMode
import "components/ThemeIdentity.js" as Identity
import Quickshell
import "components/SpectralPalette.js" as SpectralPalette
import "components/IconFontGlyphs.js" as IconFontGlyphs

QtObject {
    id: themeTokens
    // Stable preset values prevent identity/mode/palette binding cycles.
    readonly property var identityPresets: ({violet: "#9874cd", cyan: "#83dad9", rose: "#ee927f", amber: "#e9b872", emerald: "#467b50", solar: "#c44f28", silver: "#c8cdd3"})
    readonly property string identitySelection: Settings.themeIdentity === "auto" ? "auto" : Identity.get(Settings.themeIdentity).id
    readonly property string identityColor: Identity.sourceColor(Settings.spectralColors.accent, Settings.paletteSeedColor, (Settings.adaptivePalette && AdaptivePalette.ready && Identity.validColor(AdaptivePalette.sourceColor) && AdaptivePalette.appliedSource === Settings.wallpaperPath && AdaptivePalette.appliedSeed === Settings.paletteSeedColor ? AdaptivePalette.sourceColor : identityPresets[Settings.accentName]))
    readonly property var identity: Identity.resolve(identitySelection, identityColor)
    readonly property url identitySource: Qt.resolvedUrl("assets/theme-marks/" + identity.id + ".svg")
    function modeForSeed(seed) {
        if (identitySelection !== "auto" && identitySelection !== "wabi-sabi")
            return ThemeMode.resolve(Settings.themeMode, "", "", Identity.recommendedMode(identitySelection, ""));
        return ThemeMode.resolve(Settings.themeMode, seed, Settings.spectralColors.accent,
            Identity.recommendedMode(identitySelection, Identity.sourceColor(Settings.spectralColors.accent, seed, identityColor)));
    }
    readonly property string mode: modeForSeed(Settings.paletteSeedColor)
    readonly property bool isLight: mode === "light"
    readonly property bool lockIsLight: identity.lockLight !== undefined ? identity.lockLight : isLight
    readonly property bool adaptive: Settings.adaptivePalette && AdaptivePalette.ready
        && AdaptivePalette.appliedMode === mode
        && AdaptivePalette.appliedSeed === Settings.paletteSeedColor
        && AdaptivePalette.appliedSource === Settings.wallpaperPath
    readonly property string accentName: Settings.accentName
    readonly property var accents: ({
        "violet": (isLight ? "#6653a6" : "#a99cff"),
        "cyan": (isLight ? "#006875" : "#72d9e7"),
        "rose": (isLight ? "#9a4565" : "#ec8eae"),
        "amber": (isLight ? "#805613" : "#e9b872"),
        "emerald": (isLight ? "#236b50" : "#77d6ae"),
        "solar": (isLight ? "#99481f" : "#ff9e64"),
        "silver": (isLight ? "#55596a" : "#d4d8e8")
    })
    function channel(role, fallback) {
        return SpectralPalette.resolve(Settings.spectralColors, role, String(fallback), [String(void_), String(mantle), String(elevated)]);
    }
    property color accent: channel("accent", adaptive ? AdaptivePalette.accent
        : accents[accentName] || accents.violet)

    property color void_: adaptive ? AdaptivePalette.void_ : (isLight ? "#f8f7fc" : "#080910")
    property color mantle: adaptive ? AdaptivePalette.mantle : (isLight ? "#f0eff7" : "#10121d")
    property color elevated: adaptive ? AdaptivePalette.elevated : (isLight ? "#e7e6ef" : "#171a28")
    property color line: adaptive ? AdaptivePalette.line : (isLight ? "#c7c5d6" : "#30354a")
    property color lineBright: adaptive ? AdaptivePalette.lineBright : (isLight ? "#787589" : "#555d7c")
    property color moon: adaptive ? AdaptivePalette.moon : (isLight ? "#23232e" : "#eee9dc")
    property color muted: adaptive ? AdaptivePalette.muted : (isLight ? "#5b596c" : "#8e94aa")
    property color violet: adaptive ? AdaptivePalette.accent : (isLight ? "#6653a6" : "#a99cff")
    property color rose: channel("rose", adaptive ? AdaptivePalette.rose : (isLight ? "#9a4565" : "#ec8eae"))
    property color cyan: channel("cyan", adaptive ? AdaptivePalette.cyan : (isLight ? "#006875" : "#72d9e7"))
    property color warning: channel("warning", adaptive ? AdaptivePalette.warning : (isLight ? "#805613" : "#e9b872"))
    property color danger: channel("danger", adaptive ? AdaptivePalette.danger : (isLight ? "#a93649" : "#ed7d8f"))
    property color success: channel("success", adaptive ? AdaptivePalette.success : (isLight ? "#236b50" : "#77d6ae"))
    // Color changes share one short, interruptible transition. Instant/reduced
    // motion changes remain immediate, including the mode-safe fallback palette.
    Behavior on void_ { enabled: motionScale > 0; ColorAnimation { duration: Math.round(180 * motionScale) } }
    Behavior on mantle { enabled: motionScale > 0; ColorAnimation { duration: Math.round(180 * motionScale) } }
    Behavior on elevated { enabled: motionScale > 0; ColorAnimation { duration: Math.round(180 * motionScale) } }
    Behavior on line { enabled: motionScale > 0; ColorAnimation { duration: Math.round(180 * motionScale) } }
    Behavior on lineBright { enabled: motionScale > 0; ColorAnimation { duration: Math.round(180 * motionScale) } }
    Behavior on moon { enabled: motionScale > 0; ColorAnimation { duration: Math.round(180 * motionScale) } }
    Behavior on muted { enabled: motionScale > 0; ColorAnimation { duration: Math.round(180 * motionScale) } }
    Behavior on accent { enabled: motionScale > 0; ColorAnimation { duration: Math.round(180 * motionScale) } }
    Behavior on violet { enabled: motionScale > 0; ColorAnimation { duration: Math.round(180 * motionScale) } }
    Behavior on rose { enabled: motionScale > 0; ColorAnimation { duration: Math.round(180 * motionScale) } }
    Behavior on cyan { enabled: motionScale > 0; ColorAnimation { duration: Math.round(180 * motionScale) } }
    Behavior on warning { enabled: motionScale > 0; ColorAnimation { duration: Math.round(180 * motionScale) } }
    Behavior on danger { enabled: motionScale > 0; ColorAnimation { duration: Math.round(180 * motionScale) } }
    Behavior on success { enabled: motionScale > 0; ColorAnimation { duration: Math.round(180 * motionScale) } }

    property color onAccent: ThemeMode.foreground(String(themeTokens.accent))
    onAccentChanged: onAccent = ThemeMode.foreground(String(themeTokens.accent))
    readonly property color glass: Qt.rgba(mantle.r, mantle.g, mantle.b, 0.96)
    readonly property color veil: Qt.rgba(void_.r, void_.g, void_.b, 0.76)
    readonly property color accentVeil: Qt.rgba(accent.r, accent.g, accent.b, 0.13)
    readonly property color accentLine: Qt.rgba(accent.r, accent.g, accent.b, 0.52)

    readonly property real controlFillOpacity: Math.max(0, Math.min(1, Settings.controlOpacity))
    function controlAlpha(alpha) { return alpha * controlFillOpacity; }
    // Soft control tints sit over the solid instrument backing.
    readonly property color controlRest: Qt.rgba(moon.r, moon.g, moon.b, controlAlpha(0.035))
    readonly property color controlHover: Qt.rgba(moon.r, moon.g, moon.b, controlAlpha(0.095))
    readonly property color controlActive: Qt.rgba(accent.r, accent.g, accent.b, controlAlpha(0.24))
    readonly property color controlSelected: Qt.rgba(accent.r, accent.g, accent.b, controlAlpha(0.12))
    readonly property color controlPressed: Qt.rgba(accent.r, accent.g, accent.b, controlAlpha(0.19))
    readonly property color focusRing: Qt.rgba(accent.r, accent.g, accent.b, 0.85)
    readonly property color controlDanger: Qt.rgba(danger.r, danger.g, danger.b, controlAlpha(0.20))
    readonly property color fieldRest: Qt.rgba(void_.r, void_.g, void_.b, controlAlpha(0.32))
    readonly property color fieldFocus: Qt.rgba(accent.r, accent.g, accent.b, controlAlpha(0.15))

    // Aperture deliberately uses a quieter palette than the larger Ephemeris
    // surfaces.  Neutral glass carries the silhouette; chroma communicates
    // state instead of outlining every control.
    readonly property color barHairline: Qt.rgba(moon.r, moon.g, moon.b, 0.07)
    readonly property color barHairlineHover: Qt.rgba(moon.r, moon.g, moon.b, 0.14)
    readonly property color barNeutral: Qt.rgba(moon.r, moon.g, moon.b, 0.055)
    readonly property color barNeutralHover: Qt.rgba(moon.r, moon.g, moon.b, 0.10)
    readonly property color barAccentVeil: Qt.rgba(accent.r, accent.g, accent.b, 0.09)

    // Tonantzintla instrument channels. These are semantic rather than decorative:
    // a module keeps the same spectral identity in its header, field, and state.
    function moduleAccent(module) {
        if (module === "audio" || module === "system" || module === "quickstats")
            return cyan;
        if (module === "media" || module === "notifications" || module === "capture")
            return rose;
        if (module === "network")
            return success;
        if (module === "battery" || module === "guide")
            return warning;
        return accent;
    }

    function moduleSecondary(module) {
        if (module === "focus" || module === "calendar")
            return cyan;
        if (module === "battery")
            return rose;
        if (module === "network")
            return cyan;
        return accent;
    }

    readonly property int barHeight: Settings.barHeightProfile === "compact" ? 36
        : Settings.barHeightProfile === "tall" ? 52 : 44
    readonly property int radiusSmall: Math.max(0, Math.min(24, Settings.controlRadius))
    readonly property int radiusMedium: 13
    readonly property int radiusLarge: 20
    // Compact instrument controls share a rhythm; celestial silhouettes remain
    // free to use their own proportions.
    readonly property int spaceXs: 4
    readonly property int spaceSm: 8
    readonly property int spaceMd: 12
    readonly property int spaceLg: 16
    readonly property int spaceXl: 20
    readonly property int textMicro: 10
    readonly property int textCaption: 11
    readonly property int textLabel: 12
    readonly property int textBody: 13
    readonly property int textTitle: 22
    readonly property int controlHeight: 32
    readonly property int switchWidth: 34
    readonly property int switchHeight: 18
    readonly property int switchKnob: 12
    readonly property real motionScale: !Settings.motion ? 0
        : Settings.motionSpeedProfile === "instant" ? 0
        : Settings.motionSpeedProfile === "snappy" ? 0.55
        : Settings.motionSpeedProfile === "cinematic" ? 1.6 : 1.0
    readonly property bool motionEnabled: motionScale > 0
    function duration(milliseconds) { return Math.max(0, Math.round(milliseconds * motionScale)); }
    readonly property int surfaceEnterDuration: Math.round(280 * motionScale)
    readonly property int surfaceExitDuration: Math.round(190 * motionScale)
    readonly property int effectDuration: Math.round(140 * motionScale)
    readonly property int motionFast: duration(120)
    readonly property int motionNormal: duration(220)
    readonly property int motionSlow: duration(420)
    readonly property string fontText: Settings.fontText
    readonly property string fontDisplay: Settings.fontDisplay
    readonly property string fontMono: Settings.fontMono
    // Keep the public configured family intact. Only proven icon strings use
    // the bundled subset; custom families and other Unicode retain their face.
    readonly property string fontIcon: Settings.fontIcon
    readonly property bool iconFontDefault: Settings.fontIcon === "Iosevka Nerd Font"
    readonly property FontLoader iconFontLoader: FontLoader {
        source: Settings.fontIcon === "Iosevka Nerd Font"
            ? "file://" + Quickshell.shellDir.split("/").map(encodeURIComponent).join("/") + "/../assets/fonts/TonantzintlaSymbols-Regular.ttf" : ""
    }
    readonly property bool iconFontReady: iconFontDefault && iconFontLoader.status === FontLoader.Ready
    readonly property bool iconFontError: iconFontDefault && iconFontLoader.status === FontLoader.Error
    function iconFamily(value) {
        return iconFontReady && IconFontGlyphs.covers(value) ? iconFontLoader.name : Settings.fontIcon;
    }
}
