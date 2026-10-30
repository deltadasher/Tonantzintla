import QtQuick
import QtTest
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/modules/ephemeris/widgets/shared"

Window {
    id: window
    width: 680; height: 360; visible: true; color: Theme.void_
    property int step: 0
    property int failures: 0
    property bool busy: false
    function check(ok, label) { if (!ok) { failures++; console.error("AUDIO LIQUID FAIL", label); } }
    function capture(name) {
        busy = true;
        scene.grabToImage(function(result) {
            result.saveToFile(Quickshell.env("AUDIO_LIQUID_OUTPUT") + "/" + name + ".png");
            busy = false;
        });
    }
    TestEvent { id: events }
    Item {
        id: scene; anchors.fill: parent
        Rectangle { anchors.fill: parent; color: Theme.void_ }
        Text { x: 36; y: 30; text: "Audio"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 25 }
        Text { x: 36; y: 83; text: "Output volume"; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 14 }
        AudioSlider { id: slider; x: 28; y: 114; width: 624; value: 74; Accessible.name: "Output volume"; onValueRequested: function(nextValue) { slider.value = nextValue; } }
        Text { x: 36; y: 191; text: "Compact media volume"; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 14 }
        AudioSlider { id: compact; x: 28; y: 224; width: 624; value: 62; compact: true }
        Text { x: 36; y: 303; text: "Fixed rail, ticks and keyboard focus"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 12 }
    }
    Timer {
        interval: 120; running: true; repeat: true
        onTriggered: {
            if (window.busy || !Settings.persistenceReady) return;
            if (window.step === 0) { Settings.motion = true; Settings.adaptivePalette = false; window.requestActivate(); }
            else if (window.step === 1) { window.capture("rest"); }
            else if (window.step === 2) {
                events.mousePress(slider, 340, 21, Qt.LeftButton, Qt.NoModifier, -1);
                window.check(!!slider.liquidAnimating, "direct pointer adjustment starts finite liquid response");
                window.check(slider.interacting, "drag retains existing interaction state");
                window.capture("adjusting");
            } else if (window.step === 3) {
                events.mouseMove(slider, 438, 21, -1, Qt.LeftButton, Qt.NoModifier);
                events.mouseRelease(slider, 438, 21, Qt.LeftButton, Qt.NoModifier, -1);
                window.check(!slider.interacting, "release commits and ends drag");
                window.check(slider.width === 624 && slider.height === 42, "response never changes hit rectangle");
            } else if (window.step === 8) {
                window.check(!slider.liquidAnimating && slider.liquidResponse === 0, "response fully stops after settling");
                const priorValue = slider.value;
                slider.forceActiveFocus(); events.keyClick(Qt.Key_Right, Qt.NoModifier, -1);
                window.check(slider.value === priorValue + slider.stepSize, "keyboard still commits requested volume");
                window.check(!!slider.liquidAnimating, "keyboard adjustment receives same response");
                Settings.motion = false;
                window.check(!slider.liquidAnimating && slider.liquidResponse === 0, "reduced motion cancels response immediately");
                events.keyClick(Qt.Key_Left, Qt.NoModifier, -1);
                window.check(!slider.liquidAnimating, "reduced motion preserves keyboard without animation");
            } else if (window.step === 9) {
                Settings.motion = true; slider.nudge(4); slider.visible = false;
                window.check(!slider.liquidAnimating && slider.liquidResponse === 0, "hidden control cancels response immediately");
                slider.visible = true; slider.muted = true; slider.nudge(4);
                window.check(!slider.liquidAnimating, "muted control remains visually quiet");
                slider.muted = false; compact.nudge(4);
                window.check(!compact.liquidAnimating, "compact media variant remains subordinate");
                slider.value = 93;
                window.check(!slider.liquidAnimating, "external volume update does not animate decoration");
                window.capture("settled");
            } else if (window.step === 10) {
                stop(); console.log("AUDIO LIQUID COMPLETE", window.failures, "failures"); Qt.quit();
            }
            window.step++;
        }
    }
}
