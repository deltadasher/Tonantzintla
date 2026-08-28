pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import ".."

QtObject {
    id: root

    property real volume: 0
    property bool muted: false
    property real inputVolume: 0
    property bool inputMuted: false
    property bool mixerAvailable: false
    property var outputs: []
    property var inputs: []
    property var apps: []
    property bool mixerRefreshPending: false
    readonly property var sinkNode: Pipewire.defaultAudioSink
    readonly property var sourceNode: Pipewire.defaultAudioSource
    readonly property bool mixerActive: ShellState.ephemerisVisible
        && (ShellState.ephemerisTab === "audio" || ShellState.ephemerisTab === "media")
    readonly property var defaultOutput: {
        const selected = outputs.find(function(node) { return node.isDefault; });
        return selected || (outputs.length > 0 ? outputs[0] : null);
    }
    readonly property string defaultOutputName: defaultOutput && defaultOutput.name
        ? defaultOutput.name : "Default output"
    readonly property string defaultOutputDetail: defaultOutput && defaultOutput.description
        ? defaultOutput.description : "PipeWire audio path"
    readonly property int percent: Math.round(volume * 100)
    readonly property int inputPercent: Math.round(inputVolume * 100)
    readonly property string helperPath: {
        const value = Qt.resolvedUrl("../scripts/audio-state.py").toString();
        return value.indexOf("file://") === 0
            ? decodeURIComponent(value.substring(7)) : value;
    }

    function refreshLevels() {
        if (sinkNode && sinkNode.ready && sinkNode.audio) {
            volume = sinkNode.audio.volume;
            muted = sinkNode.audio.muted;
        }
        if (sourceNode && sourceNode.ready && sourceNode.audio) {
            inputVolume = sourceNode.audio.volume;
            inputMuted = sourceNode.audio.muted;
        }
    }

    function refresh() {
        refreshLevels();
        if (mixerActive)
            refreshMixer();
    }

    function refreshMixer() {
        if (mixerProcess.running) {
            mixerRefreshPending = true;
            return;
        }
        mixerProcess.running = true;
    }

    function scheduleRefresh() {
        refreshLevels();
        if (mixerActive)
            mixerRefreshTimer.restart();
    }

    function runFallback(command) {
        if (actionProcess.running)
            return;
        actionProcess.command = command;
        actionProcess.running = true;
    }

    function change(delta) {
        Osd.show("volume", Math.max(0, Math.min(150, percent + delta)),
            muted ? "OUTPUT MUTED" : "OUTPUT VOLUME", muted);
        if (sinkNode && sinkNode.ready && sinkNode.audio)
            sinkNode.audio.volume = Math.max(0, Math.min(1.5, volume + delta / 100));
        else
            runFallback(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@",
                Math.abs(delta) + "%" + (delta >= 0 ? "+" : "-")]);
        scheduleRefresh();
    }

    function toggleMute() {
        Osd.show("volume", percent, muted ? "OUTPUT VOLUME" : "OUTPUT MUTED", !muted);
        if (sinkNode && sinkNode.ready && sinkNode.audio)
            sinkNode.audio.muted = !sinkNode.audio.muted;
        else
            runFallback(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        scheduleRefresh();
    }

    function toggleMicrophone() {
        Osd.show("microphone", inputPercent,
            inputMuted ? "MICROPHONE LIVE" : "MICROPHONE MUTED", !inputMuted);
        if (sourceNode && sourceNode.ready && sourceNode.audio)
            sourceNode.audio.muted = !sourceNode.audio.muted;
        else
            runFallback(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
        scheduleRefresh();
    }

    function setVolume(percent) {
        const target = Math.max(0, Math.min(150, percent));
        Osd.show("volume", target, "OUTPUT VOLUME", false);
        if (sinkNode && sinkNode.ready && sinkNode.audio)
            sinkNode.audio.volume = target / 100;
        else
            runFallback(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", target + "%"]);
        scheduleRefresh();
    }

    function setMicrophoneVolume(percent) {
        const target = Math.max(0, Math.min(150, percent));
        Osd.show("microphone", target, "MICROPHONE GAIN", inputMuted);
        if (sourceNode && sourceNode.ready && sourceNode.audio)
            sourceNode.audio.volume = target / 100;
        else
            runFallback(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", target + "%"]);
        scheduleRefresh();
    }

    function pactlOperation(kind, action) {
        if (kind === "outputs")
            return "set-sink-" + action;
        if (kind === "inputs")
            return "set-source-" + action;
        return "set-sink-input-" + action;
    }

    function setNodeVolume(kind, id, percent) {
        if (!id)
            return;
        const target = Math.max(0, Math.min(150, Math.round(percent)));
        Quickshell.execDetached(["pactl", pactlOperation(kind, "volume"), String(id), target + "%"]);
        Osd.show(kind === "inputs" ? "microphone" : "volume", target,
            kind === "apps" ? "APPLICATION STREAM" : kind === "inputs" ? "INPUT GAIN" : "OUTPUT VOLUME", false);
        scheduleRefresh();
    }

    function toggleNodeMute(kind, id, currentlyMuted) {
        if (!id)
            return;
        Quickshell.execDetached(["pactl", pactlOperation(kind, "mute"), String(id), "toggle"]);
        Osd.show(kind === "inputs" ? "microphone" : "volume", 0,
            currentlyMuted ? "STREAM LIVE" : "STREAM MUTED", !currentlyMuted);
        scheduleRefresh();
    }

    function setDefaultNode(kind, nodeName) {
        if (!nodeName || kind === "apps")
            return;
        Quickshell.execDetached(["pactl",
            kind === "inputs" ? "set-default-source" : "set-default-sink", nodeName]);
        scheduleRefresh();
    }

    property PwObjectTracker audioTracker: PwObjectTracker {
        objects: [root.sinkNode, root.sourceNode]
    }

    property Connections pipewireConnections: Connections {
        target: Pipewire
        function onReadyChanged() { root.refreshLevels(); }
        function onDefaultAudioSinkChanged() { root.refreshLevels(); }
        function onDefaultAudioSourceChanged() { root.refreshLevels(); }
    }

    property Connections sinkConnections: Connections {
        target: root.sinkNode && root.sinkNode.audio ? root.sinkNode.audio : null
        function onVolumesChanged() { root.refreshLevels(); }
        function onMutedChanged() { root.refreshLevels(); }
    }

    property Connections sourceConnections: Connections {
        target: root.sourceNode && root.sourceNode.audio ? root.sourceNode.audio : null
        function onVolumesChanged() { root.refreshLevels(); }
        function onMutedChanged() { root.refreshLevels(); }
    }

    property Process mixerProcess: Process {
        command: ["python3", root.helperPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.mixerAvailable = data.available === true;
                    root.outputs = data.outputs || [];
                    root.inputs = data.inputs || [];
                    root.apps = data.apps || [];
                } catch (error) {
                    root.mixerAvailable = false;
                    console.warn("[Astralith/Audio] Mixer decode failed:", error);
                }
            }
        }
        onRunningChanged: {
            if (!running && root.mixerRefreshPending) {
                root.mixerRefreshPending = false;
                root.mixerRefreshTimer.restart();
            }
        }
    }

    property Process actionProcess: Process {}

    property Timer mixerRefreshTimer: Timer {
        interval: 260
        onTriggered: root.refreshMixer()
    }

    property Timer mixerPollTimer: Timer {
        interval: 5000
        running: root.mixerActive
        repeat: true
        onTriggered: root.refreshMixer()
    }

    onMixerActiveChanged: if (mixerActive) refreshMixer()

    Component.onCompleted: refreshLevels()
}
