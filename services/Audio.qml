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
    readonly property var sinkNode: Pipewire.defaultAudioSink
    readonly property var sourceNode: Pipewire.defaultAudioSource
    readonly property bool mixerActive: ShellState.ephemerisVisible
        && (ShellState.ephemerisTab === "audio" || ShellState.ephemerisTab === "media")
    readonly property bool mixerAvailable: Pipewire.ready

    // The mixer reads PipeWire's node registry directly; volume and mute
    // state stay live through the object tracker below, with no helper
    // process or polling involved.
    readonly property var outputs: Pipewire.nodes.values.filter(function(node) {
        return node.isSink && !node.isStream && node.audio !== null;
    })
    readonly property var inputs: Pipewire.nodes.values.filter(function(node) {
        return !node.isSink && !node.isStream && node.audio !== null;
    })
    readonly property var apps: Pipewire.nodes.values.filter(function(node) {
        return node.isStream && node.audio !== null;
    })

    readonly property string defaultOutputName: sinkNode ? nodeTitle(sinkNode) : "Default output"
    readonly property string defaultOutputDetail: sinkNode && sinkNode.description
        ? sinkNode.description : "PipeWire audio path"
    readonly property int percent: Math.round(volume * 100)
    readonly property int inputPercent: Math.round(inputVolume * 100)

    function nodeTitle(node) {
        if (!node)
            return "Unknown node";
        if (node.isStream && node.properties && node.properties["application.name"])
            return String(node.properties["application.name"]);
        return node.nickname || node.description || node.name || "Unknown node";
    }

    function nodeSubtitle(node) {
        if (!node)
            return "";
        if (node.isStream && node.properties && node.properties["media.name"])
            return String(node.properties["media.name"]);
        return node.description !== nodeTitle(node) && node.description
            ? node.description : node.name || "";
    }

    function nodePercent(node) {
        return node && node.audio ? Math.round(node.audio.volume * 100) : 0;
    }

    function nodeMuted(node) {
        return node && node.audio ? node.audio.muted : false;
    }

    function isDefaultNode(node) {
        return node !== null
            && (node === Pipewire.defaultAudioSink || node === Pipewire.defaultAudioSource);
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
        refreshLevels();
    }

    function toggleMute() {
        Osd.show("volume", percent, muted ? "OUTPUT VOLUME" : "OUTPUT MUTED", !muted);
        if (sinkNode && sinkNode.ready && sinkNode.audio)
            sinkNode.audio.muted = !sinkNode.audio.muted;
        else
            runFallback(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        refreshLevels();
    }

    function toggleMicrophone() {
        Osd.show("microphone", inputPercent,
            inputMuted ? "MICROPHONE LIVE" : "MICROPHONE MUTED", !inputMuted);
        if (sourceNode && sourceNode.ready && sourceNode.audio)
            sourceNode.audio.muted = !sourceNode.audio.muted;
        else
            runFallback(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
        refreshLevels();
    }

    function setVolume(percent) {
        const target = Math.max(0, Math.min(150, percent));
        Osd.show("volume", target, "OUTPUT VOLUME", false);
        if (sinkNode && sinkNode.ready && sinkNode.audio)
            sinkNode.audio.volume = target / 100;
        else
            runFallback(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", target + "%"]);
        refreshLevels();
    }

    function setMicrophoneVolume(percent) {
        const target = Math.max(0, Math.min(150, percent));
        Osd.show("microphone", target, "MICROPHONE GAIN", inputMuted);
        if (sourceNode && sourceNode.ready && sourceNode.audio)
            sourceNode.audio.volume = target / 100;
        else
            runFallback(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", target + "%"]);
        refreshLevels();
    }

    function setNodeVolume(node, percent) {
        if (!node || !node.audio)
            return;
        const target = Math.max(0, Math.min(150, Math.round(percent)));
        node.audio.volume = target / 100;
        Osd.show(!node.isStream && !node.isSink ? "microphone" : "volume", target,
            node.isStream ? "APPLICATION STREAM"
                : node.isSink ? "OUTPUT VOLUME" : "INPUT GAIN", false);
        refreshLevels();
    }

    function toggleNodeMute(node) {
        if (!node || !node.audio)
            return;
        const nowMuted = !node.audio.muted;
        node.audio.muted = nowMuted;
        Osd.show(!node.isStream && !node.isSink ? "microphone" : "volume", 0,
            nowMuted ? "STREAM MUTED" : "STREAM LIVE", nowMuted);
        refreshLevels();
    }

    function setDefaultNode(node) {
        if (!node || node.isStream)
            return;
        if (node.isSink)
            Pipewire.preferredDefaultAudioSink = node;
        else
            Pipewire.preferredDefaultAudioSource = node;
    }

    property PwObjectTracker audioTracker: PwObjectTracker {
        objects: [root.sinkNode, root.sourceNode]
    }

    // Bind the full node set only while a mixer surface is on screen, so the
    // shell is not holding every stream's state when nothing displays it.
    property PwObjectTracker mixerTracker: PwObjectTracker {
        objects: root.mixerActive
            ? root.outputs.concat(root.inputs, root.apps) : []
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

    property Process actionProcess: Process {}

    Component.onCompleted: refreshLevels()
}
