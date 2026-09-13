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
    readonly property var sinkNode: containsNode(outputs, Pipewire.defaultAudioSink)
        ? Pipewire.defaultAudioSink : firstUsableNode(outputs)
    readonly property var sourceNode: containsNode(inputs, Pipewire.defaultAudioSource)
        ? Pipewire.defaultAudioSource : firstUsableNode(inputs)
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
    readonly property var graphSources: inputs.concat(apps.filter(function(node) { return !node.isSink; }))
    readonly property var graphTargets: outputs.concat(apps.filter(function(node) { return node.isSink; }))
    readonly property var routes: Pipewire.linkGroups.values.filter(function(link) {
        return link.source && link.target && link.source.audio && link.target.audio;
    })
    property string routeStatus: ""
    property bool routeError: false
    readonly property bool routing: routeProcess.running

    function canRoute(node) {
        return node && node.ready && node.isStream && !node.isSink
            && node.properties && /^\d+$/.test(String(node.properties["object.serial"] || ""));
    }

    function moveStream(node, destination) {
        if (routing || !canRoute(node) || !containsNode(outputs, destination) || !destination.ready)
            return;
        const serial = String(destination.properties["object.serial"] || "");
        if (!/^\d+$/.test(serial)) {
            routeError = true;
            routeStatus = "This output cannot be rerouted through PulseAudio compatibility";
            return;
        }
        routeError = false;
        routeStatus = "Moving playback…";
        routeProcess.command = ["python3", Environment.script("audio-route.py"),
            String(node.properties["object.serial"]), serial];
        routeProcess.running = true;
    }

    readonly property string defaultOutputName: sinkNode ? nodeTitle(sinkNode) : "Default output"
    readonly property string defaultOutputDetail: sinkNode && sinkNode.description
        ? sinkNode.description : "PipeWire audio path"
    readonly property int percent: Math.round(Math.max(0, Math.min(1.5, volume)) * 100)
    readonly property int inputPercent: Math.round(Math.max(0, Math.min(1.5, inputVolume)) * 100)

    function firstUsableNode(nodes) {
        if (!nodes || nodes.length === 0)
            return null;
        const preferred = nodes.find(function(node) {
            const title = nodeTitle(node).toLowerCase();
            return title.indexOf("speaker") >= 0 || title.indexOf("headphone") >= 0;
        });
        return preferred || nodes[0];
    }

    function containsNode(nodes, node) {
        return node !== null && node !== undefined
            && nodes && nodes.indexOf(node) >= 0;
    }

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
        return node && node.ready && node.audio
            ? Math.round(Math.max(0, Math.min(1.5, node.audio.volume)) * 100) : 0;
    }

    function nodeMuted(node) {
        return node && node.ready && node.audio ? node.audio.muted : false;
    }

    function isDefaultNode(node) {
        return node !== null
            && (node === root.sinkNode || node === root.sourceNode);
    }

    function refreshLevels() {
        if (sinkNode && sinkNode.ready && sinkNode.audio) {
            volume = Math.max(0, Math.min(1.5, sinkNode.audio.volume));
            muted = sinkNode.audio.muted;
        } else if (!sinkNode) {
            volume = 0;
            muted = false;
        }
        if (sourceNode && sourceNode.ready && sourceNode.audio) {
            inputVolume = Math.max(0, Math.min(1.5, sourceNode.audio.volume));
            inputMuted = sourceNode.audio.muted;
        } else if (!sourceNode) {
            inputVolume = 0;
            inputMuted = false;
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
            muted ? "MUTED" : "VOLUME", muted);
        if (sinkNode && sinkNode.ready && sinkNode.audio)
            sinkNode.audio.volume = Math.max(0, Math.min(1.5, volume + delta / 100));
        else
            runFallback(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@",
                Math.abs(delta) + "%" + (delta >= 0 ? "+" : "-")]);
        refreshLevels();
    }

    function toggleMute() {
        Osd.show("volume", percent, muted ? "VOLUME" : "MUTED", !muted);
        if (sinkNode && sinkNode.ready && sinkNode.audio)
            sinkNode.audio.muted = !sinkNode.audio.muted;
        else
            runFallback(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        refreshLevels();
    }

    function toggleMicrophone() {
        Osd.show("microphone", inputPercent,
            inputMuted ? "MIC ON" : "MIC MUTED", !inputMuted);
        if (sourceNode && sourceNode.ready && sourceNode.audio)
            sourceNode.audio.muted = !sourceNode.audio.muted;
        else
            runFallback(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
        refreshLevels();
    }

    function setVolume(percent) {
        const target = Math.max(0, Math.min(150, percent));
        Osd.show("volume", target, "VOLUME", false);
        if (sinkNode && sinkNode.ready && sinkNode.audio)
            sinkNode.audio.volume = target / 100;
        else
            runFallback(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", target + "%"]);
        refreshLevels();
    }

    function setMicrophoneVolume(percent) {
        const target = Math.max(0, Math.min(150, percent));
        Osd.show("microphone", target, "MIC LEVEL", inputMuted);
        if (sourceNode && sourceNode.ready && sourceNode.audio)
            sourceNode.audio.volume = target / 100;
        else
            runFallback(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", target + "%"]);
        refreshLevels();
    }

    function setNodeVolume(node, percent) {
        if (!node || !node.ready || !node.audio)
            return;
        const target = Math.max(0, Math.min(150, Math.round(percent)));
        node.audio.volume = target / 100;
        Osd.show(!node.isStream && !node.isSink ? "microphone" : "volume", target,
            node.isStream ? "APP VOLUME"
                : node.isSink ? "VOLUME" : "MIC LEVEL", false);
        refreshLevels();
    }

    function toggleNodeMute(node) {
        if (!node || !node.ready || !node.audio)
            return;
        const nowMuted = !node.audio.muted;
        node.audio.muted = nowMuted;
        Osd.show(!node.isStream && !node.isSink ? "microphone" : "volume", 0,
            nowMuted ? "MUTED" : "UNMUTED", nowMuted);
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

    property Connections sinkNodeConnections: Connections {
        target: root.sinkNode
        function onReadyChanged() { root.refreshLevels(); }
    }

    property Connections sourceConnections: Connections {
        target: root.sourceNode && root.sourceNode.audio ? root.sourceNode.audio : null
        function onVolumesChanged() { root.refreshLevels(); }
        function onMutedChanged() { root.refreshLevels(); }
    }

    property Connections sourceNodeConnections: Connections {
        target: root.sourceNode
        function onReadyChanged() { root.refreshLevels(); }
    }

    property Process actionProcess: Process {
        onRunningChanged: if (!running) root.refreshLevels()
    }

    property Process routeProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    root.routeError = result.ok !== true;
                    root.routeStatus = result.status || "Route unavailable";
                } catch (error) {
                    root.routeError = true;
                    root.routeStatus = "Could not confirm the audio route";
                }
            }
        }
    }

    Component.onCompleted: refreshLevels()
}
