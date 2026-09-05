pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property string preset: "Neutral"
    property var bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property bool pitchEnabled: false
    property real pitchSemitones: 0
    property real pitchCents: 0
    property int pitchMix: 100
    property bool available: false
    property bool busy: false
    readonly property string helperPath: Environment.script("equalizer-state.py")

    function consume(text) {
        try {
            const data = JSON.parse(String(text).trim());
            preset = data.preset || "Neutral";
            bands = data.bands || bands;
            pitchEnabled = data.pitch_enabled === true;
            pitchSemitones = Number(data.pitch_semitones || 0);
            pitchCents = Number(data.pitch_cents || 0);
            pitchMix = Math.max(0, Math.min(100,
                Number(data.pitch_mix === undefined ? 100 : data.pitch_mix)));
            available = data.available === true;
        } catch (decodeError) {
            console.warn("[Tonantzintla/Equalizer] Decode failed:", decodeError);
        }
    }

    function refresh() {
        if (!readProcess.running)
            readProcess.running = true;
    }

    function applyPreset(name) {
        // Tonantzintla's ten control points are original listening profiles.
        // The helper interpolates them over EasyEffects' 32-band graph.
        const recipes = {
            "Neutral": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            "Gravity": [6, 5, 3, 1, 0, -1, -1, 0, 1, 1],
            "Air": [-2, -2, -1, 0, 1, 2, 3, 4, 5, 5],
            "Dialogue": [-4, -3, -1, 2, 4, 5, 3, 1, -1, -2],
            "Pulse": [3, 2, 0, -1, 0, 2, 3, 2, 1, 0],
            "Impact": [4, 3, 2, 0, -1, 0, 2, 3, 4, 3],
            "Lounge": [2, 2, 1, 0, 1, 1, 2, 2, 1, 1],
            "Orchestra": [-1, 0, 1, 2, 2, 1, 1, 2, 3, 2]
        };
        if (!recipes[name] || actionProcess.running)
            return;
        preset = name;
        bands = recipes[name];
        busy = true;
        actionProcess.command = ["python3", helperPath, "preset", name];
        actionProcess.running = true;
    }

    function setBand(index, value) {
        if (actionProcess.running)
            return;
        const next = bands.slice();
        next[index] = Math.max(-12, Math.min(12, Math.round(value)));
        bands = next;
        preset = "Custom";
        busy = true;
        actionProcess.command = ["python3", helperPath, "band", String(index), String(next[index])];
        actionProcess.running = true;
    }

    function setPitch(semitones, cents) {
        if (actionProcess.running)
            return;
        pitchSemitones = Math.max(-12, Math.min(12, Math.round(semitones)));
        pitchCents = Math.max(-100, Math.min(100, Math.round(cents)));
        pitchEnabled = true;
        busy = true;
        actionProcess.command = ["python3", helperPath, "pitch",
            String(pitchSemitones), String(pitchCents)];
        actionProcess.running = true;
    }

    function setPitchEnabled(enabled) {
        if (actionProcess.running)
            return;
        pitchEnabled = enabled;
        busy = true;
        actionProcess.command = ["python3", helperPath, "pitch-enable", enabled ? "true" : "false"];
        actionProcess.running = true;
    }

    function setPitchMix(value) {
        if (actionProcess.running)
            return;
        pitchMix = Math.max(0, Math.min(100, Math.round(value)));
        busy = true;
        actionProcess.command = ["python3", helperPath, "pitch-mix", String(pitchMix)];
        actionProcess.running = true;
    }

    function resetPitch() {
        if (actionProcess.running)
            return;
        pitchEnabled = false;
        pitchSemitones = 0;
        pitchCents = 0;
        pitchMix = 100;
        busy = true;
        actionProcess.command = ["python3", helperPath, "pitch-reset"];
        actionProcess.running = true;
    }

    function restoreAudio() {
        if (actionProcess.running) return;
        busy = true;
        actionProcess.command = ["python3", helperPath, "recover"];
        actionProcess.running = true;
    }

    property Process readProcess: Process {
        command: ["python3", root.helperPath, "get"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.consume(text) }
    }

    property Process actionProcess: Process {
        stdout: StdioCollector { onStreamFinished: root.consume(text) }
        onRunningChanged: if (!running) root.busy = false
    }
}
