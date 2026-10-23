import QtQuick
import QtTest
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/modules/ephemeris"
Window {
    id: window
    width: 320; height: 280; visible: true; color: "#080910"
    property int step: 0
    property int failures: 0
    property bool inTick: false
    property int closes: 0
    function check(ok, message) { if (!ok) { failures++; console.error("CONTEXT FAIL", message); } }
    function find(item, name) {
        if (item.Accessible && item.Accessible.name === name) return item;
        for (const child of item.children || []) { const found = find(child, name); if (found) return found; }
        return null;
    }
    function findText(item, text) {
        if (item.text === text) return item;
        for (const child of item.children || []) { const found = findText(child, text); if (found) return found; }
        return null;
    }
    function visualizer(item) {
        if (item.variant !== undefined && item.levels !== undefined) return item;
        for (const child of item.children || []) { const found = visualizer(child); if (found) return found; }
        return null;
    }
    function keyChoice(name) {
        const control = find(body, name);
        check(control !== null, "control exists: " + name);
        if (!control) return;
        control.forceActiveFocus();
        events.keyClick(Qt.Key_Space, Qt.NoModifier, -1);
    }
    TestEvent { id: events }
    WidgetSettingsBody {
        id: body; anchors.fill: parent; anchors.margins: 8
        widgetId: "media"
        onCloseRequested: window.closes++
    }
    Loader { id: media; visible: false; width: 1040; height: 680; source: "../../src/quickshell/modules/ephemeris/widgets/media/MediaWidget.qml" }
    Loader { id: calendar; active: false; visible: false; width: 1480; height: 740; source: "../../src/quickshell/modules/ephemeris/widgets/productivity/CalendarWidget.qml" }
    Timer {
        interval: 180; repeat: true; running: true
        onTriggered: {
            if (window.inTick || !Settings.persistenceReady) return;
            window.inTick = true;
            try {
                if (window.step === 0) {
                    window.requestActivate();
                    keyChoice("Material: Classic");
                    keyChoice("Spectrum: Bars");
                    window.check(Settings.appearanceFor("media") === "classic", "material changes live setting");
                    window.check(Settings.resonanceVisualizer === "bars", "spectrum changes existing consumer setting");
                    window.check(media.status === Loader.Ready, "real media loads");
                    const face = visualizer(media.item);
                    window.check(face && face.variant === "bars", "real media consumes spectrum preference");
                    window.check(findText(media.item, "Spectrum") === null, "playback face has no settings box");
                    body.widgetId = "walls";
                } else if (window.step === 1) {
                    window.check(findText(body, "Columns") === null, "no inert orbit columns control");
                    keyChoice("Wallpaper transition: Swipe");
                    window.check(Settings.wallpaperTransition === "swipe", "wallpaper backend transition preference");
                    body.widgetId = "calendar";
                } else if (window.step === 2) {
                    window.check(findText(body, "Show seconds") === null && findText(body, "Show date in bar") === null, "calendar context excludes unrelated bar clock flags");
                    keyChoice("Opening view: Earth");
                    window.check(Settings.calendarDefaultMode === 2, "calendar preference");
                    calendar.active = true;
                } else if (window.step === 3) {
                    window.check(calendar.status === Loader.Ready, "real calendar loads");
                    window.check(calendar.item.calendarMode === 2, "real calendar opens in Earth mode");
                    calendar.item.setCalendarMode(0);
                    window.check(calendar.item.calendarMode === 0, "ordinary view navigation stays independent");
                    Settings.calendarDefaultMode = 1;
                } else if (window.step === 4) {
                    window.check(calendar.item.calendarMode === 1, "open calendar responds to calibration");
                    Settings.calendarDefaultMode = 2;
                    body.focusPrimary();
                    events.keyClick(Qt.Key_Tab, Qt.NoModifier, -1);
                    window.check(window.activeFocusItem !== null, "native Tab finds a control");
                    const close = find(body, "Close instrument settings");
                    window.check(close !== null, "accessible close control");
                    if (close) events.mouseClick(close, close.width / 2, close.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
                    window.check(window.closes === 1, "native close click");
                    body.forceActiveFocus(); events.keyClick(Qt.Key_Escape, Qt.NoModifier, -1);
                    window.check(window.closes === 2, "native Escape");
                    keyChoice("Temperature: °F");
                } else if (window.step === 5) {
                    const focused = window.activeFocusItem;
                    const point = focused.mapToItem(body, 0, 0);
                    window.check(point.y >= 0 && point.y + focused.height <= body.height, "keyboard focus scrolls into short viewport");
                    window.check(body.width <= window.width && body.height <= window.height, "320px popup bounded");
                    calendar.active = false;
                } else {
                    if (Settings.saveTimer.running || Settings.preferencesLoading) return;
                    stop();
                    body.grabToImage(function(result) {
                        result.saveToFile(Quickshell.env("CONTEXT_SCREENSHOT"));
                        console.log("CONTEXT COMPLETE", window.failures, "failures");
                        Qt.quit();
                    });
                }
                window.step++;
            } finally { window.inTick = false; }
        }
    }
}
