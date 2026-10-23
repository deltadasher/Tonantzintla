import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "services"

Window {
    width: 80; height: 80; visible: true
    property int stage: 0
    property int ticks: 0
    function fail(message) { console.error("UMBRA_VALIDATION_FAILED", message); Qt.quit(); }
    Component.onCompleted: {
        Settings.umbraBackgroundPath = Quickshell.env("UMBRA_TEST_VIDEO");
        Settings.umbraBackgroundMode = "video";
        Umbra.inspectBackground(true);
    }
    Process {
        id: replaceFile
        onExited: function(code) {
            if (code !== 0) { fail("fixture replacement failed"); return; }
            Umbra.inspectBackground(true);
            if (Umbra.videoAvailable) fail("old result remained available after activation");
            stage++;
        }
    }
    Timer {
        interval: 50; repeat: true; running: true
        onTriggered: {
            if (++ticks > 180) { fail("validation timed out"); return; }
            if (Umbra.backgroundCheckedGeneration !== Umbra.backgroundGeneration) return;
            if (stage === 0) {
                if (!Umbra.videoAvailable) { fail("initial valid video rejected"); return; }
                stage = 1;
                replaceFile.command = ["cp", "--", Quickshell.env("UMBRA_TEST_OVERSIZE"), Settings.umbraBackgroundPath];
                replaceFile.running = true;
            } else if (stage === 2) {
                if (Umbra.videoAvailable) { fail("oversized replacement accepted from cached result"); return; }
                stage = 3;
                replaceFile.command = ["cp", "--", Quickshell.env("UMBRA_TEST_VALID"), Settings.umbraBackgroundPath];
                replaceFile.running = true;
            } else if (stage === 4) {
                if (!Umbra.videoAvailable) { fail("repaired file could not be retried"); return; }
                console.log("UMBRA_VALIDATION_OK"); Qt.quit();
            }
        }
    }
}
