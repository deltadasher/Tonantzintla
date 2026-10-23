pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Io
import ".."

QtObject {
    id: root

    property bool active: false
    property bool previewActive: false
    property bool secure: false
    property bool authenticating: false
    property bool unlocking: false
    property bool failed: false
    property bool pamAvailable: true
    property string authMethod: "password"
    property var backgroundInfo: ({available: false, message: "Video not checked"})
    property string backgroundCheckedKey: ""
    property string backgroundRequest: ""
    property int backgroundGeneration: 0
    property int backgroundRequestGeneration: -1
    property int backgroundCheckedGeneration: -1
    readonly property bool videoAvailable: Settings.umbraBackgroundMode === "video"
        && backgroundCheckedKey === Settings.umbraBackgroundPath
        && backgroundCheckedGeneration === backgroundGeneration && backgroundInfo.available === true
    property bool fingerprintAvailable: false
    property string fingerprintStatus: "Fingerprint is not configured; use password"
    property string fingerprintCheckedProfile: ""
    // A fresh activation invalidates the shared result before any output can
    // instantiate a decoder. Concurrent outputs only observe this one check.
    function inspectBackground(fresh) {
        if (fresh === true) {
            backgroundGeneration++;
            backgroundCheckedKey = "";
        }
        if (Settings.umbraBackgroundMode !== "video" || !Settings.umbraBackgroundPath.length) return;
        if (mediaCheck.running) return;
        if (backgroundCheckedKey === Settings.umbraBackgroundPath
                && backgroundCheckedGeneration === backgroundGeneration) return;
        backgroundRequest = Settings.umbraBackgroundPath;
        backgroundRequestGeneration = backgroundGeneration;
        backgroundCheckedKey = "";
        backgroundInfo = {available: false, message: "Checking video and preparing a small silent loop…"};
        mediaCheck.command = ["python3", Environment.script("umbra-capabilities.py"), "video", backgroundRequest];
        mediaCheck.running = true;
    }
    function inspectFingerprint() {
        fingerprintAvailable = false;
        if (!Settings.umbraFingerprintService.length || fingerprintCheck.running) return;
        fingerprintCheckedProfile = Settings.umbraFingerprintService;
        fingerprintStatus = "Checking enrolled reader and PAM profile…";
        fingerprintCheck.command = ["python3", Environment.script("umbra-capabilities.py"), "fingerprint", fingerprintCheckedProfile];
        fingerprintCheck.running = true;
    }
    function cancelAuthentication() {
        authenticating = false;
        if (pam.active) pam.abort();
        if (fingerprintPam.active) fingerprintPam.abort();
        authenticating = false;
        authMethod = "password";
        clearInput();
    }
    function submitFingerprint() {
        if (!active || !secure || previewActive || authenticating || unlocking || !fingerprintAvailable
                || fingerprintCheckedProfile !== Settings.umbraFingerprintService) return;
        password = ""; failed = false; authMethod = "fingerprint";
        authenticating = true; statusText = "TOUCH YOUR FINGERPRINT READER"; eventSerial++;
        if (!fingerprintPam.start()) {
            authenticating = false; failed = true;
            statusText = "READER UNAVAILABLE · USE PASSWORD"; eventSerial++;
        }
    }
    property Process mediaCheck: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.backgroundRequestGeneration !== root.backgroundGeneration
                        || root.backgroundRequest !== Settings.umbraBackgroundPath
                        || Settings.umbraBackgroundMode !== "video") return;
                try { root.backgroundInfo = JSON.parse(text); }
                catch (_) { root.backgroundInfo = {available: false, message: "Video check failed; using still background"}; }
                root.backgroundCheckedKey = root.backgroundRequest;
                root.backgroundCheckedGeneration = root.backgroundRequestGeneration;
            }
        }
        onExited: {
            if (root.backgroundRequestGeneration !== root.backgroundGeneration
                    || root.backgroundRequest !== Settings.umbraBackgroundPath)
                Qt.callLater(function() { root.inspectBackground(); });
        }
    }
    property Process fingerprintCheck: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const state = JSON.parse(text);
                    root.fingerprintAvailable = state.available === true && root.fingerprintCheckedProfile === Settings.umbraFingerprintService;
                    root.fingerprintStatus = root.fingerprintCheckedProfile !== Settings.umbraFingerprintService
                        ? "Profile changed · check reader support again" : state.message || "Use password";
                } catch (_) { root.fingerprintStatus = "Reader check failed; use password"; }
            }
        }
    }
    property Connections preferences: Connections {
        target: Settings
        function onUmbraBackgroundPathChanged() { root.inspectBackground(true); }
        function onUmbraBackgroundModeChanged() { root.inspectBackground(true); }
        function onUmbraFingerprintServiceChanged() { root.fingerprintAvailable = false; }
    }
    property string password: ""
    property string statusText: "READY"
    property string pamMessage: ""
    property int attempts: 0
    property int eventSerial: 0

    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property string controlPath: Environment.controlPath
    readonly property string stateCode: previewActive ? "PREVIEW"
        : !active ? "STANDBY"
        : !secure ? "LOCKING"
        : authenticating ? "AUTHENTICATING"
        : failed ? "ACCESS DENIED" : "SESSION SECURED"

    signal unlocked()
    signal previewUnlocked()

    function resetState() {
        authenticating = false;
        releaseDelay.stop();
        if (pam.active)
            pam.abort();
        if (fingerprintPam.active) fingerprintPam.abort();
        authMethod = "password";
        password = "";
        failed = false;
        authenticating = false;
        unlocking = false;
        pamMessage = "";
        statusText = "ENTER YOUR PASSWORD";
        eventSerial++;
    }

    function lock() {
        if (active)
            return;
        previewActive = false;
        resetState();
        inspectBackground(true);
        active = true;
        inspectFingerprint();
    }

    function launchLock() {
        if (active)
            return;
        previewActive = false;
        Quickshell.execDetached([controlPath, "lock"]);
    }

    function preview() {
        if (active)
            return;
        resetState();
        statusText = "PREVIEW ONLY // ESC TO EXIT";
        inspectBackground(true);
        previewActive = true;
    }

    function closePreview() {
        if (!previewActive)
            return;
        previewActive = false;
        resetState();
        statusText = "READY";
    }

    function clearInput() {
        password = "";
        failed = false;
        pamMessage = "";
        statusText = previewActive ? "PREVIEW ONLY // ESC TO EXIT"
            : "ENTER YOUR PASSWORD";
        eventSerial++;
    }

    function submit() {
        if (unlocking) return;
        if (previewActive) {
            beginUnlock();
            return;
        }
        if (!active || !secure || authenticating || unlocking || password.length === 0)
            return;

        failed = false;
        authMethod = "password";
        authenticating = true;
        pamMessage = "";
        statusText = "CHECKING PASSWORD";
        eventSerial++;
        if (!pam.start()) {
            pamAvailable = false;
            authenticating = false;
            failed = true;
            statusText = "PAM SERVICE UNAVAILABLE";
            eventSerial++;
        }
    }

    function beginUnlock() {
        password = "";
        failed = false;
        authenticating = false;
        statusText = "WELCOME BACK, " + userName.toUpperCase();
        unlocking = true;
        eventSerial++;
        if (!previewActive)
            Quickshell.execDetached([controlPath, "reveal-lock"]);
        releaseDelay.restart();
    }

    function completeUnlock() {
        const wasPreview = previewActive;
        unlocking = false;
        if (wasPreview) {
            previewUnlocked();
            previewActive = false;
            statusText = "READY";
            return;
        }
        active = false;
        secure = false;
        unlocked();
    }

    property Timer releaseDelay: Timer {
        interval: Settings.motion && Settings.umbraMotion ? 1460 : 40
        repeat: false
        onTriggered: root.completeUnlock()
    }

    property PamContext fingerprintPam: PamContext {
        config: Settings.umbraFingerprintService || "login"
        onPamMessage: {
            if (!root.authenticating || root.authMethod !== "fingerprint" || !root.active || !root.secure) return;
            root.pamMessage = message || "";
            if (responseRequired) {
                root.cancelAuthentication();
                root.statusText = "THIS PROFILE REQUIRES PASSWORD · USE PASSWORD";
                root.eventSerial++;
            } else if (message.length) root.statusText = message;
        }
        onCompleted: function(result) {
            if (!root.authenticating || root.authMethod !== "fingerprint" || !root.active || !root.secure) return;
            root.authenticating = false;
            if (result === PamResult.Success) { root.beginUnlock(); return; }
            root.failed = true; root.attempts++;
            root.statusText = "FINGERPRINT NOT ACCEPTED · RETRY OR USE PASSWORD";
            root.eventSerial++;
        }
        onError: function(error) {
            if (!root.authenticating || root.authMethod !== "fingerprint") return;
            root.pamMessage = PamError.toString(error);
            root.authenticating = false; root.failed = true;
            root.statusText = "READER UNAVAILABLE · USE PASSWORD"; root.eventSerial++;
        }
    }

    property PamContext pam: PamContext {
        config: Settings.umbraPamService.length > 0 ? Settings.umbraPamService : "login"

        onPamMessage: {
            if (!root.authenticating || root.authMethod !== "password" || !root.active || !root.secure) return;
            root.pamAvailable = true;
            root.pamMessage = message || "";
            if (responseRequired)
                respond(root.password);
        }

        onCompleted: function(result) {
            if (!root.authenticating || root.authMethod !== "password" || !root.active || !root.secure) return;
            root.authenticating = false;
            if (result === PamResult.Success) {
                root.beginUnlock();
                return;
            }

            root.password = "";
            root.failed = true;
            root.attempts++;
            root.statusText = result === PamResult.Error
                ? "PAM FAILED // CHECK PROFILE"
                : result === PamResult.MaxTries ? "MAXIMUM ATTEMPTS REACHED"
                : "WRONG PASSWORD // TRY AGAIN";
            root.eventSerial++;
        }

        onError: function(error) {
            root.pamAvailable = false;
            root.pamMessage = PamError.toString(error);
        }
    }
}
