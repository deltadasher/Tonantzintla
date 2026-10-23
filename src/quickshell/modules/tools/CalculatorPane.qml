import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services"
import "../ephemeris/widgets/catalog/LauncherModel.js" as MathModel
Item {
    id:root
    property bool advanced:false
    property bool degrees:false
    property string expression:""
    property string result:""
    property string error:""
    property real answer:0
    function focusPrimary() { input.forceActiveFocus(); }
    function evaluate() {
        const calculated=MathModel.calculate(expression,degrees,answer);
        error=calculated.error;
        if(calculated.ok) { result=calculated.text;answer=calculated.value;ToolboxState.remember(expression,result); }
    }
    function insert(value) { input.insert(input.cursorPosition,value);input.forceActiveFocus(); }
    ColumnLayout {
        anchors.fill:parent;spacing:10
        RowLayout {
            Layout.fillWidth:true
            Text { Layout.fillWidth:true;text:"Calculator";color:Theme.moon;font.family:Theme.fontDisplay;font.pixelSize:25 }
            ActionButton { text:root.advanced?"Basic":"Advanced";selected:root.advanced;onClicked:root.advanced=!root.advanced }
            ActionButton { visible:root.advanced;text:root.degrees?"Degrees":"Radians";onClicked:root.degrees=!root.degrees }
        }
        Rectangle {
            Layout.fillWidth:true;Layout.preferredHeight:52;radius:Theme.radiusMedium;color:Theme.fieldRest;border.color:input.activeFocus?Theme.accent:Theme.line
            TextInput {
                id:input;anchors.fill:parent;anchors.margins:12;verticalAlignment:TextInput.AlignVCenter
                text:root.expression;onTextChanged:root.expression=text;maximumLength:256
                color:Theme.moon;selectionColor:Theme.accent;selectedTextColor:Theme.void_;font.family:Theme.fontMono;font.pixelSize:21;clip:true
                Accessible.name:"Expression";activeFocusOnTab:true
                Keys.onReturnPressed:root.evaluate();Keys.onEnterPressed:root.evaluate()
            }
        }
        RowLayout {
            Layout.fillWidth:true
            Text { Layout.fillWidth:true;text:root.error || (root.result?"= "+root.result:"Enter an expression");color:root.error?Theme.warning:Theme.accent;font.family:Theme.fontMono;font.pixelSize:19;wrapMode:Text.Wrap }
            ActionButton { text:"Copy";enabled:root.result.length>0 && !root.error;onClicked:Clipboard.setText(root.result) }
        }
        Flow {
            visible:root.advanced;Layout.fillWidth:true;spacing:6
            Repeater { model:["sin(","cos(","tan(","sqrt(","ln(","log(","abs(","min(","max(","pi","e","ans","^","!",","]
                ActionButton { required property string modelData;text:modelData;onClicked:root.insert(modelData) }
            }
        }
        GridLayout {
            Layout.fillWidth:true;columns:4;rowSpacing:6;columnSpacing:6
            Repeater { model:["7","8","9","/","4","5","6","*","1","2","3","-","0",".","(","+", ")","%","Clear","="]
                ActionButton {
                    required property string modelData
                    Layout.fillWidth:true;text:modelData;selected:modelData==="="
                    onClicked: { if(modelData==="=")root.evaluate();else if(modelData==="Clear") { input.clear();root.result="";root.error=""; } else root.insert(modelData); }
                }
            }
        }
        RowLayout { Layout.fillWidth:true;Text { Layout.fillWidth:true;text:"Recent calculations · up to 30";color:Theme.muted;font.family:Theme.fontText;font.pixelSize:12 } ActionButton { text:"Clear history";enabled:ToolboxState.history.length>0;onClicked:ToolboxState.clearHistory() } }
        ListView {
            Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:5;model:ToolboxState.history
            delegate:ActionButton { required property var modelData;width:ListView.view.width;text:modelData.expression+" = "+modelData.result;onClicked: { root.expression=modelData.expression;root.result=modelData.result;root.error="";input.forceActiveFocus(); } }
        }
    }
}
