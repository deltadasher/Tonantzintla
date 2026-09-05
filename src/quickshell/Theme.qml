pragma Singleton

import QtQuick

QtObject {
    readonly property bool adaptive: Settings.adaptivePalette && AdaptivePalette.ready
    readonly property string accentName: Settings.accentName
    readonly property var accents: ({
        "violet": "#a99cff",
        "cyan": "#72d9e7",
        "rose": "#ec8eae",
        "amber": "#e9b872"
    })
    readonly property color accent: adaptive ? AdaptivePalette.accent
        : accents[accentName] || accents.violet

    readonly property color void_: adaptive ? AdaptivePalette.void_ : "#080910"
    readonly property color mantle: adaptive ? AdaptivePalette.mantle : "#10121d"
    readonly property color elevated: adaptive ? AdaptivePalette.elevated : "#171a28"
    readonly property color line: adaptive ? AdaptivePalette.line : "#30354a"
    readonly property color lineBright: adaptive ? AdaptivePalette.lineBright : "#555d7c"
    readonly property color moon: adaptive ? AdaptivePalette.moon : "#eee9dc"
    readonly property color muted: adaptive ? AdaptivePalette.muted : "#8e94aa"
    readonly property color violet: adaptive ? AdaptivePalette.accent : "#a99cff"
    readonly property color rose: adaptive ? AdaptivePalette.rose : "#ec8eae"
    readonly property color cyan: adaptive ? AdaptivePalette.cyan : "#72d9e7"
    readonly property color warning: adaptive ? AdaptivePalette.warning : "#e9b872"
    readonly property color danger: adaptive ? AdaptivePalette.danger : "#ed7d8f"
    readonly property color success: adaptive ? AdaptivePalette.success : "#77d6ae"
    readonly property color glass: Qt.rgba(mantle.r, mantle.g, mantle.b, 0.96)
    readonly property color veil: Qt.rgba(void_.r, void_.g, void_.b, 0.76)
    readonly property color accentVeil: Qt.rgba(accent.r, accent.g, accent.b, 0.13)
    readonly property color accentLine: Qt.rgba(accent.r, accent.g, accent.b, 0.52)

    // Boundary-free interaction language. Resting controls disappear into the
    // surface; hover and selection are communicated by filled light, never a
    // one-pixel rectangle around every object.
    readonly property color controlRest: Qt.rgba(moon.r, moon.g, moon.b, 0.035)
    readonly property color controlHover: Qt.rgba(moon.r, moon.g, moon.b, 0.095)
    readonly property color controlActive: Qt.rgba(accent.r, accent.g, accent.b, 0.24)
    readonly property color controlDanger: Qt.rgba(danger.r, danger.g, danger.b, 0.20)
    readonly property color fieldRest: Qt.rgba(void_.r, void_.g, void_.b, 0.32)
    readonly property color fieldFocus: Qt.rgba(accent.r, accent.g, accent.b, 0.15)

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
        if (module === "battery" || module === "tools" || module === "timer" || module === "guide")
            return warning;
        return accent;
    }

    function moduleSecondary(module) {
        if (module === "focus" || module === "timer" || module === "calendar")
            return cyan;
        if (module === "battery")
            return rose;
        if (module === "network")
            return cyan;
        return accent;
    }

    readonly property int barHeight: 44
    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 13
    readonly property int radiusLarge: 20
    readonly property int motionFast: 120
    readonly property int motionNormal: 220
    readonly property int motionSlow: 420
    readonly property string fontText: Settings.fontText
    readonly property string fontDisplay: Settings.fontDisplay
    readonly property string fontMono: Settings.fontMono
    readonly property string fontIcon: Settings.fontIcon
}
