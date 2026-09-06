pragma Singleton

import QtQuick
import "modules/ephemeris/EphemerisRegistry.js" as Registry

QtObject {
    property bool ephemerisVisible: false
    property string ephemerisTab: "apps"
    property string settingsSection: "appearance"
    property bool quickActionsVisible: false
    property string quickActionTab: "telemetry"
    property int umbraRevealSerial: 0
    // Session-only: leaving focus restores the user's original preferences.
    property bool deepFocus: false
    function toggleDeepFocus() { deepFocus = !deepFocus; }

    function normalizeWidget(widget) {
        if (!widget || widget.length === 0)
            return "apps";
        if (widget === "launcher" || widget === "applauncher")
            return "apps";
        if (widget === "wallpaper" || widget === "wallpapers")
            return "walls";
        if (widget === "notifications" || widget === "transit")
            return "notifications";
        if (widget === "screenshot" || widget === "screenshots" || widget === "recording")
            return "capture";
        return Registry.normalize(widget);
    }

    function openEphemeris(tab) {
        ephemerisTab = normalizeWidget(tab);
        ephemerisVisible = true;
    }

    function closeEphemeris() {
        ephemerisVisible = false;
    }

    function toggleEphemeris(tab) {
        const target = normalizeWidget(tab);
        if (ephemerisVisible && ephemerisTab === target)
            closeEphemeris();
        else
            openEphemeris(target);
    }

    function openQuickActions(tab) {
        openEphemeris("system");
    }

    function toggleQuickActions(tab) {
        toggleEphemeris("system");
    }

    function hideQuickActions() {
        quickActionsVisible = false;
    }

    function startUmbraReveal() {
        umbraRevealSerial++;
    }
}
