pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: root

    // Single source of truth for the version the shell reports. Keep this in
    // step with the newest heading in CHANGELOG.md.
    readonly property string version: "1.0.0"

    property bool hasGrim: false
    property bool hasSlurp: false
    property bool hasWlCopy: false
    property bool hasSatty: false
    property bool hasRecorder: false
    property string recordingState: "idle"
    property string recordingMessage: "Ready to choose a portal target"
    property string recordingOutput: ""
    property int recordingCountdown: 0
    readonly property bool recording: recordingState === "recording"
    readonly property bool recordingBusy: ["pending", "recording", "finalizing"].indexOf(recordingState) >= 0

    function applyRecordingState(payload) {
        recordingState = payload.state || "error";
        recordingMessage = payload.message || "Capture status unavailable";
        recordingOutput = payload.output || "";
        recordingCountdown = Number(payload.countdown || 0);
    }
    property bool recordRefreshPending: false
    property bool hasSwaybg: false
    property bool hasSwww: false
    property bool hasAwww: false
    property bool hasMpvpaper: false
    property bool wallpaperBusy: false
    property bool wallpaperRestored: false
    property bool onlineBusy: false
    property bool libraryLoading: false
    // Opening Parallax acquires the index once; failures use its explicit Retry.
    property bool libraryRequested: false
    property string libraryError: ""
    property bool libraryRefreshPending: false
    property string wallpaperMessage: ""
    property bool wallpaperMessageError: false
    readonly property bool libraryOperationBusy: libraryOperation.running
    property var localWallpapers: []
    // Native stills are opt-in. Prepared paths are transient; only source intent
    // is persisted. An external handoff retains these entries until success.
    property var nativeWallpapers: ({})
    property var nativeDesired: ({})
    property var nativePresented: ({})
    property var nativeOutputNames: []
    property int nativeGeneration: 0
    property int nativeModeEpoch: 0
    property bool nativeModeWasEnabled: false
    property var nativeJob: null
    property string nativeResponse: ""
    property var nativeHandoffs: []
    property var nativeHandoff: null
    property var nativeExternalRequest: null
    property var externalAssignment: null
    readonly property bool nativeWallpaperActive: Object.keys(nativeWallpapers).length > 0
    readonly property bool nativeWallpaperAllPresented: {
        const names = Object.keys(nativeDesired).filter(function(name) { return root.nativeDesired[name].kind === "image"; });
        return Settings.wallpaperRenderer === "native" && names.length > 0 && names.every(function(name) {
            const entry = root.nativeWallpapers[name];
            return entry && !entry.error && entry.generation === root.nativeDesired[name].generation && root.nativePresented[name] === entry.generation;
        });
    }
    function validNativeOutput(name) {
        return typeof name === "string" && /^[a-zA-Z0-9_.:-]{1,128}$/.test(name) && ["__proto__","prototype","constructor"].indexOf(name)<0;
    }
    function nativeWallpaperFor(output) { return Object.prototype.hasOwnProperty.call(nativeWallpapers,output) ? nativeWallpapers[output] : null; }
    function reportNativeWallpaperPresented(output, generation) {
        const entry = nativeWallpapers[output];
        if (!entry || entry.generation !== generation) return;
        if(entry.error) { const ready=Object.assign({},nativeWallpapers);ready[output]=Object.assign({},entry,{error:""});nativeWallpapers=ready; }
        const next = Object.assign({}, nativePresented); next[output] = generation; nativePresented = next;
        if (nativeWallpaperAllPresented) wallpaperFeedback("Native still displayed.",false);
    }
    function reportNativeWallpaperFailed(output,generation,message) {
        const entry=nativeWallpaperFor(output);
        if(!entry || entry.generation!==generation) return;
        const ready=Object.assign({},nativeWallpapers);
        ready[output]=Object.assign({},entry,{error:String(message || "Image decoding failed").slice(0,240)});
        nativeWallpapers=ready;
        wallpaperFeedback("Native still could not be displayed · previous background retained. Apply again to retry.",true);
    }
    function sanitizeNativeAssignments(value) {
        const result = {};
        if (!value || typeof value !== "object" || Array.isArray(value)) return result;
        for (const name of Object.keys(value).slice(0, 8)) {
            const entry = value[name];
            if (!validNativeOutput(name) || !entry || typeof entry.source !== "string"
                    || entry.source.length > 4096 || entry.source.indexOf("\0") >= 0
                    || (entry.kind !== "image" && entry.kind !== "video")) continue;
            let path = "";
            try { path = pathFromUrl(entry.source); } catch (error) { continue; }
            if (path.indexOf("/") !== 0) continue;
            result[name] = {source:path, kind:entry.kind};
        }
        return result;
    }
    function persistNativeAssignment(names, source, kind) {
        const next = sanitizeNativeAssignments(Settings.nativeWallpaperAssignments);
        for (const name of names) next[name] = {source:source, kind:kind};
        // Prefer connected outputs when old unplugged assignments exceed the cap.
        const keys = Object.keys(next).sort(function(a,b) { return (root.nativeOutputNames.indexOf(b)>=0 ? 1:0) - (root.nativeOutputNames.indexOf(a)>=0 ? 1:0); });
        const bounded = {}; for (const key of keys.slice(0,8)) bounded[key] = next[key];
        Settings.nativeWallpaperAssignments = sanitizeNativeAssignments(bounded);
    }
    function nativeTransitionName(value) {
        if (value === "any") return "orbit";
        if (value === "swipe" || value === "diagonal") return "wipe";
        return ["fade","grow","wipe","orbit","none"].indexOf(value) >= 0 ? value : "fade";
    }
    function currentNativeOutputs() {
        return Quickshell.screens.map(function(screen) { return screen.name; }).filter(function(name) { return root.validNativeOutput(name); }).slice(0,8);
    }
    function syncNativeOutputs(names) {
        nativeOutputNames = names.filter(function(name,index,list) { return root.validNativeOutput(name) && list.indexOf(name) === index; }).slice(0,8);
        const ready = {}, desired = {}, presented = {};
        const saved = sanitizeNativeAssignments(Settings.nativeWallpaperAssignments);
        for (const name of nativeOutputNames) {
            if (nativeWallpapers[name]) ready[name] = nativeWallpapers[name];
            if (nativePresented[name] !== undefined) presented[name] = nativePresented[name];
            if (nativeDesired[name]) desired[name] = nativeDesired[name];
            else if (Settings.wallpaperRenderer === "native") {
                const assignment = saved[name] && saved[name].kind === "image" ? saved[name] : {source:Settings.wallpaperPath || bundledWallpapers[0],kind:"image"};
                desired[name] = {source:pathFromUrl(assignment.source),kind:assignment.kind,generation:++nativeGeneration,failed:false};

            }
        }
        nativeWallpapers = ready; nativeDesired = desired; nativePresented = presented;
        pumpOpticalPreviews();
    }
    function requestNativeWallpaper(path, kind, outputs) {
        const clean=sanitizeNativeAssignments({output:{source:path,kind:kind}}).output;
        if (!clean) { wallpaperFeedback("Choose a local image or video path for the native wallpaper.",true); return; }
        path=clean.source;
        const names = nativeOutputNames.filter(function(name) { return outputs === "all" || outputs.split(",").indexOf(name) >= 0; });
        if (!names.length) { wallpaperFeedback("No selected display is available for the native wallpaper.", true); return; }
        const next = Object.assign({}, nativeDesired); const generation = ++nativeGeneration;
        for (const name of names) next[name] = {source:pathFromUrl(path),kind:kind,generation:generation,failed:false};
        nativeDesired = next;
        if (kind === "video") { beginExternalWallpaper(path,kind); } else {
            wallpaperFeedback("Preparing native still · previous background retained…", false);
            pumpOpticalPreviews();
        }
    }
    function pumpNativeWallpapers() {
        if (Settings.wallpaperRenderer !== "native" || nativeWallpaperProcess.running || opticalPreviewProcess.running || libraryProcess.running || libraryRefreshPending) return false;
        const pending = Object.keys(nativeDesired).find(function(name) { const wanted=root.nativeDesired[name], ready=root.nativeWallpapers[name]; return wanted.kind === "image" && !wanted.failed && (!ready || ready.generation !== wanted.generation); });
        if (!pending) return false;
        const source = nativeDesired[pending].source, generations = {};
        for (const name of Object.keys(nativeDesired)) if (nativeDesired[name].source === source && nativeDesired[name].kind === "image" && !nativeDesired[name].failed) generations[name] = nativeDesired[name].generation;
        nativeJob = {source:source,generations:generations}; nativeResponse = "";
        nativeWallpaperProcess.command = ["python3",libraryHelper,"--native-wallpaper-preview",source];
        nativeWallpaperProcess.running = true; return true;
    }
    function finishNativeWallpaper(exitCode) {
        const job=nativeJob; nativeJob=null;
        let result=null;
        try { result=JSON.parse(nativeResponse); } catch(error) {}
        const valid=exitCode===0 && result && result.ok===true && result.source===job.source
            && typeof result.preview === "string" && result.preview.indexOf("/")===0 && result.preview!==job.source
            && Number.isInteger(result.width) && result.width>0 && result.width<=2560
            && Number.isInteger(result.height) && result.height>0 && result.height<=2560;
        const proxyValid=valid && typeof result.transitionPreview === "string" && result.transitionPreview.indexOf("/")===0
            && result.transitionPreview!==job.source && result.transitionPreview!==result.preview
            && Number.isInteger(result.transitionWidth) && result.transitionWidth>0 && result.transitionWidth<=512
            && Number.isInteger(result.transitionHeight) && result.transitionHeight>0 && result.transitionHeight<=512;
        const ready=Object.assign({},nativeWallpapers), desired=Object.assign({},nativeDesired), names=[];
        if (Settings.wallpaperRenderer === "native") for (const name of Object.keys(job.generations)) {
            if (!desired[name] || desired[name].generation !== job.generations[name]) continue;
            if (valid) {
                ready[name]={source:job.source,preview:result.preview,width:result.width,height:result.height,
                    transitionPreview:proxyValid ? result.transitionPreview : "",transitionWidth:proxyValid ? result.transitionWidth : 0,transitionHeight:proxyValid ? result.transitionHeight : 0,
                    generation:desired[name].generation,revealSerial:desired[name].generation,transition:nativeTransitionName(Settings.wallpaperTransition)};
                names.push(name);
            } else desired[name]=Object.assign({},desired[name],{failed:true});
        }
        nativeWallpapers=ready;nativeDesired=desired;
        if (names.length) { persistNativeAssignment(names,job.source,"image");wallpaperFeedback("Native still prepared · waiting for display frame",false); }
        else if (!valid && Object.keys(job.generations).some(function(name){return desired[name] && desired[name].generation===job.generations[name];})) wallpaperFeedback("Native still unavailable · previous background retained. Apply again to retry.",true);
        if (libraryRefreshPending) Qt.callLater(root.continueWallpaperRefresh); else Qt.callLater(root.pumpOpticalPreviews);
    }
    function pumpNativeHandoffs() {
        if (applyProcess.running || nativeHandoff || !nativeHandoffs.length) return;
        const job=nativeHandoffs[0];nativeHandoffs=nativeHandoffs.slice(1);
        if ((job.kind === "video" && !hasMpvpaper) || (job.kind !== "video" && !hasAwww && !hasSwww)) {
            nativeHandoffs=[];wallpaperFeedback("External handoff unavailable · native background retained. Install " + (job.kind==="video" ? "mpvpaper" : "awww or swww") + ".",true);return;
        }
        nativeHandoff=job;wallpaperBusy=true;
        applyProcess.command=["bash",applyHelper,job.kind,job.source,job.outputs,Settings.wallpaperTransition,hasAwww ? "awww":"swww"];
        applyProcess.running=true;
    }
    function finishWallpaperApply(exitCode) {
        const job=nativeHandoff;nativeHandoff=null;
        if (!job) {
            if(externalAssignment && externalAssignment.epoch !== nativeModeEpoch) { externalAssignment=null;Qt.callLater(root.pumpNativeHandoffs);return; }
            if(exitCode===0 && externalAssignment) persistNativeAssignment(externalAssignment.names,externalAssignment.source,externalAssignment.kind);
            externalAssignment=null;
            wallpaperFeedback(exitCode===0 ? "Wallpaper applied." : "Wallpaper could not be applied. Check the selected display and backend.",exitCode!==0);
            Qt.callLater(root.pumpNativeHandoffs);return;
        }
        if(job.epoch!==nativeModeEpoch) { Qt.callLater(root.pumpNativeHandoffs);return; }
        if (exitCode===0) {
            const ready=Object.assign({},nativeWallpapers);
            const retired=[];
            for (const name of job.retire) {
                if (job.generation !== undefined && (!nativeDesired[name] || nativeDesired[name].generation !== job.generation)) continue;
                delete ready[name];retired.push(name);
            }
            nativeWallpapers=ready;
            if(retired.length) persistNativeAssignment(retired,job.source,job.kind);
            if(job.followup) nativeExternalRequest=null;
            wallpaperFeedback(job.kind === "video" ? "Video wallpaper uses the external renderer." : "External wallpaper restored.",false);
        } else if (exitCode!==0) { nativeHandoffs=[];wallpaperFeedback("External handoff failed · native background retained. Apply again to retry.",true); }
        Qt.callLater(root.pumpNativeHandoffs);
    }
    function beginExternalWallpaper(path,kind) {
        if (kind === "video" && !hasMpvpaper) { wallpaperFeedback("Install mpvpaper to apply a video wallpaper. Native still retained.",true);return; }
        const names=nativeOutputNames.filter(function(name){return Settings.wallpaperOutputs === "all" || Settings.wallpaperOutputs.split(",").indexOf(name)>=0;});
        nativeExternalRequest={source:pathFromUrl(path),kind:kind,outputs:Settings.wallpaperOutputs,retire:names,followup:true};
        Settings.wallpaperPath=path;Settings.wallpaperKind=kind;
        if(Settings.wallpaperRenderer === "native") Settings.wallpaperRenderer="external";
        else { nativeModeWasEnabled=true;syncNativeRenderer(); }
    }
    function retryWallpaper() {
        if (Settings.wallpaperRenderer !== "native" && nativeWallpaperActive) {
            nativeModeWasEnabled=true;
            syncNativeRenderer();
        } else applyWallpaper(Settings.wallpaperPath || bundledWallpapers[0],Settings.wallpaperKind);
    }
    function syncNativeRenderer() {
        const enabled=Settings.wallpaperRenderer === "native";
        if(enabled && Settings.wallpaperKind === "video") {
            Settings.wallpaperRenderer="external";
            wallpaperFeedback("Native supports stills only. Apply a still with the external renderer before enabling Native.",true);
            return;
        }
        if (enabled===nativeModeWasEnabled) return;
        nativeModeWasEnabled=enabled;nativeModeEpoch++;nativeHandoffs=[];
        if (enabled) { nativeDesired={};syncNativeOutputs(currentNativeOutputs()); }
        else {
            const grouped={};
            for (const name of Object.keys(nativeWallpapers)) {
                const source=nativeWallpapers[name].source;
                if (!grouped[source]) grouped[source]=[];grouped[source].push(name);
            }
            nativeDesired={};
            nativeHandoffs=Object.keys(grouped).slice(0,8).map(function(source){return {source:source,kind:"image",outputs:grouped[source].join(","),retire:grouped[source],epoch:root.nativeModeEpoch};});
            if(nativeExternalRequest) nativeHandoffs=nativeHandoffs.concat([Object.assign({},nativeExternalRequest,{epoch:nativeModeEpoch})]);
            if (nativeHandoffs.length) pumpNativeHandoffs();
        }
    }
    property Process nativeWallpaperProcess: Process {
        stdout: StdioCollector { onStreamFinished: root.nativeResponse=text }
        onExited: function(exitCode) { root.finishNativeWallpaper(exitCode); }
    }
    property Connections nativeScreenConnection: Connections {
        target: Quickshell
        function onScreensChanged() { root.syncNativeOutputs(root.currentNativeOutputs()); }
    }
    // One shared, on-demand still preparation queue. No library scan is needed.
    property var opticalRequests: []
    property var opticalPreviews: []
    property string opticalPreparingSource: ""
    property string opticalResponse: ""
    property int opticalGeneration: 0
    property int opticalPreparingGeneration: 0
    readonly property bool opticalPreparing: opticalPreviewProcess.running
    function opticalPreviewFor(source) {
        const path = pathFromUrl(source);
        return opticalPreviews.find(function(entry) { return entry.source === path; }) || null;
    }
    // Explicit refresh/reapply can replace pixels without changing a path. A
    // matching in-flight result must not restore the invalidated cache entry.
    function invalidateOpticalPreviews(source) {
        const path = source ? pathFromUrl(source) : "";
        if (opticalPreparingSource && (!path || opticalPreparingSource === path))
            opticalGeneration++;
        opticalPreviews = opticalPreviews.filter(function(entry) { return path && entry.source !== path; });
    }
    function requestOpticalPreview(owner, source) {
        const path = pathFromUrl(source);
        opticalRequests = opticalRequests.filter(function(entry) { return entry.owner !== owner; });
        const sources = opticalRequests.map(function(entry) { return entry.source; }).filter(function(value, index, list) { return list.indexOf(value) === index; });
        if (sources.length >= 4 && sources.indexOf(path) < 0) return false;
        if (path.length) opticalRequests = opticalRequests.concat([{owner:owner, source:path}]);
        pumpOpticalPreviews();
        return true;
    }
    function releaseOpticalPreview(owner) {
        opticalRequests = opticalRequests.filter(function(entry) { return entry.owner !== owner; });
    }
    function pumpOpticalPreviews() {
        if (nativeWallpaperProcess.running || opticalPreviewProcess.running || libraryProcess.running || libraryRefreshPending) return;
        if (pumpNativeWallpapers()) return;
        const pending = opticalRequests.find(function(entry) { return !root.opticalPreviewFor(entry.source); });
        if (!pending) return;
        opticalPreparingSource = pending.source;
        opticalPreparingGeneration = opticalGeneration;
        opticalResponse = "";
        opticalPreviewProcess.command = ["python3", libraryHelper, "--optical-preview", pending.source];
        opticalPreviewProcess.running = true;
    }
    function finishOpticalPreview(exitCode) {
        const source = opticalPreparingSource;
        let entry = {source:source, preview:"", message:"Optical still unavailable · etched fallback"};
        try {
            const result = JSON.parse(opticalResponse);
            if (exitCode === 0 && result.ok === true && result.source === source
                    && typeof result.preview === "string" && result.preview.indexOf("/") === 0
                    && result.preview !== source && Number.isInteger(result.width) && result.width > 0 && result.width <= 768
                    && Number.isInteger(result.height) && result.height > 0 && result.height <= 768) {
                entry.preview = result.preview; entry.width=result.width;entry.height=result.height;entry.message = "";
            }
        } catch (error) {}
        // A changed wallpaper never receives the previous job's result. Keep
        // only four bounded path records, including failures to avoid retry loops.
        if (opticalPreparingGeneration === opticalGeneration
                && opticalRequests.some(function(request) { return request.source === source; })) {
            const retained = opticalPreviews.filter(function(old) { return old.source !== source; });
            const active = function(old) { return root.opticalRequests.some(function(request) { return request.source === old.source; }); };
            opticalPreviews = retained.filter(function(old) { return !active(old); }).concat(retained.filter(active), [entry]).slice(-4);
        }
        opticalPreparingSource = "";
        if (libraryRefreshPending) Qt.callLater(root.continueWallpaperRefresh);
        else Qt.callLater(root.pumpOpticalPreviews);
    }
    property Process opticalPreviewProcess: Process {
        stdout: StdioCollector { onStreamFinished: root.opticalResponse = text }
        onExited: function(exitCode) { root.finishOpticalPreview(exitCode); }
    }
    property var onlineWallpapers: []
    readonly property var wallpapers: (localWallpapers.length > 0
        ? localWallpapers : bundledEntries()).concat(onlineWallpapers)
    readonly property bool captureActive: ShellState.ephemerisVisible
        && ShellState.ephemerisTab === "capture"
    readonly property var outputNames: {
        const names = [];
        for (const screen of Quickshell.screens) {
            if (screen && screen.name && names.indexOf(screen.name) < 0)
                names.push(screen.name);
        }
        for (const workspace of Compositor.workspaces) {
            if (workspace.output && names.indexOf(workspace.output) < 0)
                names.push(workspace.output);
        }
        return names;
    }

    function pathFromUrl(url) {
        const value = url.toString();
        return value.indexOf("file://") === 0 ? decodeURIComponent(value.substring(7)) : value;
    }

    // Internal executables the shell spawns. They are not user commands, so
    // they live outside the single blackhole entry point.
    readonly property string helperRoot: Quickshell.shellDir + "/../libexec"
    readonly property string controlPath: Quickshell.shellDir + "/../../bin/blackhole"

    function script(name) {
        return helperRoot + "/" + name;
    }

    readonly property string bundledRoot: Quickshell.shellDir + "/../assets/wallpapers"
    readonly property var bundledWallpapers: [
        bundledRoot + "/astral-observatory.png",
        bundledRoot + "/aurora-tide.png",
        bundledRoot + "/ringfall-survey.png",
        bundledRoot + "/umbra-array.png",
        bundledRoot + "/violet-eclipse.png",
        bundledRoot + "/orbital-cartography.png"
    ]
    readonly property string snippingTool: script("snipping-tool")
    readonly property string libraryHelper: script("wallpaper-library.py")
    readonly property string onlineHelper: script("wallpaper-online.py")
    readonly property string applyHelper: script("wallpaper-apply")
    readonly property string wallpaperLibraryPath: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property bool canCaptureRegion: hasGrim && hasSlurp && hasWlCopy
    readonly property bool canCaptureScreen: hasGrim
    readonly property bool canEditCapture: hasGrim && hasSlurp && hasWlCopy && hasSatty
    readonly property bool canRecord: hasRecorder
    readonly property string screenshotStatus: canCaptureRegion
        ? "READY" : "INSTALL GRIM + SLURP + WL-COPY"
    readonly property bool canSetWallpaper: Settings.wallpaperRenderer === "native" || hasAwww || hasSwaybg || hasSwww || hasMpvpaper
    readonly property string wallpaperStatus: Settings.wallpaperRenderer === "native" ? (nativeWallpaperAllPresented ? "NATIVE STILL ONLINE" : nativeWallpaperProcess.running ? "PREPARING NATIVE STILL" : "NATIVE STILLS · VIDEO EXTERNAL") : wallpaperBusy ? "APPLYING WALLPAPER"
        : hasAwww && hasMpvpaper ? "AWWW + MPVPAPER ONLINE"
        : hasAwww ? "AWWW TRANSITIONS ONLINE" : hasSwaybg
            ? "SWAYBG ONLINE" : hasSwww ? "SWWW ONLINE" : "NO BACKEND"

    function kindFor(path) {
        return /\.(mp4|mkv|mov|webm|avi|m4v)$/i.test(path || "") ? "video" : "image";
    }

    function bundledEntries() {
        return bundledWallpapers.map(function(path) {
            const name = path.split("/").pop();
            return {
                "path": path,
                "preview": "",
                "name": name,
                "kind": kindFor(path),
                "source": "Tonantzintla",
                "color": "",
                "bucket": "Unsorted",
                "remoteUrl": ""
            };
        });
    }

    function outputsSelected(name) {
        if (Settings.wallpaperOutputs === "all")
            return true;
        return Settings.wallpaperOutputs.split(",").indexOf(name) >= 0;
    }

    function selectAllOutputs() {
        Settings.wallpaperOutputs = "all";
    }

    function toggleOutput(name) {
        if (!name)
            return;
        let selected = Settings.wallpaperOutputs === "all"
            ? outputNames.slice() : Settings.wallpaperOutputs.split(",").filter(Boolean);
        const index = selected.indexOf(name);
        if (index >= 0) {
            if (selected.length > 1)
                selected.splice(index, 1);
        } else {
            selected.push(name);
        }
        Settings.wallpaperOutputs = selected.length === outputNames.length ? "all" : selected.join(",");
    }

    function captureRegion(action) {
        if (canCaptureRegion)
            Quickshell.execDetached([snippingTool, "--region-" + (action || "copy")]);
    }

    function launchTerminal() {
        Quickshell.execDetached([controlPath, "terminal"]);
    }

    function captureScreen(action) {
        if (!canCaptureScreen)
            return;
        Quickshell.execDetached([snippingTool, "--full-" + (action || "save")]);
    }

    function startRecording() {
        if (!canRecord || recordingBusy || recordAction.running)
            return;
        recordingState = "pending";
        recordingMessage = "Preparing capture…";
        recordAction.command = [snippingTool, "--record-start",
            "--fps", String(Settings.captureFps),
            "--desktop-audio", Settings.captureDesktopAudio ? "yes" : "no",
            "--microphone", Settings.captureMicrophone ? "yes" : "no",
            "--pointer", Settings.capturePointer ? "yes" : "no",
            "--countdown", String(Settings.captureCountdown)];
        recordAction.running = true;
    }

    function stopRecording() {
        if (!recordingBusy || recordingState === "finalizing" || recordAction.running)
            return;
        recordAction.command = [snippingTool, "--record-stop"];
        recordAction.running = true;
    }

    function refreshRecordingState() {
        if (recordAction.running) {
            recordRefresh.restart();
            return;
        }
        if (recordStatusProcess.running) {
            recordRefreshPending = true;
            return;
        }
        recordStatusProcess.running = true;
    }

    function openCaptureFolder() {
        Quickshell.execDetached([snippingTool, "--open-captures"]);
    }

    function openRecordingFolder() {
        Quickshell.execDetached([snippingTool, "--open-recordings"]);
    }

    function openWallpaperLibrary() {
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p -- \"$1\" && exec \"$2\" files \"$1\"",
            "blackhole", wallpaperLibraryPath, controlPath]);
    }

    function wallpaperFeedback(message, failed) {
        wallpaperMessage = message;
        wallpaperMessageError = !!failed;
    }

    function importWallpapers(urls) {
        if (libraryOperation.running) return;
        const files = [];
        for (const url of urls) files.push(String(url));
        if (!files.length) return;
        wallpaperFeedback("Importing " + files.length + " file(s)…", false);
        libraryOperation.command = ["python3", libraryHelper, "--import-json", JSON.stringify(files)];
        libraryOperation.running = true;
    }

    function toggleWallpaperFavorite(entry) {
        if (!entry || libraryOperation.running) return;
        if (entry.remoteUrl) {
            wallpaperFeedback("Apply the online wallpaper to download it before saving a favorite.", false);
            return;
        }
        libraryOperation.command = ["python3", libraryHelper, "--favorite", entry.path,
            "--enabled", entry.favorite ? "false" : "true"];
        libraryOperation.running = true;
    }

    function applyWallpaper(path, kind) {
        if (Settings.wallpaperRenderer === "native" && path) {
            if (!nativeOutputNames.length) syncNativeOutputs(currentNativeOutputs());
            const nativeKind=kind || kindFor(path);
            if(nativeKind === "video") { beginExternalWallpaper(path,nativeKind);return; }
            requestNativeWallpaper(path,nativeKind,Settings.wallpaperOutputs);
            if (nativeKind !== "video") invalidateOpticalPreviews(path);
            Settings.wallpaperPath=path;Settings.wallpaperKind=nativeKind;
            return;
        }
        if (nativeWallpaperActive) { beginExternalWallpaper(path,kind || kindFor(path));return; }
        if(applyProcess.running) { wallpaperFeedback("Wallpaper application is in progress. Wait for it to finish before applying another.",false);return; }
        nativeExternalRequest=null;
        if (!path || !canSetWallpaper) {
            wallpaperFeedback("No wallpaper backend is available. Install awww or swaybg.", true);
            return;
        }
        const resolvedKind = kind || kindFor(path);
        if (resolvedKind === "video" && !hasMpvpaper) {
            wallpaperFeedback("Install mpvpaper to apply a video wallpaper.", true);
            console.warn("[Tonantzintla/Wallpaper] mpvpaper is required for video wallpaper");
            return;
        }
        const targets=(nativeOutputNames.length ? nativeOutputNames : currentNativeOutputs()).filter(function(name){return Settings.wallpaperOutputs === "all" || Settings.wallpaperOutputs.split(",").indexOf(name)>=0;});
        externalAssignment={names:targets,source:pathFromUrl(path),kind:resolvedKind,epoch:nativeModeEpoch};
        wallpaperBusy = true;
        wallpaperFeedback("Applying to " + (Settings.wallpaperOutputs === "all" ? "all displays" : Settings.wallpaperOutputs) + "…", false);
        if (resolvedKind === "video" || hasAwww) {
            applyProcess.command = ["bash", applyHelper, resolvedKind, path,
                Settings.wallpaperOutputs, Settings.wallpaperTransition];
            applyProcess.running = true;
        } else if (hasSwww) {
            applyProcess.command = ["bash", applyHelper, resolvedKind, path,
                Settings.wallpaperOutputs, Settings.wallpaperTransition, "swww"];
            applyProcess.running = true;
        } else if (hasSwaybg) {
            wallpaperBackend.command = ["swaybg", "-m", "fill", "-i", path];
            wallpaperBackend.running = true;
            wallpaperBusy = false;
        }
        if (resolvedKind !== "video") invalidateOpticalPreviews(path);
        Settings.wallpaperPath = path;
        Settings.wallpaperKind = resolvedKind;
        pumpOpticalPreviews();
    }

    function setWallpaper(entry) {
        if (!entry)
            return;
        if (typeof entry === "string") {
            applyWallpaper(entry, kindFor(entry));
            return;
        }
        if (entry.remoteUrl && entry.remoteUrl.length) {
            downloadOnline(entry);
            return;
        }
        applyWallpaper(entry.path, entry.kind);
    }

    function restoreWallpaper() {
        if (Settings.wallpaperRenderer === "native") {
            if (wallpaperRestored && nativeModeWasEnabled) return;
            wallpaperRestored=true;syncNativeRenderer();
            if (Settings.wallpaperRenderer !== "native") { wallpaperRestored=false;restoreWallpaper();return; }
            if (!nativeOutputNames.length) syncNativeOutputs(currentNativeOutputs());
            return;
        }
        if (!canSetWallpaper || wallpaperRestored)
            return;
        const selected = Settings.wallpaperPath.length > 0
            ? Settings.wallpaperPath : bundledWallpapers[0];
        wallpaperRestored = true;
        applyWallpaper(selected, Settings.wallpaperKind || kindFor(selected));
    }

    function ensureWallpapers() {
        if (libraryRequested) return;
        refreshWallpapers(false);
    }

    function continueWallpaperRefresh() { refreshWallpapers(false); }

    function refreshWallpapers(invalidateOptics) {
        if (invalidateOptics !== false) invalidateOpticalPreviews("");
        libraryRequested = true;
        if (opticalPreviewProcess.running || nativeWallpaperProcess.running) {
            libraryRefreshPending = true;
            libraryLoading = true;
            return;
        }
        if (libraryProcess.running) {
            libraryRefreshPending = true;
            return;
        }
        if (!libraryProcess.running) {
            libraryRefreshPending = false;
            libraryLoading = true;
            libraryError = "";
            libraryProcess.running = true;
        }
    }

    function searchOnline(query) {
        const cleaned = String(query || "").trim();
        if (!cleaned.length || onlineSearchProcess.running)
            return;
        onlineBusy = true;
        onlineWallpapers = [];
        onlineSearchProcess.command = ["python3", onlineHelper, "search", cleaned];
        onlineSearchProcess.running = true;
    }

    function downloadOnline(entry) {
        if (!entry || !entry.remoteUrl || onlineDownloadProcess.running)
            return;
        wallpaperBusy = true;
        onlineDownloadProcess.command = ["python3", onlineHelper, "download", entry.remoteUrl];
        onlineDownloadProcess.running = true;
    }

    property Process wallpaperBackend: Process {}

    property Process applyProcess: Process {
        onExited: function(exitCode) { root.finishWallpaperApply(exitCode); }
        onRunningChanged: {
            if (!running) {
                root.wallpaperBusy = false;
                AdaptivePalette.refresh();
            }
        }
    }

    property Process libraryOperation: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text);
                    if (payload.action === "import") {
                        const count = (payload.imported || []).length;
                        const errors = payload.errors || [];
                        root.wallpaperFeedback(count + " file(s) ready in the library."
                            + (errors.length ? " " + errors.length + " failed: " + errors[0].error : ""), errors.length > 0);
                        if (count) root.refreshWallpapers();
                    } else if (payload.ok && payload.action === "favorite") {
                        root.localWallpapers = root.localWallpapers.map(function(entry) {
                            if (entry.path !== payload.path) return entry;
                            return Object.assign({}, entry, {favorite: payload.favorite});
                        });
                        root.wallpaperFeedback(payload.favorite ? "Saved to favorites." : "Removed from favorites.", false);
                    } else {
                        root.wallpaperFeedback(payload.error || "Library action failed.", true);
                    }
                } catch (error) {
                    root.wallpaperFeedback("Library action failed: " + String(error), true);
                }
            }
        }
    }

    property Process libraryProcess: Process {
        command: ["python3", root.libraryHelper, "--bundled-root", root.bundledRoot]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text);
                    if (!Array.isArray(payload))
                        throw new Error(payload.error || "Wallpaper index was not an array");
                    root.localWallpapers = payload;
                    root.libraryError = "";
                } catch (error) {
                    root.libraryError = String(error);
                    console.warn("[Tonantzintla/Wallpaper] Wallpaper index decode failed:", error);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0) {
                    root.libraryError = message.split("\n").pop();
                    console.warn("[Tonantzintla/Wallpaper] Wallpaper index failed:", message);
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                root.libraryLoading = false;
                if (root.libraryRefreshPending) {
                    Qt.callLater(root.continueWallpaperRefresh);
                } else Qt.callLater(root.pumpOpticalPreviews);
            }
        }
    }

    property Process onlineSearchProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text);
                    if (Array.isArray(payload))
                        root.onlineWallpapers = payload;
                    else
                        console.warn("[Tonantzintla/Wallpaper]", payload.error || "Online search failed");
                } catch (error) {
                    console.warn("[Tonantzintla/Wallpaper] Online search returned invalid data:", error);
                }
            }
        }
        onRunningChanged: if (!running) root.onlineBusy = false
    }

    property Process onlineDownloadProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text);
                    if (payload.ok === true && payload.path) {
                        root.applyWallpaper(payload.path, payload.kind || "image");
                        root.refreshWallpapers();
                    } else {
                        root.wallpaperBusy = false;
                        console.warn("[Tonantzintla/Wallpaper]", payload.error || "Wallpaper download failed");
                    }
                } catch (error) {
                    root.wallpaperBusy = false;
                    console.warn("[Tonantzintla/Wallpaper] Wallpaper download returned invalid data:", error);
                }
            }
        }
    }

    property Connections settingsConnection: Connections {
        target: Settings
        ignoreUnknownSignals: true
        function onWallpaperRendererChanged() { if (Settings.persistenceReady) root.syncNativeRenderer(); }
        function onPersistenceReadyChanged() {
            if (Settings.persistenceReady)
                root.restoreWallpaper();
        }
    }

    property Timer initialRestore: Timer {
        interval: 750
        running: true
        onTriggered: root.restoreWallpaper()
    }

    property Process recordAction: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.applyRecordingState(JSON.parse(text)); }
                catch (error) { root.recordingState = "error"; root.recordingMessage = "Capture request failed"; }
            }
        }
        onRunningChanged: if (!running) root.recordRefresh.restart()
    }

    property Timer recordPoll: Timer {
        interval: root.recordingBusy ? 500 : 2500
        running: root.recordingBusy || root.captureActive
        repeat: true
        onTriggered: root.refreshRecordingState()
    }

    property Timer recordRefresh: Timer {
        interval: 450
        onTriggered: root.refreshRecordingState()
    }

    property Process recordStatusProcess: Process {
        command: [root.snippingTool, "--record-status-json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.applyRecordingState(JSON.parse(text)); }
                catch (error) { root.recordingState = "error"; root.recordingMessage = "Capture status could not be read"; }
            }
        }
        onRunningChanged: {
            if (!running && root.recordRefreshPending) {
                root.recordRefreshPending = false;
                root.recordRefresh.restart();
            }
        }
    }

    onCaptureActiveChanged: if (captureActive) recordRefresh.restart()

    property Process probeProcess: Process {
        command: ["sh", "-c",
            "for c in grim slurp wl-copy satty gpu-screen-recorder swaybg swww awww awww-daemon mpvpaper; do command -v \"$c\" >/dev/null 2>&1 && printf '%s=1\\n' \"$c\" || printf '%s=0\\n' \"$c\"; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasGrim = text.indexOf("grim=1") >= 0;
                root.hasSlurp = text.indexOf("slurp=1") >= 0;
                root.hasWlCopy = text.indexOf("wl-copy=1") >= 0;
                root.hasSatty = text.indexOf("satty=1") >= 0;
                root.hasRecorder = text.indexOf("gpu-screen-recorder=1") >= 0;
                root.hasSwaybg = text.indexOf("swaybg=1") >= 0;
                root.hasSwww = text.indexOf("swww=1") >= 0;
                root.hasAwww = text.indexOf("awww=1") >= 0 && text.indexOf("awww-daemon=1") >= 0;
                root.hasMpvpaper = text.indexOf("mpvpaper=1") >= 0;
                root.restoreWallpaper();
            }
        }
    }
}
