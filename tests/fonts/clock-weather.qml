import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/modules/aperture"
import "../../src/quickshell/services"
Window {
    id: root
    width: 1600; height: 100; visible: true
    property int phase: 0
    property int failures: 0
    function check(value,message) { if(!value) { failures++; console.error("WEATHER_FAILED",message); } }
    function texts(item,value,result) {
        if(!item)return;
        if(item.text!==undefined && String(item.text)===value)result.push(item);
        for(let child of item.children || [])texts(child,value,result);
    }
    function checkpoint() {
        check(bar.status===Loader.Ready,"actual Aperture loaded");
        const icons=[],values=[];
        texts(bar.item,"☾",icons);texts(bar.item,"17°C",values);
        const expected=phase===1 || phase===3;
        check(icons.length===(expected?1:0),"weather icon lifetime phase "+phase);
        check(values.length===(expected?1:0),"temperature lifetime phase "+phase);
        if(expected && icons.length && values.length) {
            check(icons[0].visible && values[0].visible,"real weather visible");
            check(icons[0].font.family===Settings.fontIcon,"original moon fallback preserved");
            check(values[0].font.family===Theme.fontMono && values[0].font.weight===Font.DemiBold,"temperature typography preserved");
            check(icons[0].parent.spacing===5,"original row spacing");
            check(values[0].x>=icons[0].x+icons[0].width+4.9,"weather row geometry");
        }
        console.log("WEATHER_STAGE",phase);
        if(phase===5) { console.log("WEATHER_COMPLETE",failures);quitDelay.start(); }
        else advance.start();
    }
    Loader {
        id:bar; width:1600; height:100
        active:Settings.persistenceReady && !Settings.ensureDirectory.running
        sourceComponent:ApertureContents { outputName:Quickshell.screens[0].name;previewMode:true;edge:"top" }
    }
    Timer {interval:600;running:true;onTriggered:root.checkpoint()}
    Timer {id:advance;interval:300;onTriggered:{
        root.phase++;
        if(root.phase===1)Weather.applySnapshot({ok:true,unit_symbol:"°C",current:{icon:"☾",temp:17.3}});
        if(root.phase===2)bar.width=1219;
        if(root.phase===3)bar.width=1220;
        if(root.phase===4)bar.item.edge="left";
        if(root.phase===5){bar.item.edge="top";Weather.available=false;}
        settle.start();
    }}
    Timer {id:settle;interval:100;onTriggered:root.checkpoint()}
    Timer {id:quitDelay;interval:200;onTriggered:Qt.quit()}
}
