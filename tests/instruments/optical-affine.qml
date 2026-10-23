import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/components"
Window {
    id: window
    width: 640; height: 480; visible: true
    property int failures: 0
    function check(ok,label) { if(!ok) { failures++; console.error("OPTICS FAIL",label); } }
    function close(a,b) { return Math.abs(a-b)<.00001; }
    function verify(label) {
        // Exercise the same affine equation used by the shader, including the
        // old bounding-box equation so the fixture fails before the correction.
        const origin=finish.sampleOrigin || Qt.vector2d(finish.sampleRect.x,finish.sampleRect.y);
        const bx=finish.sampleBasisX || Qt.vector2d(finish.sampleRect.width,0);
        const by=finish.sampleBasisY || Qt.vector2d(0,finish.sampleRect.height);
        for(const uv of [[0,0],[1,0],[0,1],[.3,.7]]) {
            const actual=finish.mapToItem(field,uv[0]*finish.width,uv[1]*finish.height);
            check(close(origin.x+bx.x*uv[0]+by.x*uv[1],(actual.x+field.viewportOffset.x)/field.viewportSize.width)
                && close(origin.y+bx.y*uv[0]+by.y*uv[1],(actual.y+field.viewportOffset.y)/field.viewportSize.height),label+" oriented UV "+uv);
        }
    }
    Item {
        anchors.fill: parent
        property var opticalBackdrop: field
        OpticalBackdrop { id: field; anchors.fill: parent; active: false; viewportSize: Qt.size(1920,1080); viewportOffset: Qt.point(180,90) }
        Item {
            id: moving; x: 200; y: 100; width: 200; height: 120; transformOrigin: Item.TopLeft
            OpticalSurface { id: finish; x: 12; y: 18; width: 140; height: 54; material: "lens" }
        }
    }
    Timer {
        interval: 200; running: true
        onTriggered: {
            Settings.opticalControls=true;
            finish.resolveBackdrop();
            verify("unrotated");
            moving.rotation=90; verify("ancestor 90 degrees");
            moving.rotation=180; verify("ancestor 180 degrees");
            moving.scale=.75; verify("scaled rotated ancestor");
            moving.rotation=0; verify("scaled unrotated ancestor");
            console.log("OPTICS COMPLETE",failures,"failures"); Qt.quit();
        }
    }
}
