import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/modules/ephemeris"
Window {
    id: window
    visible: true; width: 1040; height: 760; color: Theme.void_
    property int step: 0
    property int failures: 0
    SettingsPane { id: pane; anchors.fill: parent }
    function check(ok, message) { if (!ok) { failures++; console.error("OPTICS FAIL", message); } }
    function choice(item, label) {
        if (item.label === label && typeof item.selected === "function") return item;
        const children = item.children || [];
        for (let i=0; i<children.length; ++i) { const found=choice(children[i],label); if(found) return found; }
        return null;
    }
    Timer {
        interval: 200; running: true; repeat: true
        onTriggered: {
            if (!Settings.persistenceReady) return;
            if (window.step === 0) {
                Settings.motion=false; Settings.weatherEnabled=false;
                window.check(ShellState.settingsSection === "appearance", "default Appearance page");
                window.check(!window.choice(pane,"Control family"), "optics not constructed by ordinary Appearance");
                ShellState.settingsSection="optics";
            } else if (window.step === 1) {
                const family=window.choice(pane,"Control family"), finish=window.choice(pane,"Finish");
                window.check(!!family && !!finish, "dedicated optics page constructs real choices");
                if (finish) finish.selected("lens");
                window.check(Settings.controlMaterial === "lens", "global finish uses actual Settings consumer");
                if (family) family.selected("instruments");
            } else if (window.step === 2) {
                const finish=window.choice(pane,"Finish");
                window.check(!!finish && finish.value === "inherit", "family inherits initially");
                if (finish) finish.selected("frosted");
                window.check(Settings.controlFinishFor("instruments") === "frosted" && Settings.controlMaterial === "lens", "family override independent of global");
                ShellState.settingsSection="system";
            } else {
                window.check(!window.choice(pane,"Control family"), "leaving optics destroys controls");
                console.log("OPTICS COMPLETE",window.failures,"failures"); Qt.quit();
            }
            window.step++;
        }
    }
    Timer { interval: 8000; running: true; onTriggered: { console.error("OPTICS FAIL page timeout"); Qt.quit(); } }
}
