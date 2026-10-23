import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/modules/umbra"
import "../../src/quickshell/services"
Window {
    id: root
    width: 960; height: 720; visible: true
    property int failures: 0
    property int symbols: 0
    property int labels: 0
    property int titles: 0
    function check(value,message) { if(!value) { failures++; console.error("UMBRA FONT FAIL",message); } }
    function inspect(item) {
        if(item.font && item.text!==undefined) {
            const text=String(item.text);
            console.log("UMBRA TEXT",JSON.stringify({text:text,family:item.font.family,weight:item.font.weight,visible:item.visible}));
            if(["‹","Ⅱ","▶","›"].indexOf(text)>=0) {
                symbols++;
                check(item.font.family===Theme.iconFamily(text),"symbol "+text+" uses configured icon family");
                check(item.font.weight===Font.Normal,"symbol "+text+" avoids heavy fallback");
            } else if(text === "Orbital light") {
                titles++;
                check(item.font.family===Settings.fontDisplay && item.font.weight===Font.DemiBold,"media title retains emphasis");
            } else if(["Choose image…","Choose video…","Undo layout","Redo layout","Reset layout"].indexOf(text)>=0) {
                labels++;
                check(item.font.family===Settings.fontText && item.font.weight===Font.DemiBold,"action text retains family and emphasis");
            }
        }
        for(const child of item.children||[]) inspect(child);
    }
    Rectangle { anchors.fill: parent; color: Theme.void_ }
    Flickable {
        anchors.fill: parent; clip: true
        contentHeight: loader.item ? loader.item.implicitHeight : 0
        Loader { id: loader; width: parent.width; active: Settings.persistenceReady; sourceComponent: UmbraLayoutEditor {} }
    }
    Loader {
        // Optional matched measurement: the real shell already uses this face.
        active: Quickshell.env("TONA_FONT_WARM") === "1"
        anchors.right: parent.right; anchors.bottom: parent.bottom
        sourceComponent: Text { text: "Ⅱ"; color: Theme.moon; font.family: Theme.iconFamily(text); font.weight: Font.Normal; font.pixelSize: 16 }
    }
    Timer {
        interval: 800; running: true
        onTriggered: {
            check(loader.status===Loader.Ready,"actual Umbra editor loads");
            inspect(loader.item);
            check(symbols===3,"all actual media transport symbols inspected");
            check(labels===5,"action text emphasis retained");
            check(Media.playing && titles===1,"private playing media title and pause state present");
            root.contentItem.grabToImage(function(result) { check(result.saveToFile(Quickshell.env("ICON_SCREENSHOT")),"native screenshot"); });
            console.log("UMBRA FONT COMPLETE",failures,"failures");
        }
    }
    Timer { interval: 2200; running: true; onTriggered: Qt.quit() }
}
