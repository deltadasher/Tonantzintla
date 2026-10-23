import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/modules/aperture"
ShellRoot {
    id:test
    property var popup:popupLoader.item
    property int step:0
    property int failures:0
    property real oldDelay:0
    property bool oldIndicators:true
    function check(ok,label){if(!ok){failures++;console.error("DOCK POPUP FAIL",label);}}
    function all(item,predicate){
        let result=predicate(item)?[item]:[];
        for(const child of item.children||[])result=result.concat(all(child,predicate));
        return result;
    }
    function control(name){return all(popup.contentItem,function(item){return item.Accessible&&item.Accessible.name===name;})[0];}
    function press(name){const item=control(name);check(!!item,name+" exists");if(item){item.forceActiveFocus();popup.nativeEvents.keyClick(Qt.Key_Space,Qt.NoModifier,-1);}}
    function onScreen(item){const point=item.mapToItem(popup.contentItem,0,0);return point.x>=0&&point.y>=0&&point.x+item.width<=popup.width+1&&point.y+item.height<=popup.height+1;}
    Loader{id:popupLoader;source:"POPUP_SOURCE"}
    Timer {
        interval:150;repeat:true;running:true
        onTriggered:{
            if(!popup||!Settings.persistenceReady)return;
            if(step===0){popup.show();popup.requestActivate();ShellState.openIslandSettings("dock",null,100,20,80,40);oldDelay=Settings.dockHideDelay;oldIndicators=Settings.dockShowIndicators;}
            else if(step===1)press("Behavior");
            else if(step===2){const last=control("Hide delay");check(!!last,"final behavior slider");if(last){last.forceActiveFocus();popup.nativeEvents.keyClick(Qt.Key_Right,Qt.NoModifier,-1);}}
            else if(step===3){check(Settings.dockHideDelay>oldDelay,"native behavior slider updates Settings");check(onScreen(control("Hide delay")),"final behavior control visible on short popup");press("Appearance");}
            else if(step===4){const indicator=control("Running indicators");check(!!indicator,"indicator control");if(indicator){indicator.forceActiveFocus();popup.nativeEvents.keyClick(Qt.Key_Space,Qt.NoModifier,-1);}}
            else if(step===5){check(Settings.dockShowIndicators!==oldIndicators,"native appearance toggle updates Settings");check(onScreen(control("Running indicators")),"appearance controls scroll into viewport");press("Apps");}
            else if(step===6){
                const lists=all(popup.contentItem,function(item){return item.visible&&typeof item.positionViewAtIndex==="function";});
                check(lists.length===2,"both application lists exist");
                for(const list of lists)check(list.height>0&&list.height<=320,"app list has bounded positive viewport");
                const unpin=control("Unpin application");check(!!unpin,"pin management control");if(unpin)unpin.forceActiveFocus();
            }else if(step===7){
                check(onScreen(control("Unpin application")),"nested app list focus remains reachable");
                popup.contentItem.grabToImage(function(result){result.saveToFile(Quickshell.env("POPUP_CAPTURE"));});
            }else if(step===8){
                popup.nativeEvents.keyClick(Qt.Key_Escape,Qt.NoModifier,-1);
                check(!ShellState.islandSettingsVisible,"dock Escape works from nested child focus");
                console.log("DOCK POPUP COMPLETE",failures,"failures");stop();Qt.quit();
            }
            step++;
        }
    }
    Timer{interval:8000;running:true;onTriggered:{console.error("DOCK POPUP TIMEOUT");Qt.quit();}}
}
