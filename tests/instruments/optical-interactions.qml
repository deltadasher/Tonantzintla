import QtQuick
import QtTest
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/components"
Window {
    id: window; width: 640; height: 440; visible: true; color: Theme.void_
    property int step: 0
    property int failures: 0
    function check(ok,label) { if (!ok) { failures++; console.error("OPTICS FAIL", label); } }
    function find(item,name) {
        if (item.objectName === name || (item.Accessible && item.Accessible.name === name)) return item;
        for (const child of item.children || []) { const found = find(child,name); if (found) return found; }
        return null;
    }
    TestEvent { id: events }
    Item {
        id: scene; anchors.fill: parent
        Rectangle { anchors.fill: parent; color: Theme.void_ }
        property var opticalBackdrop: field
        OpticalBackdrop { id: field; anchors.fill: parent; active: true }
        Item { id: first; x:20; y:20; width:80; height:40 }
        Item { id: second; x:180; y:20; width:140; height:40 }
        OpticalLens { id: lens }
        SettingChoice { id: choice; x:20; y:100; width:560; label:"Finish"; value:"a"; choices:[{label:"Alpha",value:"a"},{label:"Beta",value:"b"}]; onSelected: function(value) { choice.value=value; } }
        SettingToggle { id: toggle; x:20; y:240; width:560; label:"Enabled"; onToggled: checked = !checked }
    }
    Timer {
        interval: 160; running:true; repeat:true
        onTriggered: {
            if (!Settings.persistenceReady) return;
            if (window.step === 0) { Settings.motion = true; Settings.opticalControls = true; Settings.controlMaterial = "lens"; lens.targetItem = first; }
            else if (window.step === 1) {
                window.check(lens.x === first.x && lens.width === first.width, "first lens placement snaps");
                lens.targetItem = second;
                events.mousePress(toggle,30,20,Qt.LeftButton,Qt.NoModifier,-1);
            } else if (window.step === 2) {
                const thumb = window.find(toggle,"switchThumb");
                window.check(thumb && thumb.width > Theme.switchKnob,"press stretches only the toggle thumb");
                events.mouseRelease(toggle,30,20,Qt.LeftButton,Qt.NoModifier,-1);
                window.check(first.x === 20 && second.x === 180, "moving lens preserves hit rectangles");
                lens.targetItem = first;
            } else if (window.step === 3) { Settings.motion = false; lens.targetItem = second; }
            else if (window.step === 4) {
                window.check(lens.x === second.x && lens.width === second.width, "reduced motion cancels reversed travel and snaps");
                const beta = window.find(choice,"Finish: Beta");
                window.check(!!beta,"keyboard target exists");
                if (beta) { const before = beta.x; beta.forceActiveFocus(); events.keyClick(Qt.Key_Space,Qt.NoModifier,-1); window.check(choice.value === "b" && beta.x === before,"keyboard selection keeps fixed geometry"); }
                toggle.forceActiveFocus(); events.keyClick(Qt.Key_Space,Qt.NoModifier,-1);
                window.check(!toggle.checked,"keyboard toggles existing control after pointer toggle");
                Settings.controlRadius=0;
            } else if (window.step === 5) {
                const thumb = window.find(toggle,"switchThumb");
                window.check(!!thumb && thumb.radius === 0,"toggle honors square control corners");
                const beforeWidth=thumb ? thumb.width : 0;
                events.mousePress(toggle,30,20,Qt.LeftButton,Qt.NoModifier,-1);
                window.check(thumb && thumb.width === beforeWidth,"reduced motion suppresses press stretch");
                events.mouseRelease(toggle,30,20,Qt.LeftButton,Qt.NoModifier,-1);
                lens.targetItem = null;
            } else {
                window.check(!lens.visible || lens.opacity === 0,"no target hides lens");
                stop(); scene.grabToImage(function(result) {
                    result.saveToFile(Quickshell.env("OPTICS_SCREENSHOT"));
                    console.log("OPTICS COMPLETE",window.failures,"failures"); Qt.quit();
                });
            }
            window.step++;
        }
    }
}
