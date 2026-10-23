import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/services"
import "../../src/quickshell/modules/ephemeris/widgets/desktop"
Window {
    id:root
    width:960;height:720;visible:true
    property bool prepared:false
    property int failures:0
    property int symbols:0
    property int labels:0
    function check(value,message){if(!value){failures++;console.error("WALL FONT FAIL",message);}}
    function inspect(item){
        if(item.font && item.text!==undefined){
            const text=String(item.text);
            if(["↻","⌕","✦","◎","▶","▧","⋯","∞","⌁","↵"].indexOf(text)>=0){
                symbols++;
                console.log("WALL SYMBOL",JSON.stringify({text:text,family:item.font.family,weight:item.font.weight,visible:item.visible}));
                check(item.font.family===Theme.iconFamily(text),"symbol "+text+" uses configured icon family");
                check(item.font.weight===Font.Normal,"symbol "+text+" avoids heavy fallback");
            }else if(["LIBRARY","OPTIONS","OUTPUT","TRANSITION","A"].indexOf(text)>=0 && item.font.bold){
                labels++;
                check(item.font.family===(text==="OPTIONS"||text==="A"?Settings.fontDisplay:Settings.fontMono),"text label preserves configured family");
            }
        }
        for(const child of item.children||[])inspect(child);
    }
    Component.onCompleted:{
        Environment.libraryRequested=true;
        Environment.localWallpapers=[{id:"fixture",name:"Fixture world",path:"",preview:"",kind:"image",source:"Tonantzintla"}];
        prepared=true;
    }
    Rectangle{anchors.fill:parent;color:Theme.void_}
    Loader{id:loader;anchors.fill:parent;active:root.prepared&&Settings.persistenceReady;sourceComponent:WallpaperWidget{}}
    Timer{
        interval:800;running:true
        onTriggered:{
            check(loader.status===Loader.Ready,"actual Parallax component loads");
            inspect(loader.item);check(symbols>=9,"actual controls and artwork fallbacks inspected");check(labels>=5,"text emphasis retained");
            console.log("WALL FONT COMPLETE",failures,"failures");
        }
    }
    Timer{interval:1800;running:true;onTriggered:Qt.quit()}
}
