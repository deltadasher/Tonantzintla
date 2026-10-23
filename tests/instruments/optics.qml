import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/components"
Window {
    id: window
    width: 640; height: 540; visible: true; color: Theme.void_
    property int step: 0
    property int failures: 0
    Component.onCompleted: {
        const settingsComponent = Qt.createComponent("../../src/quickshell/components/OpticsSettings.qml");
        check(settingsComponent.status === Component.Ready, "optics settings compiles: " + settingsComponent.errorString());
        if (settingsComponent.status === Component.Ready) {
            const panel = settingsComponent.createObject(scene, {visible:false,width:360});
            check(!!panel, "settings constructs with live control bindings");
            if (panel) panel.destroy();
        }
    }
    function check(ok, label) { if (!ok) { failures++; console.error("OPTICS FAIL", label); } }
    Item {
        id: scene; anchors.fill: parent
        property var opticalBackdrop: field
        OpticalBackdrop {
            id: field; anchors.fill: parent; active: true
            geometryRevision: revealTranslation.x
            source: Quickshell.env("OPTICS_WALLPAPER") || (Quickshell.shellDir + "/../assets/wallpapers/astral-observatory.png")
        }
        Item {
            id: moving; x: 40; y: 60; width: 400; height: 340
            transform: Translate { id: revealTranslation; x: 0 }
            Rectangle { anchors.fill: parent; color: Theme.mantle; radius: 16 }
            OpticalSurface { id: finish; x: 16; y: 16; width: 340; height: 64; hovered: true }
            OpticalSurface { x: 16; y: 110; width: 340; height: 64; material: "frosted"; pressed: true }
            Text { x: 35; y: 132; text: "Frosted · pressed"; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 16 }
            OpticalSurface { x: 16; y: 204; width: 340; height: 64; material: "etched"; focused: true }
            Text { x: 35; y: 226; text: "Etched · keyboard focus"; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 16 }
            Text { x: 35; y: 38; text: "Lens · shared wallpaper field"; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 16 }
        }
        Text { x: 40; y: 440; text: field.stateLabel; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 14 }
    }
    Timer {
        interval: 220; running: true; repeat: true
        onTriggered: {
            if (!Settings.persistenceReady) return;
            if (window.step === 0) {
                Settings.opticalControls = true; Settings.controlMaterial = "etched";
                Settings.controlOpacity = Quickshell.env("OPTICS_OPACITY") === "0" ? 0 : 1;
            } else if (window.step === 1) {
                window.check(!field.texture, "etched does not decode wallpaper");
                Settings.controlMaterial = "lens";
            } else if (window.step === 2) {
                if (!field.ready) return;
                window.check(field.texture.sourceSize.width <= 768 && field.texture.sourceSize.height <= 768, "raw image decode bounded");
                window.check(finish.backdrop === field, "nearest explicit provider resolved");
                window.check(Math.abs(finish.sampleRect.x - 56 / field.viewportSize.width) < .001, "initial mapped origin");
                moving.x = 80;
            } else if (window.step === 3) {
                window.check(Math.abs(finish.sampleRect.x - 96 / field.viewportSize.width) < .001, "ancestor movement updates sampling without polling");
                window.check(finish.supported ? finish.shaderActive : !finish.shaderActive, "GPU shader / software primitive fallback");
                scene.grabToImage(function(result) { result.saveToFile(Quickshell.env("OPTICS_SCREENSHOT")); });
                            revealTranslation.x = 20;
            } else if (window.step === 4) {
                window.check(Math.abs(finish.sampleRect.x - 116 / field.viewportSize.width) < .001, "custom reveal transform updates sampling through host revision");
                Settings.controlMaterial = "etched";
                Settings.setControlFinishScope("instruments", "lens");
                window.check(field.material === "lens" && field.requested, "scope lens overrides global etched");
                field.viewportSize = Qt.size(1920,1080); field.viewportOffset = Qt.point(200,100);
                window.check(Math.abs(finish.sampleRect.x - 316 / 1920) < .001, "output offset and dimensions map immediately");
                field.sourceKind = "video"; field.previewSource = "";
            } else if (window.step === 5) {
                window.check(!field.texture && field.stateLabel.indexOf("unavailable") >= 0, "video without cached still uses explicit fallback");
                field.sourceKind = "image"; field.active = false;
            } else if (window.step === 6) {
                window.check(!field.texture, "hidden host releases image");
                field.source = "/nonexistent/optical-fixture.png"; field.active = true;
            } else if (window.step === 7) {
                window.check(!field.ready && field.stateLabel.indexOf("unavailable") >= 0, "invalid image keeps explicit etched fallback");
                field.active = false;
                console.log("OPTICS COMPLETE", window.failures, "failures"); Qt.quit();
            }
            window.step++;
        }
    }
    Timer { interval: 8000; running: true; onTriggered: { console.error("OPTICS FAIL timeout", field.stateLabel); Qt.quit(); } }
}
