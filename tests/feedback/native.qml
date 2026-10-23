import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/components"
import "../../src/quickshell/services"
import "../../src/quickshell/modules/osd"
import "../../src/quickshell/modules/transit"

Window {
    id: root
    width: 920; height: 1050; visible: true; color: Theme.void_
    property int failures: 0
    function check(ok,text) { if(!ok) { failures++;console.error("FEEDBACK_FAILED",text); } }
    function find(item,name) {
        if(item.objectName === name)return item;
        for(const child of item.children || []) { const result=find(child,name);if(result)return result; }
        return null;
    }
    OsdBody { id:body;x:30;y:20;width:330;height:74;presentation:1 }
    FeedbackPositionEditor {
        id:editor;x:30;y:310;width:850
        normalizedX:Settings.osdX;normalizedY:Settings.osdY;custom:Settings.osdCustomPosition
        popupWidth:Settings.osdOrientation === "vertical" ? 120 : 330
        popupHeight:Settings.osdOrientation === "vertical" ? 260 : 74
        previewComponent: OsdBody {}
        onEdited: function(x,y) { Settings.osdX=x;Settings.osdY=y;Settings.osdCustomPosition=true; }
    }
    NotificationCard { id:card;x:180;y:20;width:Settings.notificationWidth;appName:"Test";summary:"Silent notification";body:"Width, controls and position are configurable.";actions:[{identifier:"open",text:"Open"},{identifier:"dismiss",text:"Dismiss"},{identifier:"long",text:"A deliberately lengthy notification action"}] }
    Loader { id:settings; x:30;y:730;width:850;sourceComponent:NotificationSettings {} }
    Timer {
        interval:400;running:true
        onTriggered: {
            root.check(root.find(body,"osdHorizontal")!==null,"horizontal body initially mounted");
            Settings.osdOrientation="vertical";body.width=120;body.height=260;
            editor.preset("center");
            root.check(Settings.osdCustomPosition && Settings.osdX===.5 && Settings.osdY===.5,"preset persists normalized center");
            editor.nudge(.1,-.1);
            root.check(Math.abs(Settings.osdX-.6)<.001 && Math.abs(Settings.osdY-.4)<.001,"nudge action updates real settings");
            Settings.notificationWidth=240;
            root.check(card.width===240,"notification width consumed");
            Settings.controlOpacity=0;card.critical=true;
            root.check(card.color.a===1 && card.color.toString()===Theme.danger.toString(),"critical plate stays opaque at zero control fill");
            Settings.notificationSoundsEnabled=true;
            Notifications.preview("Silent test","Even enabled sound must not play for previews.");
            root.check(!Notifications.soundBusy,"preview stays silent");
            Notifications.playSound();Notifications.playSound();
            finish.start();
        }
    }
    Timer {
        id:finish;interval:600
        onTriggered: {
            for (const id of ["open","dismiss","long"]) {
                const action=root.find(card,"notificationAction_"+id),p=action.mapToItem(card,0,0);
                root.check(p.x+action.width<=card.width-70,"notification action clears dismiss strip: "+id);
            }
            root.check(root.find(body,"osdVertical")!==null && root.find(body,"osdHorizontal")===null,"orientation replaces body layout");
            root.check(Notifications.soundState==="played","mock player completed");
            Notifications.playSound(); // Under 2 s: must remain a single call.
            Settings.notificationSoundsEnabled=false;
            Notifications.playSound();
            root.contentItem.grabToImage(function(result) {
                if(Quickshell.env("FEEDBACK_CAPTURE"))result.saveToFile(Quickshell.env("FEEDBACK_CAPTURE"));
                console.log("FEEDBACK_COMPLETE",root.failures);Qt.quit();
            });
        }
    }
    Timer { interval:6000;running:true;onTriggered:{console.error("FEEDBACK_FAILED timeout");Qt.quit();} }
}
