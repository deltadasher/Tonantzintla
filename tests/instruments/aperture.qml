import QtQuick
import QtQuick.Controls
import QtTest
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/components"
import "../../src/quickshell/modules/aperture/islands"
import "../../src/quickshell/modules/ephemeris/widgets/catalog"
import "../../src/quickshell/services"
Window {
    id: window
    width: 720; height: 700; visible: true; color: Theme.void_
    property real centerReveal: 1
    property int step: 0
    property int failures: 0
    property bool ticking: false
    property real classicWidth: 0
    function check(ok,label) { if(!ok) { failures++;console.error("APERTURE FAIL",label); } }
    function find(item,name) {
        if(item.Accessible && item.Accessible.name===name) return item;
        for(const child of item.children||[]) { const found=find(child,name);if(found)return found; }
        return null;
    }
    function named(item,name) {
        if(item.objectName===name)return item;
        for(const child of item.children||[]) {const found=named(child,name);if(found)return found;}
        return null;
    }
    function count(item,name) {
        let result=item.objectName===name?1:0;
        for(const child of item.children||[])result+=count(child,name);
        return result;
    }
    function capture(suffix) { scene.grabToImage(function(result) {result.saveToFile(Quickshell.env("APERTURE_CAPTURE")+suffix+".png");}); }
    function press(name) {
        const item=find(editor,name);check(!!item,"control "+name);
        if(item) { item.forceActiveFocus();events.keyClick(Qt.Key_Space,Qt.NoModifier,-1); }
    }
    TestEvent { id: events }
    QtObject {
        id:fakeBar
        property bool isVertical:true
        property string effectivePosition:"left"
        property string outputName:"fixture"
        property real width:46
        property real systemReveal:1
        property var activeLayout:Settings.activeLayoutVertical
    }
    QtObject {
        id:fakeMedia
        property bool available:true
        property bool playing:false
        property string artUrl:""
        property string mediaKind:"AUDIO"
        property string title:"Aperture signal"
        property string artist:"Test source"
        property real length:120
        property real progress:0.3
        property string timeText:"0:36 / 2:00"
        property var player:({canGoPrevious:true,canGoNext:true,canTogglePlaying:true})
        property int toggles:0
        function toggle(){toggles++;playing=!playing;}
        function next(){}
        function previous(){}
        function raise(){}
    }
    Item {
        id: scene;anchors.fill:parent
        Rectangle {anchors.fill:parent;color:Theme.void_}
        ClockIsland { id: clock; x:20;y:20 }
        SystemReadout { id: telemetry;x:20;y:90 }
        SystemStatsIsland {id:vertical;x:280;y:20;barWindow:fakeBar}
        MediaPill {id:mediaPill;x:20;y:130;visible:false;media:fakeMedia}
        Loader {id:launcher;active:false;visible:false;source:"../../src/quickshell/modules/ephemeris/widgets/catalog/LauncherWidget.qml"}
        Loader { id: editor;x:370;y:10;width:320;source:"../../src/quickshell/modules/aperture/IslandCustomizationBody.qml" }
    }
    Timer { interval:16000;running:true;onTriggered:{console.error("APERTURE TIMEOUT",window.step,Settings.persistenceReady);Qt.quit();} }
    Timer {
        interval:100;repeat:true;running:true
        onTriggered: {
            if(window.ticking || !Settings.persistenceReady)return;
            window.ticking=true;
            try {
                if(step===0) { window.requestActivate();classicWidth=clock.width;Settings.barClockFace="compact"; }
                else if(step===1) {
                    check(clock.width<classicWidth,"compact face changes actual island width");
                    check(clock.faceName==="compact","selected clock face consumer");
                    if(editor.item) { editor.item.islandId="clock";press("Clock face: Stacked"); }
                    else check(false,"context body loads");
                } else if(step===2) {
                    check(clock.faceName==="stacked","native key applies stacked clock");
                    if(editor.item) {press("Clock face: Compact");press("Density: Compact");editor.item.islandId="system_stats";}
                } else if(step===3) {
                    check(clock.compactContent,"local density reaches clock");
                    if(editor.item) {press("Telemetry face: Trace");press("GPU temperature");press("Disk usage");}
                } else if(step===4) {
                    check(telemetry.faceName==="trace","trace face reaches consumer");
                    check(telemetry.metricsModel && telemetry.metricsModel.length===2,"metric subset removes actual delegates");
                } else if(step===5) {capture("-trace");Settings.barTelemetryFace="arc";}
                else if(step===6) {capture("-arc");}
                else if(step<25) {
                    Settings.barTelemetryFace=step%2?"arc":"trace";
                    Settings.barClockFace=step%2?"classic":"stacked";
                    SysStats.cpuPercent=step*2;
                } else if(step===25) {
                    Settings.barClockFace="compact";Settings.barTelemetryFace="trace";
                    window.width=320;
                    editor.x=0;editor.width=320;editor.y=160;
                    if(editor.item) editor.item.islandId="clock";
                } else if(step===26) {
                    check(clock.width<=320,"small output clock bounded");
                    check(telemetry.width<=320,"two channel trace bounded");
                } else if(step===27) {
                    check(count(telemetry,"telemetry-trace")===2,"only selected metric faces mounted");
                    check(vertical.width<=46,"vertical telemetry remains within existing strip");
                    mediaPill.visible=true;editor.item.islandId="media";
                } else if(step===28) {
                    check(mediaPill.width===400,"media default width preserved");
                    press("Album artwork");press("Playback buttons");
                    Settings.barMediaWidth=200;
                } else if(step===29) {
                    check(mediaPill.width===200,"media width has actual consumer");
                    check(!mediaPill.artVisible&&!mediaPill.controlsVisible,"media toggles reach consumer");
                    check(String(named(mediaPill,"media-artwork").source)==="","disabled artwork unloads source");
                    press("Playback buttons");
                } else if(step===30) {
                    const play=find(mediaPill,"Play");check(!!play,"real media transport control");
                    if(play){play.forceActiveFocus();events.keyClick(Qt.Key_Space,Qt.NoModifier,-1);}
                    check(fakeMedia.toggles===1,"native transport key reaches supplied media source");
                    editor.item.islandId="launcher";launcher.active=true;
                } else if(step===31) {
                    check(launcher.item && launcher.item.preferredSurfaceWidth===0,"launcher default adaptive width");
                    press("Adaptive launcher width");press("Adaptive result rows");
                } else if(step===32) {
                    check(launcher.item.preferredSurfaceWidth===720,"launcher chosen width reaches host interface");
                    check(launcher.item.preferredSurfaceHeight===658,"six visible rows reach height consumer");
                    const slider=find(editor,"Visible result rows");check(!!slider,"result row slider");
                    if(slider){slider.forceActiveFocus();events.keyClick(Qt.Key_Right,Qt.NoModifier,-1);}
                } else if(step===33) {
                    check(Settings.launcherVisibleRows===7,"native slider changes row count");
                    check(launcher.item.preferredSurfaceHeight===726,"row count updates surface size");
                    launcher.active=false;mediaPill.visible=false;editor.item.islandId="system_stats";
                    Settings.barTelemetryFace="trace";
                } else if(step<74) {
                    SysStats.cpuPercent=(step*3)%100;
                } else if(step===74) {
                    const trace=named(telemetry,"telemetry-trace");
                    check(trace && trace.samples.length===16,"warm trace retains exactly 16 latest changes");
                    check(count(telemetry,"telemetry-trace")===2,"warm face count stays bounded");
                    editor.item.islandId="clock";
                    editor.y=160;
                } else if(!Settings.saveTimer.running&&!Settings.preferencesLoading) {
                    stop();scene.grabToImage(function(result) {result.saveToFile(Quickshell.env("APERTURE_CAPTURE"));console.log("APERTURE COMPLETE",window.failures,"failures");Qt.quit();});
                } else return;
                step++;
            } finally {window.ticking=false;}
        }
    }
}
