import QtQuick
import QtQuick.Controls
import QtTest
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/modules/aperture"
ShellRoot {
    id:test
    property var popup:popupLoader.item
    property int step:0
    property int failures:0
    function check(ok,label){if(!ok){failures++;console.error("POPUP FAIL",label);}}
    function find(item,name){
        if(item.Accessible && item.Accessible.name===name)return item;
        for(const child of item.children||[]){const found=find(child,name);if(found)return found;}
        return null;
    }
    function named(item,name){
        if(item.objectName===name)return item;
        for(const child of item.children||[]){const found=named(child,name);if(found)return found;}
        return null;
    }
    Loader {id:popupLoader;source:"POPUP_SOURCE"}
    Timer {
        interval:120;repeat:true;running:true
        onTriggered:{
            if(!popup||!Settings.persistenceReady)return;
            if(step===0){popup.show();popup.requestActivate();ShellState.openIslandSettings("clock",null,1100,900,100,36);}
            else if(step===1){
                check(popup.popoverX>=0&&popup.popoverX+304<=320,"stale target x clamps to short viewport");
                check(popup.popoverY>=0&&popup.popoverY+264<=280,"stale target y clamps to short viewport");
                const stacked=find(popup.contentItem,"Clock face: Stacked");check(!!stacked,"actual popup face choice");
                if(stacked){stacked.forceActiveFocus();popup.nativeEvents.keyClick(Qt.Key_Space,Qt.NoModifier,-1);}
            }else if(step===2){
                check(Settings.barClockFace==="stacked","real popup native choice updates settings");
                const format=find(popup.contentItem,"Time format: 12 hour");check(!!format,"format control");
                if(format){format.forceActiveFocus();popup.nativeEvents.keyClick(Qt.Key_Space,Qt.NoModifier,-1);}
                const remove=find(popup.contentItem,"Remove");check(!!remove,"last placement action");
                if(remove)remove.forceActiveFocus();
            }else if(step===3){
                check(Settings.clock12h,"existing time format remains keyboard operable");
                const scroll=named(popup.contentItem,"island-scroll");
                check(scroll&&scroll.contentItem.contentY>0,"focused final action scrolls into view");
                const remove=find(popup.contentItem,"Remove");
                const point=remove.mapToItem(scroll,0,0);
                check(point.y>=0&&point.y+remove.height<=scroll.height+1,"focused action fully reachable on 280px height");
                popup.contentItem.grabToImage(function(result){result.saveToFile(Quickshell.env("POPUP_CAPTURE"));});
            }else if(step===4){
                popup.nativeEvents.keyClick(Qt.Key_Escape,Qt.NoModifier,-1);
                check(!ShellState.islandSettingsVisible,"Escape works with focused action");
                ShellState.openIslandSettings("clock",null,150,20,100,36);
                const close=find(popup.contentItem,"Close");
                close.forceActiveFocus();
            }else if(step===5){
                const close=find(popup.contentItem,"Close");
                popup.nativeEvents.mouseClick(close,close.width/2,close.height/2,Qt.LeftButton,Qt.NoModifier,-1);
                check(!ShellState.islandSettingsVisible,"native close click");
                console.log("POPUP COMPLETE",failures,"failures");Qt.quit();
                stop();
            }
            step++;
        }
    }
    Timer{interval:7000;running:true;onTriggered:{console.error("POPUP TIMEOUT");Qt.quit();}}
}
