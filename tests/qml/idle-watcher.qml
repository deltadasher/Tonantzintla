import QtQuick
import Quickshell

QtObject {
    property var watcher: null
    property int ticks: 0
    Component.onCompleted: {
        const component = Qt.createComponent(Quickshell.env("IDLE_TEST_COMPONENT"));
        if (component.status !== Component.Ready) { console.error(component.errorString()); Qt.quit(); return; }
        watcher = component.createObject(null, {
            enabled: true, seconds: 60,
            controlPath: "/tmp/a path/black'hole",
            executable: Quickshell.env("IDLE_TEST_PROGRAM")
        });
    }
    property Timer check: Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            ticks++;
            if (ticks === 20) {
                console.log(watcher && watcher.status.indexOf("Idle watcher running") === 0 ? "IDLE_STARTED" : "IDLE_FAILED");
                if (watcher) watcher.enabled = false;
            }
            if (ticks === 25) {
                console.log(watcher && !watcher.watcher.running ? "IDLE_STOPPED" : "IDLE_FAILED");
                if (watcher) watcher.destroy();
                Qt.quit();
            }
        }
    }
}
