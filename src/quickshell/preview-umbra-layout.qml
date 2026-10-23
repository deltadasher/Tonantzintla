import QtQuick
import Quickshell

Window {
    id: window
    width: 940; height: 1380; visible: true
    color: "#080910"
    Rectangle { anchors.fill: parent; color: "#080910" }
    Loader {
        id: editor
        x: 24; y: 24; width: parent.width - 48
        source: Quickshell.env("UMBRA_EDITOR_SOURCE")
        onLoaded: capture.start()
        onStatusChanged: if (status === Loader.Error) { console.error("UMBRA_PREVIEW_FAILED"); Qt.quit(); }
    }
    Loader {
        id: surface
        width: 1600; height: 900; visible: false
        source: Quickshell.env("UMBRA_SURFACE_SOURCE")
        onLoaded: { item.previewMode=true; item.intro=1; }
    }
    function find(item,name) {
        if (item.objectName === name) return item;
        for (let child of item.children || []) { const found=find(child,name); if(found) return found; }
        return null;
    }
    function require(value,message) { if(!value) console.error("UMBRA_PREVIEW_FAILED " + message); }
    function bounds(item) { return [item.x,item.y,item.width,item.height].join(","); }
    Timer {
        id: capture; interval: 800
        onTriggered: {
            const liveClassic=window.find(surface.item,"umbraClassicClock");
            const miniatureClassic=window.find(window.find(editor.item,"layoutTile_clock"),"umbraClassicClock");
            window.require(liveClassic && miniatureClassic,"runtime and editor share classic composition");
            for (let name of ["classicDate","classicTime","classicRule"]) {
                const live=window.find(liveClassic,name),small=window.find(miniatureClassic,name);
                window.require(live && small,"both hosts render "+name);
                window.require(Math.abs(live.y/liveClassic.metricScale-small.y/miniatureClassic.metricScale)<.01,name+" identical scaled position");
            }
            const original = JSON.stringify(editor.item.draft);
            editor.item.edit({x: .95, w: .5});
            if (editor.item.draft.clock.x !== .5 || editor.item.undoStack.length !== 1) console.error("UMBRA_PREVIEW_FAILED edit");
            editor.item.undo();
            if (JSON.stringify(editor.item.draft) !== original) console.error("UMBRA_PREVIEW_FAILED undo");
            editor.item.redo();
            if (editor.item.draft.clock.x !== .5) console.error("UMBRA_PREVIEW_FAILED redo");
            editor.item.undo();
            window.require(surface.status === Loader.Ready,"surface loads");
            const password=window.find(surface.item,"umbraFixedPassword");
            const horizon=window.find(surface.item,"umbraFixedHorizon");
            window.require(password && horizon,"fixed elements exist");
            const fixedPassword=window.bounds(password),fixedHorizon=window.bounds(horizon);
            editor.item.gridEnabled=true;
            for (let key of ["clock","media","weather","battery","keyboard"]) {
                editor.item.selected=key;
                editor.item.edit({opacity:.35,visible:true});
                editor.item.rotateSelected();
                const instrument=window.find(surface.item,"umbra"+key[0].toUpperCase()+key.slice(1));
                const face=window.find(instrument,"instrumentFace");
                window.require(face && face.rotation === 90 && Math.abs(face.opacity-.35)<.001,key+" consumes appearance");
                window.require(Math.abs(face.width-instrument.height)<.001 && Math.abs(face.height-instrument.width)<.001,key+" rotated face dimensions");
                for (let point of [[0,0],[face.width,0],[0,face.height],[face.width,face.height]]) {
                    const p=face.mapToItem(surface.item,point[0],point[1]);
                    window.require(p.x>=-.001 && p.y>=-.001 && p.x<=surface.width+.001 && p.y<=surface.height+.001,key+" contained corner");
                }
            }
            window.require(window.bounds(password)===fixedPassword && window.bounds(horizon)===fixedHorizon,"password and horizon remain fixed");
            surface.width=900; surface.height=1600;
            for (let key of ["clock","media","weather","battery","keyboard"]) {
                const instrument=window.find(surface.item,"umbra"+key[0].toUpperCase()+key.slice(1));
                const face=window.find(instrument,"instrumentFace");
                for (let point of [[0,0],[face.width,0],[0,face.height],[face.width,face.height]]) {
                    const p=face.mapToItem(surface.item,point[0],point[1]);
                    window.require(p.x>=-.001 && p.y>=-.001 && p.x<=surface.width+.001 && p.y<=surface.height+.001,key+" portrait contained corner");
                }
            }
            surface.width=1600; surface.height=900;
            window.require(!surface.item.surfaceActive,"no lock or authentication activation");
            window.require(password.z > window.find(surface.item,"umbraMedia").z,"authentication stays above editable instruments");
            window.require(surface.item.opticalBackdrop.scope === "umbra" && surface.item.opticalBackdrop.texture === null,"inactive etched context creates no optical image");
            editor.item.selected="clock";
            const tile=window.find(editor.item,"layoutTile_clock");
            window.require(tile!==null,"miniature exists");
            let handles=0;
            for (let edge of ["top-left","top","top-right","right","bottom-right","bottom","bottom-left","left"])
                if (window.find(tile,"resize_clock_"+edge)) handles++;
            window.require(handles===8,"all resize handles exist");
            window.contentItem.grabToImage(function(result) {
                if (result.saveToFile(Quickshell.env("UMBRA_CAPTURE"))) console.log("UMBRA_PREVIEW_OK");
                else console.error("UMBRA_PREVIEW_FAILED capture");
                Qt.quit();
            });
        }
    }
}
