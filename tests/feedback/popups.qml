import QtQuick
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/services"
import "../../src/quickshell/modules/osd"
import "../../src/quickshell/modules/transit"

ShellRoot {
    id:root
    property int failures:0
    property int stage:0
    function check(ok,text) { if(!ok) { failures++;console.error("FEEDBACK_POPUP_FAILED",text); } }
    function contained(window,name) {
        check(window.width>0 && window.height>0,name+" native dimensions");
        check(window.width<=window.screen.width && window.height<=window.screen.height,name+" bounded native window");
        check(window.margins.left>=0 && window.margins.top>=0
            && window.margins.left+window.width<=window.screen.width+1
            && window.margins.top+window.height<=window.screen.height+1,name+" native placement within output");
    }
    OsdPopup { id:osd;modelData:Quickshell.screens[0] }
    NotificationPopups { id:toast }
    Timer {
        interval:600;running:true;repeat:true
        onTriggered: {
            if(root.stage===0) {
                Settings.motion=false;Settings.osdVolume=true;Settings.osdDuration=5000;
                Settings.notificationSoundsEnabled=false;Settings.doNotDisturb=false;
                Settings.osdCustomPosition=false;Settings.osdPosition="bottom";Settings.osdOrientation="horizontal";
                Settings.notificationCustomPosition=false;Settings.notificationPosition="top-right";
                Notifications.preview("Native popup fixture","Silent bounded feedback placement.");
                Osd.show("volume",65,"Native volume fixture",false);
            } else if(root.stage===1) {
                root.contained(osd,"horizontal OSD");root.contained(toast,"legacy toast");
                root.check(osd.width===Math.floor(osd.placement.width) && osd.height===Math.floor(osd.placement.height),"OSD compositor size follows placement");
                Settings.osdOrientation="vertical";Settings.osdCustomPosition=true;Settings.osdX=.5;Settings.osdY=.5;
                Settings.notificationCustomPosition=true;Settings.notificationX=.5;Settings.notificationY=.5;Settings.notificationWidth=520;
            } else if(root.stage===2) {
                root.contained(osd,"vertical OSD");root.contained(toast,"center toast");
                root.check(osd.height>osd.width,"vertical native window shape");
                root.check(Math.abs(osd.margins.left-osd.placement.x)<1 && Math.abs(osd.margins.top-osd.placement.y)<1,"custom OSD margins consumed");
                root.check(toast.width===Math.floor(toast.placement.width),"notification native width consumed");
                root.check(Math.abs(toast.margins.top-toast.placement.y)<1,"notification center actually consumed");
                console.log("FEEDBACK_POPUP_CAPTURE center");
            } else if(root.stage===3) {
                Settings.osdX=-5;Settings.osdY=9;Settings.notificationX=9;Settings.notificationY=-5;
                const edge={};edge[osd.screen.name]={clock:{edge:"right",zone:"end",order:0}};
                Settings.barIslandPlacements=JSON.stringify(edge);
                Settings.compact=false;Settings.barHeightProfile="compact";Settings.barMode="floating";Settings.barMargin=6;
                Settings.notificationWidth=240;
                Settings.controlOpacity=0;
                Notifications.popups.setProperty(0,"critical",true);
            } else if(root.stage===4) {
                root.contained(osd,"clamped OSD");root.contained(toast,"clamped toast");
                root.check(osd.clearances.right===72 && toast.clearances.right===68,"compact-profile vertical edge uses actual Aperture thickness");
                root.check(!Notifications.soundBusy,"native previews never start sound");
                console.log("FEEDBACK_POPUP_COMPLETE",root.failures,JSON.stringify({screen:[osd.screen.width,osd.screen.height],osd:[osd.width,osd.height,osd.margins.left,osd.margins.top],notification:[toast.width,toast.height,toast.margins.left,toast.margins.top]}));
                console.log("FEEDBACK_POPUP_CAPTURE clamped");
            } else { Qt.quit(); }
            root.stage++;
        }
    }
    Timer { interval:8000;running:true;onTriggered:{console.error("FEEDBACK_POPUP_FAILED timeout");Qt.quit();} }
}
