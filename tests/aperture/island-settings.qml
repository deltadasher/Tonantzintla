import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/modules/aperture"
ShellRoot {
    id: test
    property int failures: 0
    property int step: 0
    function check(value, message) { if (!value) { failures++; console.error("ISLAND FAIL", message); } }
    function findProvider(item) {
        if (!item) return null;
        if (item.opticalBackdrop) return item.opticalBackdrop;
        for (const child of item.children || []) { const found=findProvider(child); if (found) return found; }
        return null;
    }
    Item {
        id: bar
        property string outputName: Quickshell.screens[1].name
        property string effectivePosition: "right"
        property bool isVertical: true
        property var activeLayout: Settings.getEdgeBarLayout(outputName, effectivePosition)
        function barPointToScreen(x, y) { return effectivePosition === "right" ? Qt.point(popup.width - 48 + x, y) : Qt.point(x, popup.height - 48 + y); }
        Item { id: target; x: 0; y: 120; width: 36; height: 100; property var barWindow: bar }
    }
    IslandQuickSettings { id: popup; modelData: Quickshell.screens[0] }
    Timer {
        interval: 400; running: true; repeat: true
        onTriggered: {
            if (!Settings.persistenceReady || Settings.ensureDirectory.running || Settings.preferencesLoading) return;
            if (test.step === 0) {
                Settings.opticalControls=true; Settings.controlMaterial="lens";
                // QQuickWindow created by Loader must be explicitly mapped in
                // this offscreen adapter; the production host is PanelWindow.
                popup.show(); popup.requestActivate();
                ShellState.openIslandSettings("clock", target, 0, 120, 36, 100);
                test.step++;
            } else if (test.step === 1) {
                const provider=test.findProvider(popup.contentItem);
                test.check(!!provider && provider.scope === "aperture" && provider.ready, "separate popup host provides real shared Aperture optics");
                test.check(popup.outputName === "TEST-DP", "target output wins over initial popup model output");
                test.check(popup.isVertical && popup.isRight && !popup.isBottom, "secondary right edge overrides global top and output bottom");
                test.check(popup.myLocation && popup.myLocation.zone === "end", "location comes from actual right edge layout");
                test.check(popup.popoverX > popup.width / 3, "right edge popup uses output-relative target geometry, not local x=0");
                if (typeof popup.moveToZone === "function") popup.moveToZone("start");
                else test.check(false, "placement action available");
                test.check(Settings.getEdgeBarLayout(bar.outputName, "right").start.indexOf("clock") >= 0, "move action reaches actual placement consumer");
                test.check(Settings.activeLayoutVertical.start.indexOf("media") >= 0, "move leaves unrelated vertical base alone");
                bar.effectivePosition = "bottom"; bar.isVertical = false;
                target.x = 180; target.y = 0; target.width = 100; target.height = 36;
                Settings.clearIslandPlacement(bar.outputName, "clock");
                ShellState.openIslandSettings("clock", target, 180, popup.height - 48, 100, 36);
                test.step++;
            } else {
                test.check(popup.targetRect.x === 180 && popup.targetRect.y === popup.height - 48, "bottom geometry includes strip offset");
                test.check(popup.popoverY < popup.targetRect.y - 12, "bottom popup opens above target");
                test.check(!popup.isVertical && popup.isBottom, "output primary bottom overrides global top");
                test.check(popup.myLocation && popup.myLocation.zone === "center", "output primary layout resolved");
                if (typeof popup.removeFromBar === "function") popup.removeFromBar();
                else test.check(false, "remove action available");
                test.check(Settings.getEdgeBarLayout(bar.outputName, "bottom").center.indexOf("clock") < 0, "remove affects effective primary layout");
                test.check(Settings.activeLayoutVertical.start.indexOf("media") >= 0, "remove preserves unrelated orientation layout");
                // An explicit per-output layout must not rewrite global defaults.
                Settings.saveBarLayout(false, {start:["launcher"],center:["clock"],end:["status"]});
                Settings.setOutputOverride(bar.outputName, "barLayoutHorizontal", {start:[],center:["clock","media"],end:[]});
                ShellState.openIslandSettings("clock", target, 180, popup.height - 48, 100, 36);
                popup.removeFromBar();
                test.check(Settings.getEdgeBarLayout(bar.outputName, "bottom").center.indexOf("clock") < 0, "remove edits explicit output layout");
                test.check(Settings.activeLayoutHorizontal.center.indexOf("clock") >= 0, "explicit output removal preserves global layout");
                test.check(Settings.getEffectiveBarLayout(bar.outputName, false).center.indexOf("media") >= 0, "explicit output removal preserves sibling");
                console.log("ISLAND COMPLETE", test.failures, "failures");
                Qt.quit();
            }
        }
    }
    Timer { interval: 5000; running: true; onTriggered: { console.error("ISLAND TIMEOUT"); Qt.quit(); } }
}
