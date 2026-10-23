import QtQuick
import Quickshell
import "services"
import "components"
import "."
Window {
 id: test; width:400; height:300; visible:true
 property int stage:0; property int ticks:0; property int failures:0; property int starts:0
 property string path:"file:///A%20image.png"
 function check(ok,message) { if(!ok) { failures++;console.error("PREP FAIL",message); } }
 OpticalBackdrop { id:first; anchors.fill:parent; source:test.path }
 OpticalBackdrop { id:second; anchors.fill:parent; source:test.path }
 Connections { target:Environment.opticalPreviewProcess; function onRunningChanged() { if(Environment.opticalPreviewProcess.running)test.starts++; } }
 Timer { interval:150; running:true; repeat:true
  onTriggered:{
   check(!(Environment.opticalPreparing && Environment.libraryProcess.running),"preparer and library never decode concurrently");
   if(++test.ticks>50){console.error("PREP FAIL timeout",Environment.opticalPreparingSource,Environment.opticalResponse);Qt.quit();return;}
   if(stage===0){
    check(starts===0 && !first.texture && !Environment.libraryRequested,"etched startup does no preparation or index");
    Settings.controlMaterial="lens";stage++;
   }else if(stage===1){
    check(starts===1,"two providers coalesce to one helper");
    path="file:///B%20image.png";path="file:///C%20image.png";
    check(!first.texture && !first.ready,"changed source clears stale texture immediately");stage++;
   }else if(Environment.opticalPreparing){return;
   }else if(stage===2){
    if(!first.ready || !second.ready)return;
    check(starts===2,"superseded B request never starts");
    check(first.texture.implicitWidth===64 && first.texture.implicitHeight===32 && first.texture.sourceSize.width===64 && first.texture.sourceSize.height===32,"Qt keeps exact validated still dimensions without upscaling");
    check(first.texture.source.toString()!==path && first.texture.sourceSize.width<=768,"Qt decodes prepared still only");
    check(!Environment.opticalPreviewFor("/A image.png"),"superseded result not published");
    first.active=false;second.active=false;stage++;
   }else if(stage===3){
    check(!first.texture && !second.texture && Environment.opticalRequests.length===0,"inactive providers release texture and ownership");
    first.active=true;second.active=true;stage++;
   }else if(stage===4){
    check(starts===2,"reopen reuses bounded prepared path");
    path="/bad.png";check(!first.texture,"failure request cannot display old still");stage++;
   }else if(stage===5){
    check(starts===3 && !first.texture && first.stateLabel.indexOf("unavailable")>=0,"failure stays truthful etched fallback");
    stage++;
   }else if(stage===6){
    check(starts===3,"failure has no automatic retry loop");
    first.sourceKind="video";second.active=false;first.previewSource=Quickshell.env("PREP_IMAGE");stage++;
   }else if(stage===7){
    if(!first.ready)return;
    check(starts===3,"cached video still does not invoke preparer");first.previewSource="";stage++;
   }else if(stage===8){
    check(!first.texture && first.stateLabel.indexOf("unavailable")>=0 && starts===3,"video without still never decodes or indexes");
    check(!Environment.libraryRequested,"optical queue never acquires library");
    first.active=false;
    for(let i=0;i<4;i++)check(Environment.requestOpticalPreview("limit"+i,"/limit"+i+".png"),"four distinct stills admitted");
    check(!Environment.requestOpticalPreview("overflow","/overflow.png"),"fifth distinct still rejected without queue growth");stage++;
   }else if(stage===9){
    check(starts===7 && Environment.opticalPreviews.length===4,"bounded cache completes four active sources without eviction churn");
    for(let i=0;i<4;i++)Environment.releaseOpticalPreview("limit"+i);stage++;
   }else if(stage===10){
    check(starts===7 && Environment.opticalRequests.length===0,"released queue remains idle");
    Environment.requestOpticalPreview("laneA","/laneA.png");Environment.refreshWallpapers();
    check(Environment.libraryRefreshPending && !Environment.libraryProcess.running,"scan defers behind active optical prepare");stage++;
   }else if(stage===11){
    if(Environment.libraryLoading || Environment.libraryProcess.running)return;
    Environment.releaseOpticalPreview("laneA");Environment.refreshWallpapers();Environment.requestOpticalPreview("laneB","/laneB.png");
    check(Environment.libraryProcess.running && !Environment.opticalPreparing,"optical request defers behind scan");stage++;
   }else{
    if(Environment.libraryLoading || Environment.libraryProcess.running || !Environment.opticalPreviewFor("/laneB.png"))return;
    check(starts===10,"both serialized preparations complete, invalidated in-flight result retried");Environment.releaseOpticalPreview("laneB");
    console.log("PREP COMPLETE",failures);Qt.quit();
   }
  }
 }
}
