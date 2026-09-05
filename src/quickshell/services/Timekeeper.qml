pragma Singleton

import QtQuick

QtObject {
    id: root

    property int timerPresetSeconds: 5 * 60
    property real timerRemainingMs: timerPresetSeconds * 1000
    property double timerTargetEpoch: 0
    readonly property bool timerRunning: timerTargetEpoch > 0
    readonly property real timerProgress: timerPresetSeconds > 0
        ? Math.max(0, Math.min(1, 1 - timerRemainingMs / (timerPresetSeconds * 1000))) : 0
    readonly property string timerDisplay: formatTime(timerRemainingMs, false)

    property double stopwatchStartEpoch: 0
    property real stopwatchAccumulatedMs: 0
    property real stopwatchDisplayMs: 0
    property var laps: []
    readonly property bool stopwatchRunning: stopwatchStartEpoch > 0
    readonly property string stopwatchDisplay: formatTime(stopwatchDisplayMs, true)

    readonly property bool anyRunning: timerRunning || stopwatchRunning || Focus.running
    readonly property string activeCode: timerRunning ? "TMR"
        : stopwatchRunning ? "SW" : Focus.running ? "FCS" : ""
    readonly property string activeDisplay: timerRunning ? timerDisplay
        : stopwatchRunning ? stopwatchDisplay : Focus.running ? Focus.displayTime : ""

    function two(value) {
        return Math.floor(value).toString().padStart(2, "0");
    }

    function formatTime(milliseconds, hundredths) {
        const safe = Math.max(0, Number(milliseconds || 0));
        const totalSeconds = Math.floor(safe / 1000);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        let output = (hours > 0 ? two(hours) + ":" : "")
            + two(minutes) + ":" + two(seconds);
        if (hundredths)
            output += "." + two(Math.floor((safe % 1000) / 10));
        return output;
    }

    function selectTimer(minutes) {
        timerTargetEpoch = 0;
        timerPresetSeconds = Math.max(1, Math.round(minutes * 60));
        timerRemainingMs = timerPresetSeconds * 1000;
    }

    function adjustTimer(seconds) {
        if (timerRunning)
            return;
        timerPresetSeconds = Math.max(1, Math.min(99 * 3600 + 59 * 60 + 59,
            timerPresetSeconds + seconds));
        timerRemainingMs = timerPresetSeconds * 1000;
    }

    function toggleTimer() {
        if (timerRunning) {
            timerRemainingMs = Math.max(0, timerTargetEpoch - Date.now());
            timerTargetEpoch = 0;
        } else {
            if (timerRemainingMs <= 0)
                timerRemainingMs = timerPresetSeconds * 1000;
            timerTargetEpoch = Date.now() + timerRemainingMs;
        }
    }

    function resetTimer() {
        timerTargetEpoch = 0;
        timerRemainingMs = timerPresetSeconds * 1000;
    }

    function toggleStopwatch() {
        const now = Date.now();
        if (stopwatchRunning) {
            stopwatchAccumulatedMs += now - stopwatchStartEpoch;
            stopwatchStartEpoch = 0;
            stopwatchDisplayMs = stopwatchAccumulatedMs;
        } else {
            stopwatchStartEpoch = now;
        }
    }

    function resetStopwatch() {
        stopwatchStartEpoch = 0;
        stopwatchAccumulatedMs = 0;
        stopwatchDisplayMs = 0;
        laps = [];
    }

    function addLap() {
        if (stopwatchDisplayMs <= 0)
            return;
        const previous = laps.length > 0 ? Number(laps[laps.length - 1].total) : 0;
        const next = laps.slice();
        next.push({ "number": next.length + 1, "total": stopwatchDisplayMs,
            "split": stopwatchDisplayMs - previous });
        laps = next;
    }

    property Timer ticker: Timer {
        interval: 31
        repeat: true
        running: root.timerRunning || root.stopwatchRunning
        onTriggered: {
            const now = Date.now();
            if (root.timerRunning) {
                const remaining = root.timerTargetEpoch - now;
                if (remaining <= 0) {
                    root.timerRemainingMs = 0;
                    root.timerTargetEpoch = 0;
                    Notifications.preview("Timer complete",
                        "The " + root.formatTime(root.timerPresetSeconds * 1000, false)
                            + " countdown has reached zero.");
                } else {
                    root.timerRemainingMs = remaining;
                }
            }
            if (root.stopwatchRunning)
                root.stopwatchDisplayMs = root.stopwatchAccumulatedMs
                    + (now - root.stopwatchStartEpoch);
        }
    }
}
