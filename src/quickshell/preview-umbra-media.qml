import QtQuick
import Quickshell
import "."
import "services"
import "modules/umbra"

Window {
    width: 640; height: 360; visible: true
    property int cycles: 0
    property int ticks: 0
    property bool closing: false
    property bool observedPlaying: false
    UmbraBackground { id: background; anchors.fill: parent; active: true }
    Connections {
        target: background
        function onVideoPlayingChanged() {
            if (background.videoPlaying) observedPlaying = true;
            else if (observedPlaying && background.active) {
                console.error("UMBRA_VIDEO_FAILED readiness dropped at a loop boundary"); Qt.quit();
            }
        }
    }
    Component.onCompleted: {
        Settings.umbraBackgroundPath = Quickshell.env("UMBRA_TEST_VIDEO");
        Settings.umbraBackgroundMode = "video";
        Umbra.inspectBackground();
    }
    Timer {
        interval: 300; repeat: true; running: true
        onTriggered: {
            ticks++;
            if (closing) {
                if (background.videoLoaded) { console.error("UMBRA_VIDEO_FAILED retained decoder"); Qt.quit(); return; }
                cycles++;
                if (cycles >= 5) { console.log("UMBRA_VIDEO_OK", cycles); Qt.quit(); return; }
                observedPlaying = false;
                Umbra.inspectBackground(true);
                closing = false; background.active = true;
            } else if (background.videoPlaying) {
                // Keep the first one-second fixture through multiple wraps.
                if (cycles === 0 && ticks < 8) return;
                background.active = false; closing = true;
            }
            if (ticks > 45) { console.error("UMBRA_VIDEO_FAILED", background.statusText); Qt.quit(); }
        }
    }
}
