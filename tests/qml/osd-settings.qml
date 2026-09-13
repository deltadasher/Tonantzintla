import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/services"

QtObject {
    function check(ok, message) { if (!ok) console.error("OSD_FAILED", message); }
    Component.onCompleted: Qt.callLater(function() {
        check(Osd.duration === 1450, "existing duration retained");
        Settings.osdVolume = false;
        Osd.show("volume", 30, "Speakers", false);
        check(!Osd.visible, "disabled volume stays hidden");
        Osd.show("microphone", 0, "Microphone", false);
        check(Osd.visible && !Osd.muted && Osd.value === 0, "zero is distinct from mute");
        const serial = Osd.serial;
        Osd.show("microphone", 40, "Microphone", true);
        check(Osd.serial === serial + 1 && Osd.muted, "replacement updates same service");
        Settings.osdMicrophone = false;
        check(!Osd.visible, "disabling active kind dismisses");
        Settings.osdBrightness = false;
        Osd.show("brightness", 50, "Brightness", false);
        check(!Osd.visible, "brightness setting connected");
        Settings.osdVolume = true;
        Settings.osdDuration = 1000;
        Osd.show("volume", 50, "Speakers", false);
        check(Osd.visible && Osd.duration === 1000, "new duration applied");
        expiry.start();
    })
    property Timer expiry: Timer {
        interval: 1200
        onTriggered: {
            check(!Osd.visible, "popup expires");
            Settings.osdDuration = -1;
            check(Osd.duration === 500, "invalid duration bounded");
            console.log("OSD_OK"); Qt.quit();
        }
    }
}
