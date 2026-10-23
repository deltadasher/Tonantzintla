import QtQuick
import Quickshell
import "services"
import "."
Window {
 id:test; width:320; height:240; visible:true
 property int stage:0; property int ticks:0; property int failures:0; property int starts:0
 function check(ok,message){if(!ok){failures++;console.error("PREP FAIL",message);}}
 function entry(name){return Environment.nativeWallpaperFor(name);}
 Connections { target:Environment.nativeWallpaperProcess; function onRunningChanged(){if(Environment.nativeWallpaperProcess.running)test.starts++;} }
 Timer { interval:150; running:true; repeat:true; onTriggered:{
  if(++ticks>65){console.error("PREP FAIL native timeout",stage);Qt.quit();return;}
  check([Environment.nativeWallpaperProcess.running,Environment.opticalPreparing,Environment.libraryProcess.running].filter(Boolean).length<=1,"all preparation uses one decode lane");
  if(stage===0){
   const invalid=Environment.sanitizeNativeAssignments({A:{source:"https://bad",kind:"image"},B:{source:"/valid",kind:"image"},C:{source:"/bad",kind:"other"}});
   const prototypeKey=Environment.sanitizeNativeAssignments(JSON.parse('{"__proto__":{"source":"/bad","kind":"image"}}'));
   check(Object.keys(prototypeKey).length===0 && !Environment.nativeWallpaperFor("constructor"),"prototype names cannot become output state");
   check(Object.keys(invalid).length===1 && invalid.B.source==="/valid","persisted intent sanitizer rejects remote source and unsupported kind");
   check(!Environment.nativeWallpaperActive && starts===0,"external startup creates no native preparation");
   Environment.wallpaperRestored=true;Environment.hasAwww=true;Environment.hasMpvpaper=true;
   Settings.wallpaperPath="/initial.png";Settings.persistenceReady=false;Settings.wallpaperRenderer="native";Settings.persistenceReady=true;
   check(Environment.nativeModeWasEnabled,"persisted native mode initializes even after earlier external restore flag");
   Environment.syncNativeOutputs(["A","B"]);stage++;
  }else if(Environment.nativeWallpaperProcess.running || Environment.applyProcess.running){return;
  }else if(stage===1){
   if(!entry("A") || !entry("B"))return;
   check(starts===1,"two outputs share initial still preparation");
   check(typeof Environment.reportNativeWallpaperFailed === "function","native decode failure has a truthful reporting API");
   if(typeof Environment.reportNativeWallpaperFailed === "function") {
    Environment.reportNativeWallpaperFailed("A",entry("A").generation-1,"stale");check(!entry("A").error,"stale decode failure ignored");
    Environment.reportNativeWallpaperFailed("A",entry("A").generation,"PNG decode failed");check(entry("A").error && Environment.wallpaperMessageError && !Environment.nativeWallpaperAllPresented,"current decode failure exposes retry without retiring entry");
   }
   Environment.reportNativeWallpaperPresented("A",entry("A").generation);check(!Environment.nativeWallpaperAllPresented,"one frame acknowledgment does not imply all outputs shown");
   Environment.reportNativeWallpaperPresented("B",entry("B").generation);check(Environment.nativeWallpaperAllPresented,"both real frame acknowledgments count");
   Settings.wallpaperOutputs="A";Environment.applyWallpaper("/new.png","image");check(entry("A").source==="/initial.png","old visible still retained during replacement");stage++;
  }else if(stage===2){
   if(!entry("A") || entry("A").source!=="/new.png")return;
   check(entry("B").source==="/initial.png","selected apply preserves other output");
   Environment.applyWallpaper("/stale.png","image");Environment.applyWallpaper("/final.png","image");stage++;
  }else if(stage===3){
   if(entry("A").source!=="/final.png")return;
   check(Settings.nativeWallpaperAssignments.A.source==="/final.png" && Settings.nativeWallpaperAssignments.B.source==="/initial.png","source-only per-output assignments committed");
   Environment.syncNativeOutputs(["B","C"]);check(!entry("A"),"unplug releases native entry");stage++;
  }else if(stage===4){
   if(!entry("C"))return;
   check(entry("C").source==="/final.png" && entry("B").source==="/initial.png","new output adopts current global source while existing stays unchanged");
   Settings.wallpaperOutputs="C";Environment.applyWallpaper("/bad.png","image");stage++;
  }else if(stage===5){
   check(entry("C").source==="/final.png" && Environment.wallpaperMessageError,"prepare failure keeps old visible background");
   Environment.applyWallpaper("/fail.mp4","video");check(entry("C"),"video retains native until external result");stage++;
  }else if(stage===6){
   if(Environment.nativeHandoffs.length)return;
   check(Settings.wallpaperRenderer==="external" && !Environment.nativeWallpaperActive && Environment.wallpaperMessageError,"video switches to external after restoring every native still; video failure is truthful");
   check(Settings.nativeWallpaperAssignments.B.source==="/initial.png" && Settings.nativeWallpaperAssignments.C.source==="/final.png","failed video leaves restored still assignments intact");
   Environment.applyWallpaper("/clip.mp4","video");stage++;
  }else if(stage===7){
   check(!Environment.nativeWallpaperActive && Settings.wallpaperKind==="video","successful video remains entirely external");
   Settings.wallpaperRenderer="native";check(Settings.wallpaperRenderer==="external","native enabling while video selected is rejected");
   Environment.applyWallpaper("/recover.png","image");stage++;
  }else if(stage===8){
   check(Settings.wallpaperOutputs==="C","handoffs preserve selection preference");
   Settings.wallpaperRenderer="native";Environment.syncNativeOutputs(["B","C"]);stage++;
  }else if(stage===9){
   if(!entry("B") || !entry("C"))return;
   check(entry("B").source==="/initial.png" && entry("C").source==="/recover.png","native mode recovers per-output still assignments after external video ends");
   Settings.wallpaperOutputs="B";Environment.applyWallpaper("/restore-fail.png","image");stage++;
  }else if(stage===10){
   if(entry("B").source!=="/restore-fail.png")return;
   Settings.wallpaperOutputs="C";Environment.applyWallpaper("/clip2.mp4","video");stage++;
  }else if(stage===11){
   check(Environment.wallpaperMessageError && entry("B") && entry("C") && Environment.nativeExternalRequest,"failed first restore retains all native outputs and queued video intent");
   Environment.retryWallpaper();stage++;
  }else{
   if(Environment.nativeHandoffs.length || Environment.nativeWallpaperActive)return;
   check(!Environment.nativeExternalRequest && Settings.wallpaperRenderer==="external","retry restores all targets before applying queued external video");
   console.log("PREP COMPLETE",failures);Qt.quit();
  }
 } }
}
