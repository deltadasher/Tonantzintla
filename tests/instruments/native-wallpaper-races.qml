import QtQuick
import Quickshell
import "services"
import "."
Window {
 id:test; width:320; height:240; visible:true
 Component.onCompleted: Environment.wallpaperRestored=true
 property int stage:0; property int ticks:0; property int failures:0
 function check(ok,message){if(!ok){failures++;console.error("PREP FAIL",message);}}
 function entry(){return Environment.nativeWallpaperFor("A");}
 Timer { interval:100;running:true;repeat:true;onTriggered:{
  if(++ticks>90){console.error("PREP FAIL race timeout",stage);Qt.quit();return;}
  if(stage===0){
   Environment.wallpaperRestored=true;Environment.hasAwww=true;Environment.syncNativeOutputs(["A"]);
   Environment.applyWallpaper("/slow.png","image");
   Settings.wallpaperRenderer="native";Environment.syncNativeOutputs(["A"]);Environment.applyWallpaper("/new.png","image");stage++;
  }else if(stage===1){
   if(Environment.applyProcess.running || !entry() || entry().source!=="/new.png")return;
   check(Settings.nativeWallpaperAssignments.A.source==="/new.png","late ordinary external completion cannot overwrite newer native assignment");
   Environment.applyWallpaper("/slow-fail.png","image");stage++;
  }else if(stage===2){
   if(!entry() || entry().source!=="/slow-fail.png")return;
   Settings.wallpaperRenderer="external";stage++;
  }else if(stage===3){
   if(!Environment.applyProcess.running)return;
   Settings.wallpaperRenderer="native";Environment.syncNativeOutputs(["A"]);Environment.applyWallpaper("/latest.png","image");stage++;
  }else if(stage===4){
   if(!entry() || entry().source!=="/latest.png")return;
   check(Environment.applyProcess.running,"old external failure remains in flight");
   Settings.wallpaperRenderer="external";check(Environment.nativeHandoffs.length===1,"new restore queued behind superseded old process");stage++;
  }else{
   if(Environment.applyProcess.running || Environment.nativeHandoffs.length)return;
   check(!Environment.nativeWallpaperActive && !Environment.wallpaperMessageError,"stale failure does not erase new handoff queue or publish old error");
   check(Settings.nativeWallpaperAssignments.A.source==="/latest.png","latest external restore persists current source");
   console.log("PREP COMPLETE",failures);Qt.quit();
  }
 } }
}
