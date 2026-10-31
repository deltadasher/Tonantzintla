import QtQuick
import Quickshell.Io
import ".."
import "../components/ThemeMode.js" as ThemeMode

// Owned by the open picker, not a global poller. Selection changes clear old
// colors immediately and terminate the helper's owned Matugen child.
QtObject {
    id: root
    property string source: ""
    property bool active: false
    readonly property string helperPath: Environment.script("palette-state.py")
    property var swatches: []
    property var choices: []
    property string seed: ""
    readonly property string mode: Theme.modeForSeed(seed)
    property string jobMode: "dark"
    property string previewSeed: ""
    property string status: "idle"
    property string error: ""
    property int revision: 0
    property int jobRevision: -1
    property string jobSource: ""
    property bool stopping: false
    property bool workerStarted: false

    function invalidate() {
        revision++;
        swatches=[];
        error="";
        delay.stop();
        if (worker.running) { stopping=true; worker.running=false; }
        status=!active ? "idle" : !source ? "unavailable" : "loading";
        if (status==="unavailable") error="No local wallpaper preview is available.";
        if (active && source) delay.restart();
    }
    function receive(text) {
        if (!active || jobRevision!==revision || jobSource!==source || jobMode!==mode) return;
        try {
            const data=JSON.parse(text);
            const rows=data.swatches;
            if (data.ok===true && data.source===source && data.mode===jobMode && (!seed || data.seed===seed.toLowerCase()) && Array.isArray(rows)
                    && rows.length>=3 && rows.length<=5
                    && rows.every(function(row) {return row && typeof row.name==="string" && /^#[0-9a-fA-F]{6}$/.test(row.color);})) {
                choices=Array.isArray(data.choices) ? data.choices.filter(function(color) { return /^#[0-9a-fA-F]{6}$/.test(color); }) : [];
                // The first discovered candidate becomes an explicit selection.
                // In automatic mode resample it before exposing a mismatched preview.
                if (!seed && data.seed && Theme.modeForSeed(data.seed) !== jobMode) {
                    seed=data.seed;
                    return;
                }
                previewSeed=data.seed || "";
                swatches=rows;status="ready";error="";
            } else {
                swatches=[];status="unavailable";error=data.error || "Could not sample this wallpaper's colors.";
            }
        } catch (exception) {
            swatches=[];status="unavailable";error="Could not read the wallpaper color preview.";
        }
    }
    onSourceChanged: { choices=[];seed="";invalidate(); }
    onSeedChanged: invalidate()
    onModeChanged: invalidate()
    onActiveChanged: invalidate()
    Component.onCompleted: invalidate()
    property Timer delay: Timer {
        interval:300
        onTriggered: {
            if (!root.active || !root.source) return;
            if (worker.running || root.stopping) { restart();return; }
            root.jobRevision=root.revision;root.jobSource=root.source;root.jobMode=root.mode;
            root.workerStarted=false;
            worker.command=["python3",root.helperPath,"--preview",root.source,"--seed",root.seed,"--mode",root.jobMode];
            worker.running=true;
        }
    }
    property Process worker: Process {
        onStarted:root.workerStarted=true
        onRunningChanged:if(!running) Qt.callLater(function() {
            if(!worker.running && !root.workerStarted) {
                root.stopping=false;
                if(root.active && root.jobRevision===root.revision && root.status==="loading") {
                    root.swatches=[];root.status="unavailable";
                    root.error="Could not start color sampling. Check that Python 3 is installed.";
                }
            }
        })
        stdout: StdioCollector { onStreamFinished: root.receive(text) }
        onExited: function(exitCode, exitStatus) {
            root.stopping=false;
            if (exitCode!==0 && root.jobRevision===root.revision && root.active && root.status==="loading") {
                root.status="unavailable";root.error="Could not sample this wallpaper's colors.";
            }
        }
    }
}
