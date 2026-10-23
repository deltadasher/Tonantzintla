import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/components"
Window {
    id:root
    width:920;height:600;visible:true;color:Theme.void_
    function find(item,name) { if(item.objectName===name)return item;for(const c of item.children || []) { const r=find(c,name);if(r)return r; } return null; }
    FeedbackPositionEditor {
        id:editor;x:24;y:24;width:parent.width-48
        label:"Native keyboard placement fixture"
        custom:Settings.osdCustomPosition;normalizedX:Settings.osdX;normalizedY:Settings.osdY
        onEdited: function(x,y) { Settings.osdX=x;Settings.osdY=y;Settings.osdCustomPosition=true; }
    }
    Timer {
        interval:350;running:true
        onTriggered: {
            Settings.osdCustomPosition=true;Settings.osdX=.5;Settings.osdY=.5;
            root.find(editor,"feedbackPositionMarker").forceActiveFocus();
            root.requestActivate();
            console.log("FEEDBACK_KEY_READY");
            finish.start();
        }
    }
    Timer {
        id:finish;interval:1800
        onTriggered: {
            const valid=Math.abs(Settings.osdX-.54)<.001 && Math.abs(Settings.osdY-.55)<.001;
            console.log(valid?"FEEDBACK_KEY_COMPLETE":"FEEDBACK_KEY_FAILED",Settings.osdX,Settings.osdY);
            root.contentItem.grabToImage(function(result) { result.saveToFile(Quickshell.env("FEEDBACK_CAPTURE"));Qt.quit(); });
        }
    }
}
