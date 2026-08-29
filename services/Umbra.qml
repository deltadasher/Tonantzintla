pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pam
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
    property string password: ""
    property string statusText: "UMBRA STANDING BY"
    property string pamMessage: ""
    property int attempts: 0
    property int eventSerial: 0

    readonly property string userName: Quickshell.env("USER") || "traveler"
    readonly property string controlPath: Environment.script("astralithctl")
    readonly property string stateCode: previewActive ? "SIMULATION"
        : !active ? "STANDBY"
        : !secure ? "SEALING"
        : authenticating ? "AUTHENTICATING"
        : failed ? "ACCESS DENIED" : "SESSION SECURED"

    signal unlocked()

    function resetState() {
        releaseDelay.stop();
        if (pam.active)
            pam.abort();
        password = "";
        failed = false;
        authenticating = false;
        unlocking = false;
        pamMessage = "";
        statusText = "IDENTITY CONFIRMATION REQUIRED";
        eventSerial++;
    }

    function lock() {
        if (active)
            return;
        previewActive = false;
        resetState();
        active = true;
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
        statusText = "VISUAL SIMULATION // ESC TO EXIT";
        previewActive = true;
    }

    function closePreview() {
        if (!previewActive)
            return;
        previewActive = false;
        resetState();
        statusText = "UMBRA STANDING BY";
    }

    function clearInput() {
        password = "";
        failed = false;
        pamMessage = "";
        statusText = previewActive ? "VISUAL SIMULATION // ESC TO EXIT"
            : "IDENTITY CONFIRMATION REQUIRED";
        eventSerial++;
    }

    function submit() {
        if (previewActive) {
            beginUnlock();
            return;
        }
        if (!active || authenticating || unlocking || password.length === 0)
            return;

        failed = false;
        authenticating = true;
        pamMessage = "";
        statusText = "VERIFYING FLIGHT SIGNATURE";
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
            previewActive = false;
            statusText = "UMBRA STANDING BY";
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

    property PamContext pam: PamContext {
        config: Settings.umbraPamService.length > 0 ? Settings.umbraPamService : "login"

        onPamMessage: {
            root.pamAvailable = true;
            root.pamMessage = message || "";
            if (responseRequired)
                respond(root.password);
        }

        onCompleted: function(result) {
            root.authenticating = false;
            if (result === PamResult.Success) {
                root.beginUnlock();
                return;
            }

            root.password = "";
            root.failed = true;
            root.attempts++;
            root.statusText = result === PamResult.Error
                ? "PAM HANDSHAKE FAILED // CHECK PROFILE"
                : result === PamResult.MaxTries ? "MAXIMUM ATTEMPTS REACHED"
                : "SIGNATURE REJECTED // TRY AGAIN";
            root.eventSerial++;
        }

        onError: function(error) {
            root.pamAvailable = false;
            root.pamMessage = PamError.toString(error);
        }
    }
}
