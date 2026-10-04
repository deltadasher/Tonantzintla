import QtQuick
import Quickshell
import "modules/aperture"
import "modules/aperture/islands"

// Run only with isolated HOME/XDG config/state; never maps a desktop surface.
Scope {
    ApertureDock {
        id: dock
        modelData: Quickshell.screens[0]
        visible: false
    }
    DockSettings { id: settings; width: 740; height: 300; outputName: "fixture" }
    ApertureContents {
        id: bar
        width: 1024; height: 72
        outputName: Quickshell.screens[0].name
        screenWidth: 1024; screenHeight: 768
        edge: "bottom"
    }
    Timer {
        interval: 250; running: true
        onTriggered: {
            Settings.motion = false;
            Settings.dockPins = '["missing.desktop"]';
            if (dock.inputDepth !== 3) throw new Error("Hidden dock must capture only 3px");
            dock.expanded = true;
            check.restart();
        }
    }
    Timer {
        id: check
        interval: 300
        onTriggered: {
            if (dock.inputDepth !== dock.thickness) throw new Error("Open dock mask must follow revealed geometry");
            ShellState.barEditMode = true;
            for (const edge of ["left", "right", "top", "bottom"]) {
                for (const zone of ["start", "center", "end"]) {
                    bar.commitDrop("dock", edge, zone, 0);
                    if (dock.edge !== edge || dock.placement.zone !== zone)
                        throw new Error("Shared placement did not reach dock: " + edge + "/" + zone);
                    const layout = Settings.getEdgeBarLayout(bar.outputName, edge);
                    if (layout[zone].filter(id => id === "dock").length !== 1)
                        throw new Error("Missing or duplicate dock island");
                }
            }
            Settings.dockEnabled = false;
            if (Settings.getEdgeBarLayout(bar.outputName, "bottom").end.indexOf("dock") >= 0)
                throw new Error("Disabled dock remained in layout");
            if (dock.visible) throw new Error("Test must not map a dock window");
            console.log("DOCK CHECK COMPLETE");
            Qt.quit();
        }
    }
}
