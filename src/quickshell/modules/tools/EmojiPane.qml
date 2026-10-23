import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "EmojiModel.js" as Model
Item {
    id:root
    property string query:""
    property int selection:0
    property string feedback:""
    readonly property var matches:Model.search(query)
    readonly property int columns:Math.max(1,Math.floor(width/72))
    onMatchesChanged:selection=matches.length?0:-1
    function moveSelection(delta) { selection=Model.move(selection,delta,matches.length);if(selection>=0)grid.positionViewAtIndex(selection,GridView.Contain); }
    function activateSelected() { if(selection>=0 && selection<matches.length) { Clipboard.setText(matches[selection].emoji);feedback="Copied "+matches[selection].emoji; } }
    ColumnLayout {
        anchors.fill:parent;spacing:8
        Text { Layout.fillWidth:true;text:root.feedback || "Find an emoji by name · arrows select · Enter copies";color:Theme.muted;font.family:Theme.fontText;font.pixelSize:12;wrapMode:Text.Wrap }
        GridView {
            id:grid;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;model:root.matches;cellWidth:width/root.columns;cellHeight:78
            delegate:Rectangle {
                required property var modelData
                required property int index
                width:grid.cellWidth-6;height:72;radius:Theme.radiusSmall
                color:root.selection===index?Theme.controlSelected:Theme.controlRest
                border.color:root.selection===index?Theme.accent:"transparent"
                activeFocusOnTab:true;Accessible.role:Accessible.Button;Accessible.name:modelData.name
                Accessible.onPressAction: { root.selection=index;root.activateSelected(); }
                Keys.onReturnPressed: { root.selection=index;root.activateSelected(); }
                Keys.onSpacePressed: { root.selection=index;root.activateSelected(); }
                Column { anchors.centerIn:parent;width:parent.width-6;spacing:3
                    Text { width:parent.width;text:modelData.emoji;horizontalAlignment:Text.AlignHCenter;font.pixelSize:28 }
                    Text { width:parent.width;text:modelData.name.split(" ").slice(0,2).join(" ");color:Theme.muted;font.family:Theme.fontText;font.pixelSize:9;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight }
                }
                MouseArea { anchors.fill:parent;onClicked: { root.selection=parent.index;root.activateSelected(); } }
            }
            Text { anchors.centerIn:parent;visible:root.matches.length===0;text:"No matching emoji";color:Theme.muted;font.family:Theme.fontText }
        }
    }
}
