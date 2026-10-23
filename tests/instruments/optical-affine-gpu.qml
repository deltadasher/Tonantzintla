import QtQuick
import Quickshell
import Quickshell.Io
import "../../src/quickshell"
import "../../src/quickshell/components"
Window {
    id: window
    width: 500; height: 400; visible: true
    Item {
        id: scene; width: 400; height: 300; anchors.centerIn: parent
        property var opticalBackdrop: field
        Rectangle { anchors.fill: parent; color: Theme.void_ }
        OpticalBackdrop { id: field; anchors.fill: parent; source: Quickshell.env("AFFINE_PATTERN") }
        Item {
            id: moving
            property bool rotated: false
            x: rotated ? 300 : 100; y: 80
            width: rotated ? 100 : 200; height: rotated ? 200 : 100
            transformOrigin: Item.TopLeft; rotation: rotated ? 90 : 0
            OpticalSurface { id: finish; anchors.fill: parent; radius: 0; material: "lens" }
        }
    }
    IpcHandler {
        target: "affineTest"
        function state(): string {
            return JSON.stringify({ready:field.ready,supported:finish.supported,shader:finish.shaderActive,
                origin:finish.sampleOrigin ? [finish.sampleOrigin.x,finish.sampleOrigin.y] : null,
                bx:finish.sampleBasisX ? [finish.sampleBasisX.x,finish.sampleBasisX.y] : null,
                by:finish.sampleBasisY ? [finish.sampleBasisY.x,finish.sampleBasisY.y] : null});
        }
        function capture(rotated: bool,path: string): void {
            moving.rotated=rotated;
            scene.grabToImage(function(result) { result.saveToFile(path); });
        }
    }
}
