import QtQuick
import ".."

// One moving highlight per option group. It never owns a pointer handler or
// captures a texture; selection buttons keep their original geometry and focus.
Rectangle {
    id: root
    property Item targetItem: null
    property real outset: 0
    property real leftEdge: 0
    property real rightEdge: 0
    property real topEdge: 0
    property real bottomEdge: 0
    property rect destination: Qt.rect(0,0,0,0)
    property bool placed: false
    property bool forward: true
    readonly property bool moving: travel.running
    x: leftEdge; y: topEdge
    width: Math.max(0,rightEdge-leftEdge); height: Math.max(0,bottomEdge-topEdge)
    radius: Math.min(Theme.radiusSmall,height/2)
    color: Theme.controlHover
    border.width: 1; border.color: Theme.lineBright
    opacity: targetItem && Settings.opticalControls ? 1 : 0
    visible: opacity > .001
    Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
    OpticalSurface { anchors.fill: parent; radius: parent.radius; hovered: true }

    function place(snap) {
        if (!targetItem || !parent) { travel.stop(); placed=false; return; }
        const bounds = targetItem.mapToItem(parent,0,0,targetItem.width,targetItem.height);
        travel.stop();
        destination=Qt.rect(bounds.x-outset,bounds.y-outset,bounds.width+outset*2,bounds.height+outset*2);
        forward=destination.x+destination.width/2 >= (leftEdge+rightEdge)/2;
        if (snap || !placed || !Theme.motionEnabled) {
            leftEdge=destination.x; rightEdge=destination.x+destination.width;
            topEdge=destination.y; bottomEdge=destination.y+destination.height;
        } else travel.start();
        placed=true;
    }
    onTargetItemChanged: place(!placed)
    onOutsetChanged: place(true)
    Connections {
        target: root.targetItem
        function onXChanged() { root.place(true); }
        function onYChanged() { root.place(true); }
        function onWidthChanged() { root.place(true); }
        function onHeightChanged() { root.place(true); }
    }
    Connections {
        target: Theme
        function onMotionEnabledChanged() { root.place(true); }
    }
    ParallelAnimation {
        id: travel
        NumberAnimation { target:root; property:"leftEdge"; to:root.destination.x; duration:Theme.duration(root.forward?280:190); easing.type:Easing.OutCubic }
        NumberAnimation { target:root; property:"rightEdge"; to:root.destination.x+root.destination.width; duration:Theme.duration(root.forward?190:280); easing.type:Easing.OutCubic }
        NumberAnimation { target:root; property:"topEdge"; to:root.destination.y; duration:Theme.duration(230); easing.type:Easing.OutCubic }
        NumberAnimation { target:root; property:"bottomEdge"; to:root.destination.y+root.destination.height; duration:Theme.duration(260); easing.type:Easing.OutCubic }
    }
}
