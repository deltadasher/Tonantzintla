import QtQuick
import Quickshell
import "."
import "components"
import "modules/umbra"
Window {
    id: root
    width: 1120; height: 520; visible: true; color: Theme.void_
    property date fixedDate: new Date(2026,9,21,13,7)
    property int failures: 0
    function check(value,message) { if(!value) { failures++; console.error("CLOCK_FAILED",message); } }
    function find(item,name) {
        if(item.objectName === name) return item;
        for(let child of item.children || []) { const result=find(child,name); if(result) return result; }
        return null;
    }
    UmbraClassicClock { id: live; x:20; y:20; width:560; height:240; dateTime:root.fixedDate }
    UmbraClassicClock { id: mini; x:620; y:20; width:280; height:120; dateTime:root.fixedDate }
    Repeater {
        id: faces
        model: ["compact","orbital","luminous","typographic"]
        InstrumentClock { required property string modelData; required property int index
            x:index*280; y:280; width:260; height:220
            variant:modelData; dateTime:root.fixedDate
        }
    }
    Timer {
        interval:400; running:true
        onTriggered: {
            Settings.clock12h=true;
            verify.start();
        }
    }
    Timer {
        id:verify; interval:100
        onTriggered: {
            root.check(live.timeText === "1:07 pm" && mini.timeText === live.timeText,"classic global 12h");
            for(let name of ["classicDate","classicTime","classicRule"]) {
                const a=root.find(live,name),b=root.find(mini,name);
                root.check(a && b,"shared "+name);
                root.check(Math.abs(a.y/2-b.y)<.01 && Math.abs(a.height/2-b.height)<1,name+" scaled metrics");
                root.check(a.y+a.height<=live.height && b.y+b.height<=mini.height,name+" contained");
            }
            for(let i=0;i<faces.count;i++) root.check(faces.itemAt(i).timeText === "1:07 pm",faces.itemAt(i).variant+" global 12h");
            root.contentItem.grabToImage(function(result) {
                result.saveToFile(Quickshell.env("CLOCK_CAPTURE"));
                Settings.clock12h=false;
                finish.start();
            });
        }
    }
    Timer { id:finish; interval:100; onTriggered: {
        root.check(live.timeText === "13:07" && mini.timeText === "13:07","classic 24h restore");
        for(let i=0;i<faces.count;i++) root.check(faces.itemAt(i).timeText === "13:07",faces.itemAt(i).variant+" 24h restore");
        console.log("CLOCK_COMPLETE",root.failures);Qt.quit();
    } }
}
