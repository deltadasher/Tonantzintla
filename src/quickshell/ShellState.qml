pragma Singleton

import QtQuick

QtObject {
    property bool ephemerisVisible: false
    property string ephemerisTab: "apps"
    property string settingsSection: "appearance"
    property bool quickActionsVisible: false
    property string quickActionTab: "timer"
    property int umbraRevealSerial: 0

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
        return widget;
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
        quickActionTab = tab || quickActionTab;
        quickActionsVisible = true;
    }

    function toggleQuickActions(tab) {
        const target = tab || quickActionTab;
        if (quickActionsVisible && quickActionTab === target)
            quickActionsVisible = false;
        else
            openQuickActions(target);
    }

    function hideQuickActions() {
        quickActionsVisible = false;
    }

    function startUmbraReveal() {
        umbraRevealSerial++;
    }
}
