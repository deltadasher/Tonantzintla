pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../services"
import "FeedbackPlacement.js" as Placement
import "ApertureMetrics.js" as ApertureMetrics

ColumnLayout {
    id: root
    property string label: "Feedback placement"
    property bool custom: false
    property real normalizedX: .5
    property real normalizedY: .5
    property string legacyPosition: "bottom"
    property real popupWidth: 330
    property real popupHeight: 74
    property real edgeMargin: 24
    property real occupiedExtraGap: 4
    property Component previewComponent: null
    property var output: Quickshell.screens.find(s => s.name === Compositor.focusedOutput) || Quickshell.screens[0] || null
    readonly property string outputName: output ? output.name : ""
    readonly property real outputWidth: output ? output.width : 1920
    readonly property real outputHeight: output ? output.height : 1080
    function edgeClearance(edge) {
        return Settings.edgeHasIslands(outputName,edge)
            ? ApertureMetrics.clearance(edge,true,Settings.compact,Settings.barHeightProfile,Theme.barHeight,Settings.barMode,Settings.barMargin)+occupiedExtraGap
            : edgeMargin;
    }
    readonly property var clearance: ({top:edgeClearance("top"),bottom:edgeClearance("bottom"),left:edgeClearance("left"),right:edgeClearance("right")})
    readonly property var position: custom ? ({x:normalizedX,y:normalizedY}) : Placement.preset(legacyPosition)
    readonly property var placed: Placement.place(outputWidth,outputHeight,popupWidth,popupHeight,clearance,position.x,position.y)
    signal edited(real x,real y)
    signal customToggled(bool enabled)
    spacing: 10
    function preset(name) { const p=Placement.preset(name); edited(p.x,p.y); }
    function nudge(dx,dy) { edited(Placement.step(position.x,dx),Placement.step(position.y,dy)); }
    SettingToggle { Layout.fillWidth:true;label:root.label;checked:root.custom;onToggled:root.customToggled(!checked) }
    Rectangle {
        id: miniature
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(120,Math.min(250,width*root.outputHeight/root.outputWidth))
        color: Theme.void_; radius: Theme.radiusSmall; border.width: 1; border.color: Theme.line; clip: true
        readonly property real factor: Math.min(width/root.outputWidth,height/root.outputHeight)
        Item {
            id: viewport
            anchors.centerIn: parent
            width: root.outputWidth*miniature.factor; height: root.outputHeight*miniature.factor
            Repeater {
                model: ["top","bottom","left","right"]
                Rectangle {
                    required property string modelData
                    visible: Settings.edgeHasIslands(root.outputName,modelData)
                    color: Theme.controlActive
                    x: modelData === "right" ? viewport.width-width : 0
                    y: modelData === "bottom" ? viewport.height-height : 0
                    width: modelData === "left" || modelData === "right" ? root.clearance[modelData]*miniature.factor : viewport.width
                    height: modelData === "top" || modelData === "bottom" ? root.clearance[modelData]*miniature.factor : viewport.height
                }
            }
            Rectangle {
                id: marker
                objectName: "feedbackPositionMarker"
                x: root.placed.x*miniature.factor; y: root.placed.y*miniature.factor
                width: root.placed.width*miniature.factor; height: root.placed.height*miniature.factor
                radius: 4; color: Theme.accentVeil; border.width: 1; border.color: activeFocus ? Theme.moon : Theme.accent
                activeFocusOnTab: true
                Accessible.role: Accessible.Slider
                Accessible.name: root.label + " · use arrow keys to move"
                Keys.onPressed: function(event) {
                    const amount=event.modifiers & Qt.ControlModifier ? .01 : .05;
                    if(event.key===Qt.Key_Left) root.nudge(-amount,0);
                    else if(event.key===Qt.Key_Right) root.nudge(amount,0);
                    else if(event.key===Qt.Key_Up) root.nudge(0,-amount);
                    else if(event.key===Qt.Key_Down) root.nudge(0,amount);
                    else return;
                    event.accepted=true;
                }
                Loader {
                    width:root.placed.width;height:root.placed.height
                    scale:miniature.factor;transformOrigin:Item.TopLeft
                    sourceComponent:root.previewComponent
                }
                MouseArea {
                    anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.SizeAllCursor
                    property point origin
                    property point initial
                    onPressed: function(mouse) { marker.forceActiveFocus();origin=mapToItem(viewport,mouse.x,mouse.y);initial=Qt.point(root.placed.x,root.placed.y); }
                    onPositionChanged: function(mouse) {
                        if(!pressed)return;
                        const p=mapToItem(viewport,mouse.x,mouse.y);
                        const pos=Placement.normalized(initial.x+(p.x-origin.x)/miniature.factor,initial.y+(p.y-origin.y)/miniature.factor,root.placed);
                        root.edited(pos.x,pos.y);
                    }
                }
            }
        }
    }
    Flow {
        Layout.fillWidth: true; spacing: 6
        Repeater {
            model:[{name:"Top left",value:"top-left"},{name:"Top center",value:"top"},{name:"Top right",value:"top-right"},
                {name:"Center",value:"center"},{name:"Bottom left",value:"bottom-left"},{name:"Bottom center",value:"bottom"},{name:"Bottom right",value:"bottom-right"}]
            ActionButton { required property var modelData;text:modelData.name;onClicked:root.preset(modelData.value) }
        }
    }
    Text {
        Layout.fillWidth: true; wrapMode: Text.Wrap
        text:"Drag the preview or focus it and use arrow keys (Ctrl for finer steps). Position "
            +Math.round(root.position.x*100)+"% / "+Math.round(root.position.y*100)+"% · "+(root.outputName || "reference output")
        color:Theme.muted;font.family:Theme.fontText;font.pixelSize:11
    }
}
