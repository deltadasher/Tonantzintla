//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Wayland
import "."
import "services"
import "modules/umbra"

ShellRoot {
    id: root

    Component.onCompleted: stateDelay.start()

    Timer {
        id: stateDelay
        interval: 0
        onTriggered: {
            Umbra.lock();
            if (!sessionLock.locked) {
                Umbra.active = false;
                Umbra.failed = true;
                Umbra.statusText = "SCREEN LOCK UNAVAILABLE";
                Umbra.eventSerial++;
                Qt.quit();
            }
        }
    }

    Connections {
        target: Umbra
        function onUnlocked() {
            sessionLock.locked = false;
            Qt.quit();
        }
    }

    WlSessionLock {
        id: sessionLock

        // Authentication is the only successful path that releases this lock.
        locked: true

        onSecureStateChanged: Umbra.secure = secure
        onLockStateChanged: {
            if (!locked && Umbra.active) {
                Umbra.active = false;
                Umbra.secure = false;
                Umbra.failed = true;
                Umbra.statusText = "SCREEN LOCK UNAVAILABLE";
                Umbra.eventSerial++;
                Qt.quit();
            }
        }

        WlSessionLockSurface {
            id: lockSurface
            color: Theme.void_

            UmbraSurface {
                anchors.fill: parent
                screenInfo: lockSurface.screen
            }
        }
    }
}
