import QtQuick
import Quickshell
import "services"
import "."
Window {
 id:test; width:320; height:240; visible:true
 property int stage:0; property int ticks:0; property int failures:0; property int starts:0
 function check(ok,message){if(!ok){failures++;console.error("PREP FAIL",message);}}
 Connections { target:Environment.opticalPreviewProcess; function onRunningChanged(){if(Environment.opticalPreparing)test.starts++;} }
 Connections { target:Environment; function onOpticalPreviewsChanged(){
  if(test.stage===1 && Environment.opticalPreviewFor("/fresh.png"))test.check(test.starts===2,"old in-flight generation never publishes");
 } }
 Timer { interval:150; running:true; repeat:true; onTriggered:{
  if(++ticks>45){console.error("PREP FAIL freshness timeout",stage);Qt.quit();return;}
  check(!(Environment.opticalPreparing && Environment.libraryProcess.running),"one decode lane during invalidation");
  if(stage===0){
   Environment.wallpaperRestored=true;Environment.hasSwaybg=true;
   Environment.requestOpticalPreview("fresh","/fresh.png");
   Environment.applyWallpaper("file:///fresh.png","image");stage++;
  }else if(Environment.opticalPreparing || Environment.libraryLoading){return;
  }else if(stage===1){
   if(!Environment.opticalPreviewFor("/fresh.png"))return;
   check(starts===2,"explicit same-path reapply replaces in-flight generation");
   Environment.releaseOpticalPreview("fresh");Environment.requestOpticalPreview("bad","/bad.png");stage++;
  }else if(stage===2){
   const result=Environment.opticalPreviewFor("/bad.png");if(!result)return;
   check(!result.preview,"first attempt fails without retry");
   Environment.refreshWallpapers();
   check(!Environment.opticalPreviewFor("/bad.png"),"explicit refresh removes cached failure immediately");stage++;
  }else if(stage===3){
   const result=Environment.opticalPreviewFor("/bad.png");if(!result || !result.preview)return;
   check(starts===4,"refresh retries failed still after scan");
   Environment.releaseOpticalPreview("bad");Environment.requestOpticalPreview("fresh","/fresh.png");stage++;
  }else if(stage===4){
   if(!Environment.opticalPreviewFor("/fresh.png"))return;
   Environment.applyWallpaper("/fresh.png","image");
   check(!Environment.opticalPreviewFor("/fresh.png"),"reapply removes successful same-path cache immediately");stage++;
  }else{
   if(!Environment.opticalPreviewFor("/fresh.png"))return;
   check(starts===6,"successful cached still is prepared again after reapply");
   Environment.releaseOpticalPreview("fresh");console.log("PREP COMPLETE",failures);Qt.quit();
  }
 } }
}
