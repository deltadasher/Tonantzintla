import QtQuick
import QtTest
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/modules/tools"
import "../../src/quickshell/services"
Window {
    id:window;width:1120;height:800;visible:true;color:"#080910"
    property int failures:0
    property int step:0
    property bool inTick:false
    function check(value,message) { if(!value) {failures++;console.error("TOOLS FAIL",message);} }
    TestEvent { id:events }
    Item {
        id:scene;anchors.fill:parent
        Rectangle { anchors.fill:parent;color:"#080910" }
        Rectangle { x:16;y:16;width:536;height:768;radius:24;color:"#10121d";CalculatorPane { id:calculator;anchors.fill:parent;anchors.margins:22 } }
        Rectangle { x:568;y:16;width:536;height:768;radius:24;color:"#10121d";NotesPane { id:notes;anchors.fill:parent;anchors.margins:22 } }
    }
    EmojiPane { id:emoji;width:400;height:500;visible:false }
    FilePane { id:files;width:400;height:500;visible:false }
    Loader { id:launcher;active:false;visible:false;width:680;height:700;source:"../../src/quickshell/modules/ephemeris/widgets/catalog/LauncherWidget.qml";onLoaded:item.selectCategory("emoji") }
    Loader { id:osd;source:"../../src/quickshell/modules/osd/OsdSettings.qml";visible:false;width:320 }
    Loader { id:clipboard;source:"../../src/quickshell/modules/transit/ClipboardPane.qml";visible:false;width:700;height:600 }
    Loader { id:notification;source:"../../src/quickshell/components/NotificationCard.qml";visible:false;width:400;property int dismissals:0;onLoaded:item.dismissed.connect(function() {notification.dismissals++;}) }
    Timer {
        interval:200;running:true;repeat:true
        onTriggered: {
            if(window.inTick)return;
            window.inTick=true;
            try {
            if(!Settings.persistenceReady)return;
            if(window.step===0) {
                Settings.toolboxState={};
                launcher.active=true;
                calculator.expression="sqrt(81)+3!";calculator.advanced=true;
                window.requestActivate();calculator.focusPrimary();events.keyClick(Qt.Key_Return,Qt.NoModifier,-1);
                window.check(calculator.result==="15","calculator native Enter");
                const noteId=ToolboxState.addNote();notes.select(noteId);
                ToolboxState.updateNote(noteId,{title:"An observatory you operate",body:"The small tools stay close.\n\n• Search emoji by name\n• Browse one folder at a time\n• Keep notes and clipboard pins locally\n\nNo background indexer, no surprise network requests."});
                notes.focusPrimary();events.keyClickChar("!",Qt.NoModifier,-1);
                const originalText=notes.draftBody;
                window.activeFocusItem.insert(window.activeFocusItem.length,"x".repeat(5000));
                window.check(notes.draftBody.length===4096,"oversized note paste bounded");
                notes.save();
                const second=ToolboxState.addNote();ToolboxState.updateNote(second,{body:"Second note"});notes.select(second);notes.focusPrimary();
                window.check(window.activeFocusItem.text==="Second note","note switch retains editor binding after paste");
                notes.select(noteId);ToolboxState.updateNote(noteId,{body:originalText});ToolboxState.removeNote(second);
                emoji.query="cat";window.check(emoji.matches.some(function(row) {return row.emoji==="🐱";}),"emoji search");
                emoji.moveSelection(1);window.check(emoji.selection>=0,"emoji keyboard selection");
                window.check(osd.status===Loader.Ready,"OSD settings loads");
                window.check(clipboard.status===Loader.Ready,"clipboard controls load");
                Osd.showStatus("capslock",true);window.check(Osd.statusMode && Osd.value===100,"Caps Lock actual status input");
                Osd.showStatus("numlock",false);window.check(Osd.value===0,"Num Lock actual status input");
                window.check(!Osd.showStatus("invented",true),"invalid status rejected");
                Osd.visible=false;
                window.check(Clipboard.paused && !Clipboard.textWatcher.running && !Clipboard.imageWatcher.running,"clipboard watchers paused");
                notification.visible=true;
                events.mouseClick(notification.item,50,30,Qt.RightButton,Qt.NoModifier,-1);
                window.check(notification.dismissals===1,"right-click dismiss signal");
                notification.visible=false;
                window.step++;
            } else if(window.step===1) {
                if(files.entries.length===0)return;
                window.check(files.entries.some(function(entry) {return entry.name==="fixture.txt";}),"one-folder native listing");
                window.check(launcher.status===Loader.Ready && launcher.item.toolMode,"native launcher emoji route");
                launcher.item.selectCategory("files");
                window.step++;
            } else if(window.step===2) {
                notes.save();
                window.check(launcher.item.toolMode && launcher.item.category==="files","native launcher file route");
                launcher.item.selectCategory("all");window.check(!launcher.item.toolMode,"launcher returns to app search");launcher.active=false;
                window.step++;
            } else if(window.step===3) { window.step++; } else {
                if(notes.dirty || Settings.saveTimer.running || Settings.preferencesLoading)return;
                stop();
                const data=JSON.parse(Settings.settingsFile.text());
                window.check(data.toolboxState.notes.length===1,"notes persisted");
                window.check(data.toolboxState.history[0].result==="15","calculation history persisted");
                const screenshot=Quickshell.env("TOOLS_SCREENSHOT");
                if(screenshot)scene.grabToImage(function(result) {window.check(result.saveToFile(screenshot),"render saved");console.log("TOOLS COMPLETE",window.failures,"failures");Qt.quit();});
                else {console.log("TOOLS COMPLETE",window.failures,"failures");Qt.quit();}
            }
            } finally {window.inTick=false;}
        }
    }
    Timer { interval:8000;running:true;onTriggered: {console.error("TOOLS FAIL timeout");Qt.quit();} }
}
