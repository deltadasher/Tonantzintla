pragma Singleton

import QtQuick
import Quickshell.Io
import ".."

QtObject {
    id: root

    property int workMinutes: 25
    property int shortBreakMinutes: 5
    property int longBreakMinutes: 15
    property int longBreakEvery: 4
    property bool autoAdvance: true
    property string phase: "focus"
    property int remainingSeconds: workMinutes * 60
    property double targetEpoch: 0
    property int completedSessions: 0
    property int completedCycles: 0
    property var dailyStats: ({})
    property int pendingFocusSeconds: 0
    property string currentDayKey: dateKey(new Date())
    property bool applying: false
    property bool persistenceReady: false

    readonly property bool running: targetEpoch > 0
    readonly property int durationSeconds: phase === "long-break"
        ? longBreakMinutes * 60 : phase === "short-break"
            ? shortBreakMinutes * 60 : workMinutes * 60
    readonly property real progress: durationSeconds > 0
        ? Math.max(0, Math.min(1, 1 - remainingSeconds / durationSeconds)) : 0
    readonly property string phaseLabel: phase === "long-break" ? "LONG BREAK"
        : phase === "short-break" ? "SHORT BREAK" : "FOCUS"
    readonly property string displayTime: formatTime(remainingSeconds)
    readonly property string todayKey: currentDayKey
    readonly property int todayFocusSeconds: statSeconds(todayKey) + pendingFocusSeconds
    readonly property int todaySessions: statSessions(todayKey)
    readonly property int weekFocusSeconds: sumRecentDays(7)
    readonly property int currentStreak: calculateCurrentStreak()
    readonly property int bestStreak: calculateBestStreak()
    readonly property var recentDays: buildRecentDays()
    readonly property string statePath: Settings.configRoot + "/focus.json"

    function two(value) {
        return Math.floor(value).toString().padStart(2, "0");
    }

    function formatTime(seconds) {
        const safe = Math.max(0, Math.round(seconds));
        const hours = Math.floor(safe / 3600);
        const minutes = Math.floor((safe % 3600) / 60);
        const secs = safe % 60;
        return (hours > 0 ? two(hours) + ":" : "") + two(minutes) + ":" + two(secs);
    }

    function formatDuration(seconds) {
        const safe = Math.max(0, Math.round(seconds));
        const hours = Math.floor(safe / 3600);
        const minutes = Math.floor((safe % 3600) / 60);
        return hours > 0 ? hours + "H " + minutes + "M" : minutes + "M";
    }

    function dateKey(date) {
        const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
        return local.toISOString().slice(0, 10);
    }

    function offsetDate(days) {
        const date = new Date();
        date.setHours(12, 0, 0, 0);
        date.setDate(date.getDate() + days);
        return date;
    }

    function statSeconds(key) {
        const stats = dailyStats || {};
        return stats[key] ? Number(stats[key].seconds || 0) : 0;
    }

    function statSessions(key) {
        const stats = dailyStats || {};
        return stats[key] ? Number(stats[key].sessions || 0) : 0;
    }

    function sumRecentDays(count) {
        const stats = dailyStats || {};
        let total = 0;
        for (let offset = 0; offset > -count; offset--) {
            const key = dateKey(offsetDate(offset));
            total += stats[key] ? Number(stats[key].seconds || 0) : 0;
        }
        return total + pendingFocusSeconds;
    }

    function buildRecentDays() {
        const stats = dailyStats || {};
        const output = [];
        let maximum = 1;
        for (let offset = -6; offset <= 0; offset++) {
            const date = offsetDate(offset);
            const key = dateKey(date);
            const seconds = (stats[key] ? Number(stats[key].seconds || 0) : 0)
                + (offset === 0 ? pendingFocusSeconds : 0);
            maximum = Math.max(maximum, seconds);
            output.push({ "key": key,
                "label": Qt.formatDate(date, "ddd").toUpperCase().slice(0, 2),
                "seconds": seconds,
                "sessions": stats[key] ? Number(stats[key].sessions || 0) : 0 });
        }
        return output.map(function(day) {
            return { "key": day.key, "label": day.label, "seconds": day.seconds,
                "sessions": day.sessions, "ratio": day.seconds / maximum };
        });
    }

    function calculateCurrentStreak() {
        const stats = dailyStats || {};
        let streak = 0;
        let offset = statSessions(todayKey) === 0 ? -1 : 0;
        while (offset > -370) {
            const entry = stats[dateKey(offsetDate(offset))];
            if (!entry || Number(entry.sessions || 0) <= 0)
                break;
            streak++;
            offset--;
        }
        return streak;
    }

    function calculateBestStreak() {
        const stats = dailyStats || {};
        const keys = Object.keys(stats).filter(function(key) {
            return Number(stats[key].sessions || 0) > 0;
        }).sort();
        let best = 0;
        let active = 0;
        let previous = null;
        keys.forEach(function(key) {
            const current = new Date(key + "T12:00:00");
            const contiguous = previous
                && Math.round((current - previous) / 86400000) === 1;
            active = contiguous ? active + 1 : 1;
            best = Math.max(best, active);
            previous = current;
        });
        return best;
    }

    function queueSave() {
        if (persistenceReady && !applying)
            saveTimer.restart();
    }

    function flushStats() {
        if (pendingFocusSeconds <= 0)
            return;
        const next = Object.assign({}, dailyStats || {});
        const entry = Object.assign({ "seconds": 0, "sessions": 0 }, next[todayKey] || {});
        entry.seconds = Number(entry.seconds || 0) + pendingFocusSeconds;
        next[todayKey] = entry;
        pendingFocusSeconds = 0;
        dailyStats = next;
        queueSave();
    }

    function recordCompletedSession() {
        flushStats();
        const next = Object.assign({}, dailyStats || {});
        const entry = Object.assign({ "seconds": 0, "sessions": 0 }, next[todayKey] || {});
        entry.sessions = Number(entry.sessions || 0) + 1;
        next[todayKey] = entry;
        dailyStats = next;
        completedSessions++;
        completedCycles++;
    }

    function phaseDuration(nextPhase) {
        return nextPhase === "long-break" ? longBreakMinutes * 60
            : nextPhase === "short-break" ? shortBreakMinutes * 60 : workMinutes * 60;
    }

    function enterPhase(nextPhase, shouldRun) {
        phase = nextPhase;
        remainingSeconds = phaseDuration(nextPhase);
        targetEpoch = shouldRun ? Date.now() + remainingSeconds * 1000 : 0;
        queueSave();
    }

    function finishPhase() {
        if (phase === "focus") {
            recordCompletedSession();
            const nextBreak = completedCycles % Math.max(1, longBreakEvery) === 0
                ? "long-break" : "short-break";
            Notifications.preview("Focus session complete",
                "Session " + completedSessions + " done. "
                    + (nextBreak === "long-break" ? "Long break available." : "Short break available."));
            enterPhase(nextBreak, autoAdvance);
        } else {
            Notifications.preview("Break complete", "Ready for the next focus session.");
            enterPhase("focus", autoAdvance);
        }
        queueSave();
    }

    function selectPreset(minutes) {
        workMinutes = Math.max(1, Math.round(minutes));
        enterPhase("focus", false);
    }

    function selectPhase(nextPhase) {
        flushStats();
        enterPhase(nextPhase, false);
    }

    function toggle() {
        if (running) {
            remainingSeconds = Math.max(0, Math.ceil((targetEpoch - Date.now()) / 1000));
            targetEpoch = 0;
            flushStats();
        } else {
            if (remainingSeconds <= 0)
                remainingSeconds = durationSeconds;
            targetEpoch = Date.now() + remainingSeconds * 1000;
        }
        queueSave();
    }

    function reset() {
        flushStats();
        targetEpoch = 0;
        remainingSeconds = durationSeconds;
        queueSave();
    }

    function skipPhase() {
        flushStats();
        if (phase === "focus") {
            const nextBreak = (completedCycles + 1) % Math.max(1, longBreakEvery) === 0
                ? "long-break" : "short-break";
            enterPhase(nextBreak, autoAdvance);
        } else {
            enterPhase("focus", autoAdvance);
        }
    }

    function applyFromDisk() {
        applying = true;
        workMinutes = stateAdapter.workMinutes;
        shortBreakMinutes = stateAdapter.shortBreakMinutes;
        longBreakMinutes = stateAdapter.longBreakMinutes;
        longBreakEvery = stateAdapter.longBreakEvery;
        autoAdvance = stateAdapter.autoAdvance;
        phase = stateAdapter.phase || "focus";
        remainingSeconds = stateAdapter.remainingSeconds || phaseDuration(phase);
        targetEpoch = stateAdapter.targetEpoch;
        completedSessions = stateAdapter.completedSessions;
        completedCycles = stateAdapter.completedCycles;
        dailyStats = stateAdapter.dailyStats || {};
        applying = false;
        persistenceReady = true;

        if (targetEpoch > 0) {
            const remaining = Math.ceil((targetEpoch - Date.now()) / 1000);
            if (remaining <= 0)
                finishPhase();
            else
                remainingSeconds = remaining;
        }
    }

    function saveNow() {
        stateAdapter.workMinutes = workMinutes;
        stateAdapter.shortBreakMinutes = shortBreakMinutes;
        stateAdapter.longBreakMinutes = longBreakMinutes;
        stateAdapter.longBreakEvery = longBreakEvery;
        stateAdapter.autoAdvance = autoAdvance;
        stateAdapter.phase = phase;
        stateAdapter.remainingSeconds = remainingSeconds;
        stateAdapter.targetEpoch = targetEpoch;
        stateAdapter.completedSessions = completedSessions;
        stateAdapter.completedCycles = completedCycles;
        stateAdapter.dailyStats = dailyStats;
        stateFile.writeAdapter();
    }

    property Timer ticker: Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            const remaining = Math.ceil((root.targetEpoch - Date.now()) / 1000);
            if (root.phase === "focus")
                root.pendingFocusSeconds++;
            if (remaining <= 0) {
                root.remainingSeconds = 0;
                root.targetEpoch = 0;
                root.finishPhase();
            } else {
                root.remainingSeconds = remaining;
            }
        }
    }

    property Timer statsFlushTimer: Timer {
        interval: 10000
        repeat: true
        running: root.running && root.phase === "focus"
        onTriggered: root.flushStats()
    }

    property Timer dayBoundaryTimer: Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            const nextKey = root.dateKey(new Date());
            if (nextKey !== root.currentDayKey) {
                root.flushStats();
                root.currentDayKey = nextKey;
            }
        }
    }

    property Timer saveTimer: Timer {
        interval: 240
        onTriggered: root.saveNow()
    }

    property Process ensureDirectory: Process {
        command: ["mkdir", "-p", Settings.configRoot]
        running: true
        onRunningChanged: {
            if (!running)
                stateFile.reload();
        }
    }

    property FileView stateFile: FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        onLoaded: root.applyFromDisk()
        onFileChanged: reload()
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound && !root.ensureDirectory.running) {
                root.persistenceReady = true;
                root.saveNow();
            }
        }
        adapter: JsonAdapter {
            id: stateAdapter
            property int workMinutes: 25
            property int shortBreakMinutes: 5
            property int longBreakMinutes: 15
            property int longBreakEvery: 4
            property bool autoAdvance: true
            property string phase: "focus"
            property int remainingSeconds: 25 * 60
            property double targetEpoch: 0
            property int completedSessions: 0
            property int completedCycles: 0
            property var dailyStats: ({})
        }
    }
}
